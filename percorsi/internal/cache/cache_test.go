package cache

import (
	"testing"
	"time"
)

func TestPrendiEMetti(t *testing.T) {
	c := Nuova[int](10, time.Minute)
	if _, trovato := c.Prendi("a"); trovato {
		t.Fatal("cache vuota non doveva trovare nulla")
	}
	c.Metti("a", 42)
	valore, trovato := c.Prendi("a")
	if !trovato || valore != 42 {
		t.Fatalf("Prendi(a) = %v, %v", valore, trovato)
	}
}

func TestScadenza(t *testing.T) {
	adesso := time.Now()
	c := Nuova[int](10, time.Minute)
	c.adesso = func() time.Time { return adesso }

	c.Metti("a", 1)
	adesso = adesso.Add(61 * time.Second)
	if _, trovato := c.Prendi("a"); trovato {
		t.Fatal("la voce scaduta non doveva essere restituita")
	}
}

func TestSfrattoDellaMenoUsata(t *testing.T) {
	c := Nuova[int](2, time.Minute)
	c.Metti("a", 1)
	c.Metti("b", 2)
	c.Prendi("a")   // «a» torna in cima
	c.Metti("c", 3) // sfratta «b», la più vecchia per uso

	if _, trovato := c.Prendi("b"); trovato {
		t.Error("«b» doveva essere sfrattata")
	}
	if _, trovato := c.Prendi("a"); !trovato {
		t.Error("«a» doveva restare")
	}
}

func TestMisureContanoIlTasso(t *testing.T) {
	c := Nuova[int](10, time.Minute)
	c.Metti("a", 1)
	c.Prendi("a") // successo
	c.Prendi("z") // buco

	m := c.Misure()
	if m.Letture != 2 || m.Successi != 1 || m.Tasso != 0.5 {
		t.Fatalf("misure = %+v", m)
	}
}
