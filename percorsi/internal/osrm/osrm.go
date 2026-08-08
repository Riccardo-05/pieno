// Package osrm è l'unico punto del servizio che sa che il motore è OSRM.
// Tutto il resto parla dei tipi di internal/motore.
package osrm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/riccardo-05/pieno/percorsi/internal/geo"
	"github.com/riccardo-05/pieno/percorsi/internal/motore"
)

// maxRisposta è quanto si è disposti a leggere dal motore. Una tabella verso cento
// destinazioni sta in poche decine di KB e un percorso con geometria in qualche
// centinaio: otto megabyte sono larghi per qualunque risposta sensata e stretti
// abbastanza da non lasciare che una risposta impazzita riempia la memoria.
//
// Il corpo delle richieste che *arrivano* era già limitato; quello delle risposte no,
// e non c'era ragione per l'asimmetria.
const maxRisposta = 8 << 20

// Client è un motore di instradamento OSRM raggiungibile via HTTP.
type Client struct {
	base    string
	profilo string
	http    *http.Client
}

// verifica a compilazione che il client rispetti il contratto di Pieno.
var _ motore.Motore = (*Client)(nil)

// Nuovo costruisce un client verso «base» (es. http://127.0.0.1:5000).
func Nuovo(base string, scadenza time.Duration) *Client {
	return &Client{
		base:    strings.TrimSuffix(base, "/"),
		profilo: "driving",
		http:    &http.Client{Timeout: scadenza},
	}
}

// Tabella chiede in una sola richiesta le tratte da un'origine verso N
// destinazioni. È il caso d'uso della classifica, ed è il motivo per cui il
// motore è OSRM.
func (c *Client) Tabella(ctx context.Context, origine geo.Punto, destinazioni []geo.Punto) ([]motore.Tratta, error) {
	if len(destinazioni) == 0 {
		return nil, nil
	}

	coordinate := make([]string, 0, len(destinazioni)+1)
	coordinate = append(coordinate, origine.VersoOSRM())
	indici := make([]string, 0, len(destinazioni))
	for i, d := range destinazioni {
		coordinate = append(coordinate, d.VersoOSRM())
		indici = append(indici, strconv.Itoa(i+1))
	}

	q := url.Values{
		"sources":      {"0"},
		"destinations": {strings.Join(indici, ";")},
		"annotations":  {"duration,distance"},
	}
	indirizzo := fmt.Sprintf("%s/table/v1/%s/%s?%s", c.base, c.profilo, strings.Join(coordinate, ";"), q.Encode())

	var risposta struttTabella
	if err := c.chiedi(ctx, indirizzo, &risposta); err != nil {
		return nil, err
	}
	if len(risposta.Distanze) == 0 || len(risposta.Durate) == 0 {
		return nil, motore.ErrNonInStrada
	}

	tratte := make([]motore.Tratta, len(destinazioni))
	for i := range destinazioni {
		if i >= len(risposta.Distanze[0]) || i >= len(risposta.Durate[0]) {
			return nil, fmt.Errorf("il motore ha risposto con meno colonne del richiesto")
		}
		d, s := risposta.Distanze[0][i], risposta.Durate[0][i]
		if d == nil || s == nil {
			// OSRM manda null dove non c'è collegamento: si dichiara, non si inventa.
			tratte[i] = motore.NonRaggiungibile
			continue
		}
		tratte[i] = motore.Tratta{Metri: *d, Secondi: *s}
	}
	return tratte, nil
}

// Percorso chiede la tratta fra due punti con la geometria per disegnarla.
func (c *Client) Percorso(ctx context.Context, origine, destinazione geo.Punto) (motore.Percorso, error) {
	q := url.Values{
		"overview":     {"simplified"},
		"geometries":   {"polyline"},
		"steps":        {"false"},
		"alternatives": {"false"},
	}
	indirizzo := fmt.Sprintf("%s/route/v1/%s/%s;%s?%s",
		c.base, c.profilo, origine.VersoOSRM(), destinazione.VersoOSRM(), q.Encode())

	var risposta struttPercorso
	if err := c.chiedi(ctx, indirizzo, &risposta); err != nil {
		return motore.Percorso{}, err
	}
	if len(risposta.Percorsi) == 0 {
		return motore.Percorso{}, motore.ErrNonInStrada
	}
	p := risposta.Percorsi[0]
	return motore.Percorso{
		Tratta:    motore.Tratta{Metri: p.Distanza, Secondi: p.Durata},
		Geometria: p.Geometria,
	}, nil
}

// Vivo dice se il motore risponde.
func (c *Client) Vivo(ctx context.Context) bool {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		c.base+"/nearest/v1/"+c.profilo+"/9.190000,45.464000", nil)
	if err != nil {
		return false
	}
	risp, err := c.http.Do(req)
	if err != nil {
		return false
	}
	defer risp.Body.Close()
	_, _ = io.Copy(io.Discard, risp.Body)
	return risp.StatusCode == http.StatusOK
}

func (c *Client) chiedi(ctx context.Context, indirizzo string, dentro any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, indirizzo, nil)
	if err != nil {
		return err
	}
	risp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("il motore non risponde: %w", err)
	}
	defer risp.Body.Close()

	if risp.StatusCode != http.StatusOK {
		// 400 con code NoRoute/NoSegment è il modo di OSRM di dire «non ci arrivo».
		var esito struttEsito
		if json.NewDecoder(risp.Body).Decode(&esito) == nil && strings.HasPrefix(esito.Codice, "No") {
			return motore.ErrNonInStrada
		}
		return fmt.Errorf("il motore ha risposto %d", risp.StatusCode)
	}
	if err := json.NewDecoder(io.LimitReader(risp.Body, maxRisposta)).Decode(dentro); err != nil {
		return fmt.Errorf("risposta del motore illeggibile: %w", err)
	}
	return nil
}

type struttEsito struct {
	Codice string `json:"code"`
}

type struttTabella struct {
	struttEsito
	Distanze [][]*float64 `json:"distances"`
	Durate   [][]*float64 `json:"durations"`
}

type struttPercorso struct {
	struttEsito
	Percorsi []struct {
		Distanza  float64 `json:"distance"`
		Durata    float64 `json:"duration"`
		Geometria string  `json:"geometry"`
	} `json:"routes"`
}
