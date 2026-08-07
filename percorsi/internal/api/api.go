// Package api è il contratto di Pieno davanti al motore. Il motore non si
// espone mai: qui stanno la cache, il limite di frequenza e la superficie
// ridotta, e qui si vede se un giorno il motore cambia.
package api

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"math"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/riccardo-05/pieno/percorsi/internal/cache"
	"github.com/riccardo-05/pieno/percorsi/internal/geo"
	"github.com/riccardo-05/pieno/percorsi/internal/limite"
	"github.com/riccardo-05/pieno/percorsi/internal/motore"
)

// Config raccoglie le manopole del servizio, tutte con un valore sensato.
type Config struct {
	MaxDestinazioni   int
	VociCache         int
	DurataCache       time.Duration
	RafficaClient     int
	RichiesteAlMinuto float64
	FileVersione      string

	// Reti (in forma CIDR) da cui si accetta l'intestazione «CF-Connecting-IP».
	// Vuoto significa la sola macchina locale, dove gira il tunnel.
	ProxyFidati []string

	Log *slog.Logger
}

// Servizio tiene insieme motore, cache e limite, e serve le tre rotte.
type Servizio struct {
	motore   motore.Motore
	tratte   *cache.Cache[motore.Tratta]
	percorsi *cache.Cache[motore.Percorso]
	limite   *limite.Limite
	cfg      Config
	avvio    time.Time
	sale     []byte // rende non ricostruibile l'IP tenuto in memoria

	// Chi può parlare a nome di altri: si crede all'intestazione del tunnel solo
	// se la richiesta arriva da qui.
	proxyFidati []*net.IPNet
}

// Nuovo costruisce il servizio. I campi a zero prendono il default.
func Nuovo(m motore.Motore, cfg Config) *Servizio {
	if cfg.MaxDestinazioni <= 0 {
		cfg.MaxDestinazioni = 100
	}
	if cfg.VociCache <= 0 {
		cfg.VociCache = 200_000
	}
	if cfg.DurataCache <= 0 {
		cfg.DurataCache = 24 * time.Hour
	}
	if cfg.RafficaClient <= 0 {
		cfg.RafficaClient = 30
	}
	if cfg.RichiesteAlMinuto <= 0 {
		cfg.RichiesteAlMinuto = 60
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}

	sale := make([]byte, 32)
	_, _ = rand.Read(sale)

	return &Servizio{
		motore:      m,
		tratte:      cache.Nuova[motore.Tratta](cfg.VociCache, cfg.DurataCache),
		percorsi:    cache.Nuova[motore.Percorso](cfg.VociCache/10+1, cfg.DurataCache),
		limite:      limite.Nuovo(cfg.RafficaClient, cfg.RichiesteAlMinuto),
		cfg:         cfg,
		avvio:       time.Now(),
		sale:        sale,
		proxyFidati: retiFidate(cfg.ProxyFidati, cfg.Log),
	}
}

// Handler monta le tre rotte versionate.
func (s *Servizio) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.Handle("POST /v1/distanze", s.conLimite(http.HandlerFunc(s.distanze)))
	mux.Handle("GET /v1/percorso", s.conLimite(http.HandlerFunc(s.percorso)))
	// La salute resta fuori dal limite: il monitoraggio non dev'essere la
	// prima cosa a sparire quando il servizio è sotto pressione.
	mux.HandleFunc("GET /v1/salute", s.salute)
	return s.conRegistro(mux)
}

// PulisciOgni tiene in ordine i secchi del limite finché il contesto vive.
func (s *Servizio) PulisciOgni(ctx context.Context, intervallo time.Duration) {
	t := time.NewTicker(intervallo)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.limite.Pulisci()
		}
	}
}

// ---------- POST /v1/distanze ----------

type richiestaDistanze struct {
	Origine      geo.Punto   `json:"origine"`
	Destinazioni []geo.Punto `json:"destinazioni"`
}

