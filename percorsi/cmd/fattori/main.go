// Comando fattori: il paracadute per quando il server è spento.
//
// Per ogni impianto calcola il rapporto mediano fra distanza su strada e distanza
// in linea d'aria, misurato da otto punti attorno a 2 km e otto attorno a 5 km.
// Ne esce **un numero per impianto** — 1,18 per quello sulla statale, 2,40 per
// quello di là dal fiume — che pesa pochissimo e finisce nel file di provincia.
//
// Gira una volta al mese sul mini PC, nella finestra di veglia, e produce un file
// che la pipeline dati incorpora nella build notturna.
// Vedi ../../../linee-guida/10-percorsi-e-backend.md, Fase 5.
//
//	go run ./cmd/fattori -uscita fattori-stradali.json
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"sort"
	"time"

	"github.com/riccardo-05/pieno/percorsi/internal/geo"
	"github.com/riccardo-05/pieno/percorsi/internal/motore"
	"github.com/riccardo-05/pieno/percorsi/internal/osrm"
)

// Gli anelli su cui si misura, in chilometri, e quanti punti per anello.
var anelli = []float64{2, 5}

const puntiPerAnello = 8

func main() {
	dati := flag.String("dati", "https://riccardo-05.github.io/pieno", "base dei file pubblici della pipeline")
	indirizzoMotore := flag.String("motore", "http://127.0.0.1:5000", "OSRM")
	uscita := flag.String("uscita", "fattori-stradali.json", "file da scrivere")
	soloProvincia := flag.String("provincia", "", "una sola provincia (per provare)")
	flag.Parse()

	province, err := leggiProvince(*dati, *soloProvincia)
	if err != nil {
		log.Fatalf("elenco delle province: %v", err)
	}
	log.Printf("province da lavorare: %d", len(province))

	m := osrm.Nuovo(*indirizzoMotore, 30*time.Second)
	if !m.Vivo(context.Background()) {
		log.Fatalf("il motore su %s non risponde: senza non c'è niente da calcolare", *indirizzoMotore)
	}

	fattori := map[string]float64{}
	saltati := 0
	inizio := time.Now()

	for _, sigla := range province {
		impianti, err := leggiImpianti(*dati, sigla)
		if err != nil {
			log.Printf("provincia %s saltata: %v", sigla, err)
			continue
		}
		for _, i := range impianti {
			f, ok := fattore(m, i)
			if !ok {
				saltati++
				continue
			}
			fattori[i.Id] = f
		}
		log.Printf("%s: %d impianti, %d fattori finora", sigla, len(impianti), len(fattori))
	}

	if err := scrivi(*uscita, fattori); err != nil {
		log.Fatalf("scrittura di %s: %v", *uscita, err)
	}
	log.Printf("fatto in %s: %d fattori scritti in %s (%d impianti senza misura)",
		time.Since(inizio).Round(time.Second), len(fattori), *uscita, saltati)
}

