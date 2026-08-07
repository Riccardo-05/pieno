// Package cache è la memoria a breve termine dell'API: chiavi già arrotondate,
// niente su disco, niente da custodire quando il servizio si spegne.
package cache

import (
	"container/list"
	"sync"
	"time"
)

// Cache tiene un numero massimo di voci con scadenza, scartando le meno usate
// di recente. Nessuna persistenza: si ricostruisce da sé.
type Cache[T any] struct {
	mu       sync.Mutex
	voci     map[string]*list.Element
	ordine   *list.List // fronte = usata più di recente
	capienza int
	durata   time.Duration
	adesso   func() time.Time // sostituibile nei test

	letture, successi uint64
}

type elemento[T any] struct {
	chiave   string
	valore   T
	scadenza time.Time
}

// Nuova costruisce una cache con capienza e durata date.
func Nuova[T any](capienza int, durata time.Duration) *Cache[T] {
	if capienza < 1 {
		capienza = 1
	}
	return &Cache[T]{
		voci:     make(map[string]*list.Element, capienza),
		ordine:   list.New(),
		capienza: capienza,
		durata:   durata,
		adesso:   time.Now,
	}
}

// Prendi restituisce il valore se presente e non scaduto.
func (c *Cache[T]) Prendi(chiave string) (T, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.letture++
	var vuoto T
	el, presente := c.voci[chiave]
	if !presente {
		return vuoto, false
	}
	voce := el.Value.(*elemento[T])
	if c.adesso().After(voce.scadenza) {
		c.rimuovi(el)
		return vuoto, false
	}
	c.ordine.MoveToFront(el)
	c.successi++
	return voce.valore, true
}

// Metti inserisce o aggiorna una voce, sfrattando la meno usata se serve.
func (c *Cache[T]) Metti(chiave string, valore T) {
	c.mu.Lock()
	defer c.mu.Unlock()

	scadenza := c.adesso().Add(c.durata)
	if el, presente := c.voci[chiave]; presente {
		voce := el.Value.(*elemento[T])
		voce.valore, voce.scadenza = valore, scadenza
		c.ordine.MoveToFront(el)
		return
	}
	el := c.ordine.PushFront(&elemento[T]{chiave: chiave, valore: valore, scadenza: scadenza})
	c.voci[chiave] = el
	if c.ordine.Len() > c.capienza {
		c.rimuovi(c.ordine.Back())
	}
}

func (c *Cache[T]) rimuovi(el *list.Element) {
	if el == nil {
		return
	}
	c.ordine.Remove(el)
	delete(c.voci, el.Value.(*elemento[T]).chiave)
}

// Misure riporta quanto la cache sta lavorando. Conteggi, non posizioni:
// è quello che il monitoraggio può sapere senza sapere dove sta nessuno.
type Misure struct {
	Voci     int     `json:"voci"`
	Letture  uint64  `json:"letture"`
	Successi uint64  `json:"successi"`
	Tasso    float64 `json:"tasso"`
}

// Misure fotografa lo stato corrente della cache.
func (c *Cache[T]) Misure() Misure {
	c.mu.Lock()
	defer c.mu.Unlock()

	m := Misure{Voci: c.ordine.Len(), Letture: c.letture, Successi: c.successi}
	if c.letture > 0 {
		m.Tasso = float64(c.successi) / float64(c.letture)
	}
	return m
}