// Distanza è ciò che l'app riceve per ogni destinazione. Interi: i centimetri
// non cambiano nessuna decisione, e i decimali sono solo peso in rete.
type Distanza struct {
	Metri         int  `json:"metri"`
	Secondi       int  `json:"secondi"`
	Raggiungibile bool `json:"raggiungibile"`
}

type rispostaDistanze struct {
	Distanze  []Distanza `json:"distanze"`
	DaCache   int        `json:"daCache"`
	DalMotore int        `json:"dalMotore"`
}

func (s *Servizio) distanze(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 256<<10)

	var req richiestaDistanze
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		scriviErrore(w, http.StatusBadRequest, "corpo_illeggibile", "il corpo non è un JSON valido")
		return
	}
	if !req.Origine.Valido() {
		scriviErrore(w, http.StatusBadRequest, "origine_non_valida", "l'origine non è una coordinata valida")
		return
	}
	if len(req.Destinazioni) == 0 {
		scriviErrore(w, http.StatusBadRequest, "senza_destinazioni", "serve almeno una destinazione")
		return
	}
	if len(req.Destinazioni) > s.cfg.MaxDestinazioni {
		scriviErrore(w, http.StatusBadRequest, "troppe_destinazioni",
			"al massimo "+strconv.Itoa(s.cfg.MaxDestinazioni)+" destinazioni per richiesta")
		return
	}
	for _, d := range req.Destinazioni {
		if !d.Valido() {
			scriviErrore(w, http.StatusBadRequest, "destinazione_non_valida",
				"una destinazione non è una coordinata valida")
			return
		}
	}

	// La cache lavora per coppia, non per richiesta intera: due utenti nello
	// stesso isolato che guardano impianti diversi si aiutano comunque.
	esiti := make([]motore.Tratta, len(req.Destinazioni))
	var mancanti []geo.Punto
	var indiciMancanti []int

	for i, d := range req.Destinazioni {
		if t, trovata := s.tratte.Prendi(geo.ChiaveCoppia(req.Origine, d)); trovata {
			esiti[i] = t
			continue
		}
		mancanti = append(mancanti, d)
		indiciMancanti = append(indiciMancanti, i)
	}

	if len(mancanti) > 0 {
		tratte, err := s.motore.Tabella(r.Context(), req.Origine, mancanti)
		if err == nil && len(tratte) != len(mancanti) {
			err = errors.New("il motore ha risposto con un numero di tratte diverso dal richiesto")
		}
		if err != nil {
			s.motoreInDifficolta(w, err, nessunaRaggiungibile(len(req.Destinazioni)))
			return
		}
		for k, t := range tratte {
			i := indiciMancanti[k]
			esiti[i] = t
			s.tratte.Metti(geo.ChiaveCoppia(req.Origine, req.Destinazioni[i]), t)
		}
	}

	risposta := rispostaDistanze{
		Distanze:  make([]Distanza, len(esiti)),
		DaCache:   len(req.Destinazioni) - len(mancanti),
		DalMotore: len(mancanti),
	}
	for i, t := range esiti {
		risposta.Distanze[i] = verso(t)
	}
	scriviJSON(w, http.StatusOK, risposta)
}

// ---------- GET /v1/percorso ----------

type rispostaPercorso struct {
	Metri         int    `json:"metri"`
	Secondi       int    `json:"secondi"`
	Geometria     string `json:"geometria"`
	Raggiungibile bool   `json:"raggiungibile"`
}

