package limite

import (
	"testing"
	"time"
)

func TestLaRafficaSiFermaAllaCapienza(t *testing.T) {
	adesso := time.Now()
	l := Nuovo(3, 60) // 3 di raffica, 1 al secondo a regime
	l.adesso = func() time.Time { return adesso }

	for i := range 3 {
		if ok, _ := l.Consenti("cliente"); !ok {
			t.Fatalf("richiesta %d doveva passare", i+1)
		}
	}
	ok, attesa := l.Consenti("cliente")
	if ok {
		t.Fatal("la quarta richiesta doveva essere respinta")
	}
	if attesa <= 0 {
		t.Fatalf("l'attesa suggerita deve essere positiva, era %v", attesa)
	}
}

func TestIlSecchioSiRicarica(t *testing.T) {
	adesso := time.Now()
	l := Nuovo(1, 60)
	l.adesso = func() time.Time { return adesso }

	l.Consenti("cliente")
	if ok, _ := l.Consenti("cliente"); ok {
		t.Fatal("secchio vuoto, non doveva passare")
	}
	adesso = adesso.Add(time.Second)
	if ok, _ := l.Consenti("cliente"); !ok {
		t.Fatal("dopo un secondo doveva esserci un gettone")
	}
}

func TestClientiSeparati(t *testing.T) {
	l := Nuovo(1, 60)
	l.Consenti("uno")
	if ok, _ := l.Consenti("due"); !ok {
		t.Fatal("il limite di un client non deve toccare gli altri")
	}
}

func TestPulisciToglieISecchiPieni(t *testing.T) {
	adesso := time.Now()
	l := Nuovo(2, 60)
	l.adesso = func() time.Time { return adesso }

	l.Consenti("uno")
	if l.Clienti() != 1 {
		t.Fatalf("clienti = %d", l.Clienti())
	}
	adesso = adesso.Add(time.Minute) // il secchio torna pieno
	l.Pulisci()
	if l.Clienti() != 0 {
		t.Fatalf("dopo la pulizia clienti = %d, atteso 0", l.Clienti())
	}
}
