package osrm

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/riccardo-05/pieno/percorsi/internal/geo"
)

var milano = geo.Punto{Lat: 45.464, Lon: 9.190}

// Il corpo della richiesta e' gia' limitato da MaxBytesReader. La risposta del
// motore no: si leggeva finche' arrivava roba. Il motore e' in casa, quindi il
// rischio e' piccolo — ma un OSRM che impazzisce, o qualunque cosa finisse a
// rispondere al suo posto, poteva riempire la memoria del servizio senza che
// niente lo fermasse. Un tetto costa una riga e toglie l'asimmetria.
func TestUnaRispostaSmisurataNonSiLeggeTutta(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		// JSON **valido**, ma con dentro una zavorra da decine di megabyte. Senza
		// tetto verrebbe letto e decodificato tutto, senza un errore: e' questo il
		// caso che un corpo semplicemente troncato non mette alla prova.
		_, _ = w.Write([]byte(`{"code":"Ok","distances":[[4210]],"durations":[[612]],"zavorra":"`))
		for i := 0; i < 40; i++ {
			_, _ = w.Write([]byte(strings.Repeat("a", 1<<20)))
		}
		_, _ = w.Write([]byte(`"}`))
	}))
	defer server.Close()

	c := Nuovo(server.URL, 5*time.Second)
	_, err := c.Tabella(context.Background(), milano, []geo.Punto{{Lat: 45.478, Lon: 9.227}})

	if err == nil {
		t.Fatal("una risposta senza fine doveva dare errore, non essere letta per intero")
	}
}

func TestUnaRispostaNormaleSiLeggeSenzaProblemi(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"code":"Ok","distances":[[4210]],"durations":[[612]]}`))
	}))
	defer server.Close()

	c := Nuovo(server.URL, 5*time.Second)
	tratte, err := c.Tabella(context.Background(), milano, []geo.Punto{{Lat: 45.478, Lon: 9.227}})

	if err != nil {
		t.Fatalf("errore inatteso: %v", err)
	}
	if len(tratte) != 1 || tratte[0].Metri != 4210 || tratte[0].Secondi != 612 {
		t.Fatalf("tratte = %+v", tratte)
	}
}

func TestIlMotoreCheDiceDiNonArrivarciNonEUnGuasto(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"code":"NoRoute","message":"Impossible route"}`))
	}))
	defer server.Close()

	c := Nuovo(server.URL, 5*time.Second)
	_, err := c.Tabella(context.Background(), milano, []geo.Punto{{Lat: 45.478, Lon: 9.227}})

	if err == nil {
		t.Fatal("atteso ErrNonInStrada")
	}
}