func (s *Servizio) percorso(w http.ResponseWriter, r *http.Request) {
	origine, err := geo.DaTesto(r.URL.Query().Get("origine"))
	if err != nil {
		scriviErrore(w, http.StatusBadRequest, "origine_non_valida", "origine: "+err.Error())
		return
	}
	destinazione, err := geo.DaTesto(r.URL.Query().Get("destinazione"))
	if err != nil {
		scriviErrore(w, http.StatusBadRequest, "destinazione_non_valida", "destinazione: "+err.Error())
		return
	}

	chiave := geo.ChiaveCoppia(origine, destinazione)
	p, inCache := s.percorsi.Prendi(chiave)
	if !inCache {
		p, err = s.motore.Percorso(r.Context(), origine, destinazione)
		if err != nil {
			s.motoreInDifficolta(w, err, rispostaPercorso{Raggiungibile: false})
			return
		}
		s.percorsi.Metti(chiave, p)
	}

	scriviJSON(w, http.StatusOK, rispostaPercorso{
		Metri:         arrotonda(p.Metri),
		Secondi:       arrotonda(p.Secondi),
		Geometria:     p.Geometria,
		Raggiungibile: p.Raggiungibile(),
	})
}

// ---------- GET /v1/salute ----------

type rispostaSalute struct {
	Stato           string       `json:"stato"`
	Motore          string       `json:"motore"`
	VersioneGrafo   string       `json:"versioneGrafo"`
	AttivoDaSecondi int64        `json:"attivoDaSecondi"`
	Cache           cache.Misure `json:"cache"`
	Clienti         int          `json:"clienti"`
}

func (s *Servizio) salute(w http.ResponseWriter, r *http.Request) {
	ctx, stop := context.WithTimeout(r.Context(), 2*time.Second)
	defer stop()

	risposta := rispostaSalute{
		Stato:           "su",
		Motore:          "raggiungibile",
		VersioneGrafo:   s.versioneGrafo(),
		AttivoDaSecondi: int64(time.Since(s.avvio).Seconds()),
		Cache:           s.tratte.Misure(),
		Clienti:         s.limite.Clienti(),
	}
	stato := http.StatusOK
	if !s.motore.Vivo(ctx) {
		// Senza motore il servizio è in piedi ma non serve a niente: lo dice,
		// così l'app ricade sulla stima invece di aspettare.
		risposta.Stato, risposta.Motore, stato = "degradato", "irraggiungibile", http.StatusServiceUnavailable
	}
	scriviJSON(w, stato, risposta)
}

// versioneGrafo legge il file scritto dalla ricostruzione mensile. Senza,
// un grafo vecchio di mesi non se ne accorgerebbe nessuno.
func (s *Servizio) versioneGrafo() string {
	if s.cfg.FileVersione == "" {
		return "sconosciuta"
	}
	contenuto, err := os.ReadFile(s.cfg.FileVersione)
	if err != nil {
		return "sconosciuta"
	}
	if v := strings.TrimSpace(string(contenuto)); v != "" {
		return v
	}
	return "sconosciuta"
}

// ---------- contorno ----------

func (s *Servizio) conLimite(prossimo http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		passa, attesa := s.limite.Consenti(s.impronta(r))
		if !passa {
			secondi := max(1, int(math.Ceil(attesa.Seconds())))
			w.Header().Set("Retry-After", strconv.Itoa(secondi))
			scriviErrore(w, http.StatusTooManyRequests, "troppe_richieste",
				"limite di frequenza superato, riprova fra "+strconv.Itoa(secondi)+" s")
			return
		}
		prossimo.ServeHTTP(w, r)
	})
}

// impronta identifica il client per il solo limite di frequenza. L'IP non
// viene conservato: se ne tiene un'impronta con sale casuale, che muore con il
// processo e non è riconducibile a nessuno.
// L'intestazione del tunnel vale **solo se arriva dal tunnel**. Crederle sempre
// significa non avere un limite: chi parla direttamente col servizio scrive
// l'indirizzo che vuole, ne cambia uno a ogni richiesta e ha un secchio nuovo
// ogni volta — e per giunta fa crescere la mappa dei secchi più in fretta di
// quanto Pulisci riesca a sfoltirla.
func (s *Servizio) impronta(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}

	indirizzo := host
	if s.daFidarsi(host) {
		if dichiarato := strings.TrimSpace(r.Header.Get("CF-Connecting-IP")); dichiarato != "" {
			indirizzo = dichiarato
		}
	}

	somma := sha256.Sum256(append(append([]byte(nil), s.sale...), indirizzo...))
	return hex.EncodeToString(somma[:8])
}

