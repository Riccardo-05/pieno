// Package motore dichiara che cosa Pieno chiede a un servizio di
// instradamento. È il confine che rende OSRM sostituibile: l'API parla questi
// tipi, non quelli del motore, e cambiare motore domani non tocca le rotte.
package motore

import (
	"context"
	"errors"

	"github.com/riccardo-05/pieno/percorsi/internal/geo"
)

// Tratta è quanto il motore sa dire di un collegamento fra due punti.
// Metri e Secondi negativi significano «non raggiungibile».
type Tratta struct {
	Metri   float64
	Secondi float64
}

// Raggiungibile dice se la tratta esiste davvero.
func (t Tratta) Raggiungibile() bool { return t.Metri >= 0 && t.Secondi >= 0 }

// NonRaggiungibile è la tratta che si restituisce quando il motore dice di no.
var NonRaggiungibile = Tratta{Metri: -1, Secondi: -1}

// Percorso aggiunge alla tratta la geometria da disegnare (polilinea codificata).
type Percorso struct {
	Tratta
	Geometria string
}

// ErrNonInStrada segnala che non c'è collegamento stradale: capita sulle isole
// senza traghetto e sulle coordinate finite in mezzo al mare.
var ErrNonInStrada = errors.New("nessun percorso stradale fra i punti")

// Motore è il servizio di instradamento visto da Pieno.
type Motore interface {
	// Tabella dà le tratte da un'origine verso N destinazioni in una richiesta
	// sola: è il caso d'uso della classifica.
	Tabella(ctx context.Context, origine geo.Punto, destinazioni []geo.Punto) ([]Tratta, error)
	// Percorso dà tratta e geometria fra due punti.
	Percorso(ctx context.Context, origine, destinazione geo.Punto) (Percorso, error)
	// Vivo dice se il motore risponde.
	Vivo(ctx context.Context) bool
}
