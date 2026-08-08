package api

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/riccardo-05/pieno/percorsi/internal/geo"
	"github.com/riccardo-05/pieno/percorsi/internal/motore"
)

// motoreFinto conta quante volte viene interrogato: è così che si verifica
// che la cache stia davvero risparmiando lavoro al motore.
type motoreFinto struct {
	chiamate atomic.Int64
	errore   error
	vivo     bool
}

func (m *motoreFinto) Tabella(_ context.Context, _ geo.Punto, destinazioni []geo.Punto) ([]motore.Tratta, error) {
	m.chiamate.Add(1)
	if m.errore != nil {
		return nil, m.errore
	}
	tratte := make([]motore.Tratta, len(destinazioni))
	for i := range destinazioni {
		tratte[i] = motore.Tratta{Metri: float64(1000 * (i + 1)), Secondi: float64(60 * (i + 1))}
	}
	return tratte, nil
}

func (m *motoreFinto) Percorso(_ context.Context, _, _ geo.Punto) (motore.Percorso, error) {
	m.chiamate.Add(1)
	if m.errore != nil {
		return motore.Percorso{}, m.errore
	}
	return motore.Percorso{Tratta: motore.Tratta{Metri: 4210, Secondi: 612}, Geometria: "_p~iF~ps|U"}, nil
}

func (m *motoreFinto) Vivo(context.Context) bool { return m.vivo }

func servizioDiProva(t *testing.T, m motore.Motore, cfg Config) http.Handler {
	t.Helper()
	cfg.Log = slog.New(slog.NewTextHandler(io.Discard, nil))
	return Nuovo(m, cfg).Handler()
}

func chiama(t *testing.T, h http.Handler, metodo, indirizzo, corpo string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(metodo, indirizzo, strings.NewReader(corpo))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestDistanzeRispondePerOgniDestinazione(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{})

	rec := chiama(t, h, http.MethodPost, "/v1/distanze",
		`{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[{"lat":45.478,"lon":9.227},{"lat":45.501,"lon":9.155}]}`)

	if rec.Code != http.StatusOK {
		t.Fatalf("stato = %d, corpo %s", rec.Code, rec.Body.String())
	}
	var risposta rispostaDistanze
	if err := json.Unmarshal(rec.Body.Bytes(), &risposta); err != nil {
		t.Fatal(err)
	}
	if len(risposta.Distanze) != 2 {
		t.Fatalf("distanze = %d, attese 2", len(risposta.Distanze))
	}
	if !risposta.Distanze[0].Raggiungibile || risposta.Distanze[0].Metri != 1000 {
		t.Fatalf("prima distanza = %+v", risposta.Distanze[0])
	}
	if risposta.DalMotore != 2 || risposta.DaCache != 0 {
		t.Fatalf("conteggi = %+v", risposta)
	}
}

func TestLaCacheRisparmiaIlMotore(t *testing.T) {
	m := &motoreFinto{vivo: true}
	h := servizioDiProva(t, m, Config{})

	chiama(t, h, http.MethodPost, "/v1/distanze",
		`{"origine":{"lat":45.4641,"lon":9.1901},"destinazioni":[{"lat":45.478,"lon":9.227}]}`)
	// Stessa cella di ~100 m, coordinate diverse: deve bastare la cache.
	rec := chiama(t, h, http.MethodPost, "/v1/distanze",
		`{"origine":{"lat":45.4643,"lon":9.1903},"destinazioni":[{"lat":45.4782,"lon":9.2272}]}`)

	var risposta rispostaDistanze
	if err := json.Unmarshal(rec.Body.Bytes(), &risposta); err != nil {
		t.Fatal(err)
	}
	if risposta.DaCache != 1 || risposta.DalMotore != 0 {
		t.Fatalf("la seconda richiesta doveva venire dalla cache: %+v", risposta)
	}
	if m.chiamate.Load() != 1 {
		t.Fatalf("il motore è stato interrogato %d volte, attesa 1", m.chiamate.Load())
	}
}

func TestDistanzeRifiutaRichiesteMalfatte(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{MaxDestinazioni: 2})

	casi := []struct {
		nome  string
		corpo string
	}{
		{"corpo non JSON", `non-json`},
		{"origine assurda", `{"origine":{"lat":991,"lon":9.19},"destinazioni":[{"lat":45.4,"lon":9.1}]}`},
		{"senza destinazioni", `{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[]}`},
		{"troppe destinazioni", `{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[{"lat":45.1,"lon":9.1},{"lat":45.2,"lon":9.2},{"lat":45.3,"lon":9.3}]}`},
	}
	for _, c := range casi {
		t.Run(c.nome, func(t *testing.T) {
			if rec := chiama(t, h, http.MethodPost, "/v1/distanze", c.corpo); rec.Code != http.StatusBadRequest {
				t.Fatalf("stato = %d, atteso 400", rec.Code)
			}
		})
	}
}