// daFidarsi dice se chi ci sta parlando è il nostro proxy, e quindi se ciò che
// dichiara sul conto di altri va creduto.
func (s *Servizio) daFidarsi(host string) bool {
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}
	for _, rete := range s.proxyFidati {
		if rete.Contains(ip) {
			return true
		}
	}
	return false
}

// retiFidate legge le reti indicate in configurazione. Il default è la macchina
// stessa: cloudflared gira qui accanto, e nessun altro deve poter parlare a nome
// di terzi. Una voce illeggibile viene scartata e detta, non ignorata in silenzio.
func retiFidate(voci []string, log *slog.Logger) []*net.IPNet {
	if len(voci) == 0 {
		voci = []string{"127.0.0.0/8", "::1/128"}
	}
	reti := make([]*net.IPNet, 0, len(voci))
	for _, voce := range voci {
		_, rete, err := net.ParseCIDR(strings.TrimSpace(voce))
		if err != nil {
			log.Warn("proxy fidato non riconosciuto: voce ignorata", "voce", voce)
			continue
		}
		reti = append(reti, rete)
	}
	return reti
}

// conRegistro registra conteggi e tempi. Mai la query, mai il corpo: è lì che
// stanno le coordinate, e non devono finire da nessuna parte.
func (s *Servizio) conRegistro(prossimo http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		inizio := time.Now()
		spia := &spiaStato{ResponseWriter: w, stato: http.StatusOK}
		prossimo.ServeHTTP(spia, r)
		s.cfg.Log.Info("richiesta",
			"metodo", r.Method,
			"rotta", r.URL.Path,
			"stato", spia.stato,
			"ms", time.Since(inizio).Milliseconds(),
		)
	})
}

type spiaStato struct {
	http.ResponseWriter
	stato int
}

func (s *spiaStato) WriteHeader(codice int) {
	s.stato = codice
	s.ResponseWriter.WriteHeader(codice)
}

// motoreInDifficolta distingue il guasto dal «non ci arrivo». Il secondo non è
// un errore: è una risposta, e ogni rotta ha la sua forma per darla.
func (s *Servizio) motoreInDifficolta(w http.ResponseWriter, err error, seNonInStrada any) {
	if errors.Is(err, motore.ErrNonInStrada) {
		scriviJSON(w, http.StatusOK, seNonInStrada)
		return
	}
	s.cfg.Log.Error("motore", "errore", err.Error())
	scriviErrore(w, http.StatusBadGateway, "motore_non_disponibile", "il motore dei percorsi non risponde")
}

// nessunaRaggiungibile è la risposta di /v1/distanze quando il motore dice che
// da lì non si va da nessuna parte: stessa forma, tutte dichiarate irraggiungibili.
func nessunaRaggiungibile(quante int) rispostaDistanze {
	return rispostaDistanze{Distanze: make([]Distanza, quante)}
}

func verso(t motore.Tratta) Distanza {
	if !t.Raggiungibile() {
		return Distanza{Raggiungibile: false}
	}
	return Distanza{Metri: arrotonda(t.Metri), Secondi: arrotonda(t.Secondi), Raggiungibile: true}
}

func arrotonda(v float64) int {
	if v < 0 {
		return 0
	}
	return int(math.Round(v))
}

type erroreJSON struct {
	Codice    string `json:"codice"`
	Messaggio string `json:"messaggio"`
}

func scriviErrore(w http.ResponseWriter, stato int, codice, messaggio string) {
	scriviJSON(w, stato, erroreJSON{Codice: codice, Messaggio: messaggio})
}

func scriviJSON(w http.ResponseWriter, stato int, corpo any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(stato)
	_ = json.NewEncoder(w).Encode(corpo)
}
