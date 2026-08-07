package geo

import "testing"

func TestArrotondaRiduceAllaStessaCella(t *testing.T) {
	// Due posizioni a poche decine di metri l'una dall'altra devono dare la
	// stessa chiave: è il presupposto del tasso di successo della cache.
	casi := []struct {
		nome   string
		a, b   Punto
		uguali bool
	}{
		{"stessa cella, scarto di ~20 m", Punto{45.4641, 9.1901}, Punto{45.4643, 9.1903}, true},
		{"celle diverse, scarto di ~500 m", Punto{45.4641, 9.1901}, Punto{45.4691, 9.1901}, false},
		{"segno negativo vicino allo zero", Punto{0.0001, -0.0001}, Punto{-0.0002, 0.0002}, true},
	}
	for _, c := range casi {
		t.Run(c.nome, func(t *testing.T) {
			if uguali := c.a.Chiave() == c.b.Chiave(); uguali != c.uguali {
				t.Fatalf("chiavi %q e %q: uguali=%v, atteso %v", c.a.Chiave(), c.b.Chiave(), uguali, c.uguali)
			}
		})
	}
}

func TestChiaveNonContieneLaPosizioneEsatta(t *testing.T) {
	p := Punto{45.4641234, 9.1901987}
	if got, want := p.Chiave(), "45.464,9.190"; got != want {
		t.Fatalf("chiave = %q, atteso %q", got, want)
	}
}

func TestValido(t *testing.T) {
	casi := []struct {
		p     Punto
		esito bool
	}{
		{Punto{45.46, 9.19}, true},
		{Punto{-90, -180}, true},
		{Punto{90.1, 9.19}, false},
		{Punto{45.46, 180.1}, false},
	}
	for _, c := range casi {
		if got := c.p.Valido(); got != c.esito {
			t.Errorf("Valido(%v) = %v, atteso %v", c.p, got, c.esito)
		}
	}
}

func TestDaTesto(t *testing.T) {
	p, err := DaTesto(" 45.4641 , 9.1901 ")
	if err != nil {
		t.Fatalf("errore inatteso: %v", err)
	}
	if p.Lat != 45.4641 || p.Lon != 9.1901 {
		t.Fatalf("punto = %v", p)
	}
	for _, s := range []string{"45.4641", "abc,9.19", "45.46,xyz", "91,9.19"} {
		if _, err := DaTesto(s); err == nil {
			t.Errorf("DaTesto(%q) doveva fallire", s)
		}
	}
}

func TestVersoOSRMMetteLaLongitudinePrima(t *testing.T) {
	if got, want := (Punto{45.4641, 9.1901}).VersoOSRM(), "9.190100,45.464100"; got != want {
		t.Fatalf("VersoOSRM = %q, atteso %q", got, want)
	}
}