func TestPercorsoRestituisceLaGeometria(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{})

	rec := chiama(t, h, http.MethodGet, "/v1/percorso?origine=45.464,9.190&destinazione=45.478,9.227", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("stato = %d", rec.Code)
	}
	var p rispostaPercorso
	if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil {
		t.Fatal(err)
	}
	if !p.Raggiungibile || p.Metri != 4210 || p.Geometria == "" {
		t.Fatalf("percorso = %+v", p)
	}
}

func TestNonInStradaNonEUnGuasto(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true, errore: motore.ErrNonInStrada}, Config{})

	rec := chiama(t, h, http.MethodGet, "/v1/percorso?origine=45.464,9.190&destinazione=39.0,9.0", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("stato = %d, atteso 200", rec.Code)
	}
	var p rispostaPercorso
	if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil {
		t.Fatal(err)
	}
	if p.Raggiungibile {
		t.Fatal("doveva essere dichiarata non raggiungibile")
	}
}

func TestMotoreGiuDaBadGateway(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: false, errore: os.ErrDeadlineExceeded}, Config{})

	rec := chiama(t, h, http.MethodGet, "/v1/percorso?origine=45.464,9.190&destinazione=45.478,9.227", "")
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("stato = %d, atteso 502", rec.Code)
	}
}

func TestLimiteDiFrequenzaSiDichiara(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{RafficaClient: 2, RichiesteAlMinuto: 1})
	corpo := `{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[{"lat":45.478,"lon":9.227}]}`

	chiama(t, h, http.MethodPost, "/v1/distanze", corpo)
	chiama(t, h, http.MethodPost, "/v1/distanze", corpo)
	rec := chiama(t, h, http.MethodPost, "/v1/distanze", corpo)

	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("stato = %d, atteso 429", rec.Code)
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Error("manca Retry-After: il limite dev'essere esplicito")
	}
	var e erroreJSON
	if err := json.Unmarshal(rec.Body.Bytes(), &e); err != nil || e.Codice != "troppe_richieste" {
		t.Fatalf("corpo dell'errore = %s", rec.Body.String())
	}
}

// chiamaDa è come chiama, ma dice da quale indirizzo arriva la richiesta e con
// quali intestazioni: serve a distinguere il proxy di casa da uno sconosciuto.
func chiamaDa(t *testing.T, h http.Handler, remoto, corpo string, intestazioni map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/distanze", strings.NewReader(corpo))
	req.RemoteAddr = remoto
	for chiave, valore := range intestazioni {
		req.Header.Set(chiave, valore)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

// Un client qualunque non deve poter cambiare identità a piacere: se bastasse
// scrivere un'intestazione per avere un secchio nuovo, il limite non esisterebbe.
func TestIntestazioneDelProxyIgnorataDaChiNonEIlProxy(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{RafficaClient: 2, RichiesteAlMinuto: 1})
	corpo := `{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[{"lat":45.478,"lon":9.227}]}`

	var ultimo *httptest.ResponseRecorder
	for i := 0; i < 5; i++ {
		ultimo = chiamaDa(t, h, "203.0.113.7:5000", corpo,
			map[string]string{"CF-Connecting-IP": "198.51.100." + strconv.Itoa(i)})
	}

	if ultimo.Code != http.StatusTooManyRequests {
		t.Fatalf("stato = %d, atteso 429: l'intestazione di un client non fidato non deve valere", ultimo.Code)
	}
}

// Dietro il tunnel, invece, l'intestazione è l'unica cosa che distingue due
// utenti diversi: lì va creduta, altrimenti il primo che passa limita tutti.
func TestIntestazioneDelProxyCredutaDalProxy(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{RafficaClient: 2, RichiesteAlMinuto: 1})
	corpo := `{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[{"lat":45.478,"lon":9.227}]}`

	for i := 0; i < 3; i++ {
		chiamaDa(t, h, "127.0.0.1:5000", corpo, map[string]string{"CF-Connecting-IP": "198.51.100.1"})
	}
	altro := chiamaDa(t, h, "127.0.0.1:5000", corpo, map[string]string{"CF-Connecting-IP": "198.51.100.2"})

	if altro.Code != http.StatusOK {
		t.Fatalf("stato = %d, atteso 200: un altro utente dietro lo stesso tunnel ha il suo secchio", altro.Code)
	}
}

// motoreSpia ricorda le coordinate che gli sono arrivate: serve a verificare che
// al motore non finisca la posizione esatta di nessuno.
type motoreSpia struct {
	motoreFinto
	origine      geo.Punto
	destinazioni []geo.Punto
}

func (m *motoreSpia) Tabella(ctx context.Context, origine geo.Punto, destinazioni []geo.Punto) ([]motore.Tratta, error) {
	m.origine = origine
	m.destinazioni = append([]geo.Punto(nil), destinazioni...)
	return m.motoreFinto.Tabella(ctx, origine, destinazioni)
}

