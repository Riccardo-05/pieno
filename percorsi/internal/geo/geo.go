// Package geo tiene le coordinate e l'unico modo in cui l'API le riduce a chiave.
package geo

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// Punto è una coordinata geografica in gradi decimali.
type Punto struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

// passo è il lato della cella di arrotondamento: 0,001° valgono ~111 m in
// latitudine e ~80 m in longitudine alle latitudini italiane, cioè il «~100 m»
// chiesto dalle linee guida.
const passo = 0.001

// Valido scarta coordinate fuori dal mondo e i NaN che arrivano dai client rotti.
func (p Punto) Valido() bool {
	if math.IsNaN(p.Lat) || math.IsNaN(p.Lon) || math.IsInf(p.Lat, 0) || math.IsInf(p.Lon, 0) {
		return false
	}
	return p.Lat >= -90 && p.Lat <= 90 && p.Lon >= -180 && p.Lon <= 180
}

// Arrotonda riduce il punto al centro della cella di ~100 m che lo contiene.
// Non è solo cache: è la ragione per cui la chiave non è mai la posizione
// esatta di qualcuno, e per cui l'informativa privacy può stare in tre righe.
func (p Punto) Arrotonda() Punto {
	return Punto{Lat: arrotondaGrado(p.Lat), Lon: arrotondaGrado(p.Lon)}
}

func arrotondaGrado(v float64) float64 {
	// Il passaggio per la stringa toglie il residuo binario di
	// math.Round(v/passo)*passo, che altrimenti darebbe due chiavi diverse
	// per la stessa cella.
	arrotondato, _ := strconv.ParseFloat(formattaGrado(math.Round(v/passo)*passo), 64)
	return arrotondato
}

func formattaGrado(v float64) string {
	s := strconv.FormatFloat(v, 'f', 3, 64)
	if s == "-0.000" { // meno zero e zero sono la stessa cella
		return "0.000"
	}
	return s
}

// Chiave è la forma testuale del punto arrotondato, usata come chiave di cache.
func (p Punto) Chiave() string {
	a := p.Arrotonda()
	return formattaGrado(a.Lat) + "," + formattaGrado(a.Lon)
}

// ChiaveCoppia unisce origine e destinazione in una sola chiave di cache.
func ChiaveCoppia(origine, destinazione Punto) string {
	return origine.Chiave() + "|" + destinazione.Chiave()
}

// VersoOSRM produce la coordinata nell'ordine che vuole OSRM: prima la longitudine.
func (p Punto) VersoOSRM() string {
	return strconv.FormatFloat(p.Lon, 'f', 6, 64) + "," + strconv.FormatFloat(p.Lat, 'f', 6, 64)
}

// DaTesto legge la forma «lat,lon» usata nei parametri di query.
func DaTesto(s string) (Punto, error) {
	lat, lon, trovato := strings.Cut(s, ",")
	if !trovato {
		return Punto{}, fmt.Errorf("atteso «lat,lon»")
	}
	valLat, err := strconv.ParseFloat(strings.TrimSpace(lat), 64)
	if err != nil {
		return Punto{}, fmt.Errorf("latitudine non numerica")
	}
	valLon, err := strconv.ParseFloat(strings.TrimSpace(lon), 64)
	if err != nil {
		return Punto{}, fmt.Errorf("longitudine non numerica")
	}
	p := Punto{Lat: valLat, Lon: valLon}
	if !p.Valido() {
		return Punto{}, fmt.Errorf("coordinate fuori intervallo")
	}
	return p, nil
}
