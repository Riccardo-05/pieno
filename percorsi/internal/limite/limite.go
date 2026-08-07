// Package limite tiene il limite di frequenza per client: un secchio di gettoni
// che si ricarica nel tempo, senza dipendenze esterne e senza Redis.
package limite

import (
	"sync"
	"time"
)

// Limite concede richieste finché il secchio del client ha gettoni.
// La capienza governa la raffica ammessa, la ricarica il ritmo a regime.
type Limite struct {
	mu       sync.Mutex
	secchi   map[string]*secchio
	capienza float64
	ricarica float64 // gettoni al secondo
	adesso   func() time.Time
}

type secchio struct {
	gettoni float64
	ultimo  time.Time
}

// Nuovo costruisce un limite di «capienza» richieste di raffica, che si
// ricaricano a «alMinuto» richieste al minuto.
func Nuovo(capienza int, alMinuto float64) *Limite {
	if capienza < 1 {
		capienza = 1
	}
	return &Limite{
		secchi:   make(map[string]*secchio),
		capienza: float64(capienza),
		ricarica: alMinuto / 60,
		adesso:   time.Now,
	}
}

// Consenti scala un gettone e dice se la richiesta passa. Quando non passa,
// restituisce anche quanto aspettare prima di riprovare.
func (l *Limite) Consenti(chiave string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()

	ora := l.adesso()
	s, presente := l.secchi[chiave]
	if !presente {
		s = &secchio{gettoni: l.capienza, ultimo: ora}
		l.secchi[chiave] = s
	}

	s.gettoni = min(l.capienza, s.gettoni+ora.Sub(s.ultimo).Seconds()*l.ricarica)
	s.ultimo = ora

	if s.gettoni < 1 {
		mancante := (1 - s.gettoni) / l.ricarica
		return false, time.Duration(mancante * float64(time.Second))
	}
	s.gettoni--
	return true, 0
}

// Pulisci scarta i secchi ormai pieni: senza, la mappa crescerebbe con ogni IP
// mai visto. Va chiamata di tanto in tanto.
func (l *Limite) Pulisci() {
	l.mu.Lock()
	defer l.mu.Unlock()

	ora := l.adesso()
	for chiave, s := range l.secchi {
		if s.gettoni+ora.Sub(s.ultimo).Seconds()*l.ricarica >= l.capienza {
			delete(l.secchi, chiave)
		}
	}
}

// Clienti dice quanti secchi sono in piedi. È un conteggio per il
// monitoraggio, non un elenco di chi ha chiamato.
func (l *Limite) Clienti() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.secchi)
}
