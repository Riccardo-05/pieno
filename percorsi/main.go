// Comando percorsi: l'API di Pieno davanti al motore di instradamento.
//
// Un binario unico, nessuna dipendenza di runtime, nessun database: la cache
// sta in memoria e si ricostruisce da sé. Vedi linee-guida/10-percorsi-e-backend.md.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/riccardo-05/pieno/percorsi/internal/api"
	"github.com/riccardo-05/pieno/percorsi/internal/osrm"
)

func main() {
	registro := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(registro)

	ascolto := ambiente("PERCORSI_ASCOLTO", "127.0.0.1:8080")
	indirizzoMotore := ambiente("PERCORSI_MOTORE", "http://127.0.0.1:5000")

	servizio := api.Nuovo(
		osrm.Nuovo(indirizzoMotore, durata("PERCORSI_SCADENZA_MOTORE", 5*time.Second)),
		api.Config{
			MaxDestinazioni:   intero("PERCORSI_MAX_DESTINAZIONI", 100),
			VociCache:         intero("PERCORSI_VOCI_CACHE", 200_000),
			DurataCache:       durata("PERCORSI_DURATA_CACHE", 24*time.Hour),
			RafficaClient:     intero("PERCORSI_RAFFICA", 30),
			RichiesteAlMinuto: float64(intero("PERCORSI_AL_MINUTO", 60)),
			FileVersione:      ambiente("PERCORSI_FILE_VERSIONE", "versione-grafo.txt"),
			// Chi può dichiarare l'indirizzo di qualcun altro. Vuoto = solo questa
			// macchina, dove gira il tunnel: è la configurazione di casa, e va bene
			// così finché il proxy non si sposta altrove.
			ProxyFidati: elenco("PERCORSI_PROXY_FIDATI"),
			Log:         registro,
		},
	)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go servizio.PulisciOgni(ctx, 5*time.Minute)

	server := &http.Server{
		Addr:              ascolto,
		Handler:           servizio.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		registro.Info("in ascolto", "indirizzo", ascolto, "motore", indirizzoMotore)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			registro.Error("il server si è fermato", "errore", err.Error())
			stop()
		}
	}()

	<-ctx.Done()
	registro.Info("chiusura in corso")

	// Le richieste in volo hanno trenta secondi per finire: alle 02:00 la
	// macchina si spegne, e non è il caso di troncare una risposta a metà.
	chiusura, annulla := context.WithTimeout(context.Background(), 30*time.Second)
	defer annulla()
	if err := server.Shutdown(chiusura); err != nil {
		registro.Error("chiusura non pulita", "errore", err.Error())
	}
}

func ambiente(chiave, valorePredefinito string) string {
	if v := os.Getenv(chiave); v != "" {
		return v
	}
	return valorePredefinito
}

// elenco legge una lista separata da virgole. Vuoto resta vuoto: chi la consuma
// sa quale sia il suo default, e non è compito di qui indovinarlo.
func elenco(chiave string) []string {
	grezzo := strings.TrimSpace(os.Getenv(chiave))
	if grezzo == "" {
		return nil
	}
	var voci []string
	for _, v := range strings.Split(grezzo, ",") {
		if v = strings.TrimSpace(v); v != "" {
			voci = append(voci, v)
		}
	}
	return voci
}

func intero(chiave string, valorePredefinito int) int {
	v, err := strconv.Atoi(os.Getenv(chiave))
	if err != nil || v <= 0 {
		return valorePredefinito
	}
	return v
}

func durata(chiave string, valorePredefinito time.Duration) time.Duration {
	v, err := time.ParseDuration(os.Getenv(chiave))
	if err != nil || v <= 0 {
		return valorePredefinito
	}
	return v
}