// fattore misura il rapporto mediano strada/linea d'aria attorno a un impianto.
// La mediana e non la media: un solo punto finito su un'isola pedonale o dietro
// un casello sposterebbe la media di parecchio, la mediana quasi per niente.
func fattore(m motore.Motore, i impianto) (float64, bool) {
	destinazione := geo.Punto{Lat: i.Lat, Lon: i.Lon}
	origini := make([]geo.Punto, 0, len(anelli)*puntiPerAnello)
	distanzeAria := make([]float64, 0, len(anelli)*puntiPerAnello)

	for _, raggio := range anelli {
		for k := range puntiPerAnello {
			angolo := 2 * math.Pi * float64(k) / puntiPerAnello
			p := spostato(destinazione, raggio, angolo)
			if !p.Valido() {
				continue
			}
			origini = append(origini, p)
			distanzeAria = append(distanzeAria, raggio*1000)
		}
	}
	if len(origini) == 0 {
		return 0, false
	}

	ctx, stop := context.WithTimeout(context.Background(), 30*time.Second)
	defer stop()

	rapporti := make([]float64, 0, len(origini))
	for k, origine := range origini {
		tratte, err := m.Tabella(ctx, origine, []geo.Punto{destinazione})
		if err != nil || len(tratte) != 1 || !tratte[0].Raggiungibile() {
			continue
		}
		r := tratte[0].Metri / distanzeAria[k]
		// Un rapporto sotto 1 è impossibile su un piano: è il segno che il punto
		// è stato agganciato a una strada più vicina all'impianto di quanto fosse.
		if r < 1 || r > 20 {
			continue
		}
		rapporti = append(rapporti, r)
	}

	// Con meno di metà delle misure non si dichiara un numero: si lascia il campo
	// vuoto e l'app resta alla linea d'aria pura, che almeno è dichiarata.
	if len(rapporti) < len(origini)/2 {
		return 0, false
	}
	return math.Round(mediana(rapporti)*100) / 100, true
}

// spostato dà il punto a «km» di distanza e all'angolo dato (0 = nord).
func spostato(centro geo.Punto, km, angolo float64) geo.Punto {
	const gradiPerKmLat = 1.0 / 111.0
	dLat := km * math.Cos(angolo) * gradiPerKmLat
	dLon := km * math.Sin(angolo) * gradiPerKmLat / math.Cos(centro.Lat*math.Pi/180)
	return geo.Punto{Lat: centro.Lat + dLat, Lon: centro.Lon + dLon}
}

func mediana(v []float64) float64 {
	sort.Float64s(v)
	mezzo := len(v) / 2
	if len(v)%2 == 1 {
		return v[mezzo]
	}
	return (v[mezzo-1] + v[mezzo]) / 2
}

// ---------- lettura dei file pubblici della pipeline ----------

type impianto struct {
	Id  string  `json:"id"`
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

func leggiProvince(base, solo string) ([]string, error) {
	if solo != "" {
		return []string{solo}, nil
	}
	var manifest struct {
		Province []struct {
			Sigla string `json:"sigla"`
		} `json:"province"`
	}
	if err := scarica(base+"/manifest.json", &manifest); err != nil {
		return nil, err
	}
	sigle := make([]string, 0, len(manifest.Province))
	for _, p := range manifest.Province {
		if p.Sigla != "" {
			sigle = append(sigle, p.Sigla)
		}
	}
	if len(sigle) == 0 {
		return nil, fmt.Errorf("il manifest non elenca province")
	}
	return sigle, nil
}

func leggiImpianti(base, sigla string) ([]impianto, error) {
	var provincia struct {
		Impianti []impianto `json:"impianti"`
	}
	if err := scarica(fmt.Sprintf("%s/province/%s.json", base, sigla), &provincia); err != nil {
		return nil, err
	}
	buoni := make([]impianto, 0, len(provincia.Impianti))
	for _, i := range provincia.Impianti {
		if i.Id != "" && i.Lat != 0 && i.Lon != 0 {
			buoni = append(buoni, i)
		}
	}
	return buoni, nil
}

func scarica(indirizzo string, dentro any) error {
	client := &http.Client{Timeout: 60 * time.Second}
	risp, err := client.Get(indirizzo)
	if err != nil {
		return err
	}
	defer risp.Body.Close()
	if risp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s ha risposto %d", indirizzo, risp.StatusCode)
	}
	return json.NewDecoder(risp.Body).Decode(dentro)
}

func scrivi(percorso string, fattori map[string]float64) error {
	corpo, err := json.MarshalIndent(struct {
		Generato string             `json:"generato"`
		Fattori  map[string]float64 `json:"fattori"`
	}{
		Generato: time.Now().UTC().Format("2006-01-02"),
		Fattori:  fattori,
	}, "", " ")
	if err != nil {
		return err
	}
	return os.WriteFile(percorso, corpo, 0o644)
}