// L'informativa dice che la posizione serve a calcolare le distanze, e la cache
// lavora gia' su celle di ~100 m. Passare al motore la coordinata al centimetro non
// aggiunge precisione utile — entro cento metri la strada e' la stessa — e tiene in
// giro una posizione piu' precisa di quanto serva.
func TestAlMotoreNonArrivaLaPosizioneEsatta(t *testing.T) {
	m := &motoreSpia{motoreFinto: motoreFinto{vivo: true}}
	h := servizioDiProva(t, m, Config{})

	chiama(t, h, http.MethodPost, "/v1/distanze",
		`{"origine":{"lat":45.46412345,"lon":9.19016789},"destinazioni":[{"lat":45.47812345,"lon":9.22706789}]}`)

	if m.origine != (geo.Punto{Lat: 45.464, Lon: 9.19}) {
		t.Fatalf("origine passata al motore = %+v, attesa la cella arrotondata", m.origine)
	}
	if len(m.destinazioni) != 1 || m.destinazioni[0] != (geo.Punto{Lat: 45.478, Lon: 9.227}) {
		t.Fatalf("destinazioni passate al motore = %+v", m.destinazioni)
	}
}

// Due posizioni nella stessa cella devono dare la stessa risposta: era gia' cosi'
// grazie alla cache, ora lo e' anche alla prima richiesta.
func TestStessaCellaStessoPercorso(t *testing.T) {
	m := &motoreSpia{motoreFinto: motoreFinto{vivo: true}}
	h := servizioDiProva(t, m, Config{})

	chiama(t, h, http.MethodPost, "/v1/distanze",
		`{"origine":{"lat":45.46401,"lon":9.19001},"destinazioni":[{"lat":45.478,"lon":9.227}]}`)
	prima := m.origine
	chiama(t, h, http.MethodPost, "/v1/distanze",
		`{"origine":{"lat":45.46404,"lon":9.19004},"destinazioni":[{"lat":45.478,"lon":9.227}]}`)

	if m.origine != prima {
		t.Fatalf("stessa cella ma origini diverse: %+v e %+v", prima, m.origine)
	}
}

func TestSaluteDiceVersioneEUptime(t *testing.T) {
	file := filepath.Join(t.TempDir(), "versione-grafo.txt")
	if err := os.WriteFile(file, []byte("prova · 2026-08-07\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{FileVersione: file})

	rec := chiama(t, h, http.MethodGet, "/v1/salute", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("stato = %d", rec.Code)
	}
	var s rispostaSalute
	if err := json.Unmarshal(rec.Body.Bytes(), &s); err != nil {
		t.Fatal(err)
	}
	if s.Stato != "su" || s.VersioneGrafo != "prova · 2026-08-07" {
		t.Fatalf("salute = %+v", s)
	}
}

func TestSaluteDichiaraIlMotoreGiu(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: false}, Config{})

	rec := chiama(t, h, http.MethodGet, "/v1/salute", "")
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("stato = %d, atteso 503", rec.Code)
	}
	var s rispostaSalute
	_ = json.Unmarshal(rec.Body.Bytes(), &s)
	if s.Stato != "degradato" || s.Motore != "irraggiungibile" {
		t.Fatalf("salute = %+v", s)
	}
}

func TestSaluteNonSoggettaAlLimite(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{RafficaClient: 1, RichiesteAlMinuto: 1})
	for i := range 3 {
		if rec := chiama(t, h, http.MethodGet, "/v1/salute", ""); rec.Code == http.StatusTooManyRequests {
			t.Fatalf("la salute è stata limitata alla richiesta %d", i+1)
		}
	}
}

func TestVersioneSconosciutaSenzaFile(t *testing.T) {
	h := servizioDiProva(t, &motoreFinto{vivo: true}, Config{FileVersione: filepath.Join(t.TempDir(), "manca.txt")})

	rec := chiama(t, h, http.MethodGet, "/v1/salute", "")
	var s rispostaSalute
	_ = json.Unmarshal(rec.Body.Bytes(), &s)
	if s.VersioneGrafo != "sconosciuta" {
		t.Fatalf("versioneGrafo = %q", s.VersioneGrafo)
	}
}

func TestPulisciOgniSiFermaColContesto(t *testing.T) {
	s := Nuovo(&motoreFinto{vivo: true}, Config{Log: slog.New(slog.NewTextHandler(io.Discard, nil))})
	ctx, annulla := context.WithCancel(context.Background())
	fatto := make(chan struct{})
	go func() { s.PulisciOgni(ctx, time.Millisecond); close(fatto) }()
	annulla()
	select {
	case <-fatto:
	case <-time.After(time.Second):
		t.Fatal("PulisciOgni non si è fermata")
	}
}
