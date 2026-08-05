# Architettura

Stack, file per provincia, job notturno (pagina 11 del documento di progetto). Piano d'azione: tecnologie, tutte a costo zero.

## Stack

| Ambito | Scelta e motivo |
| --- | --- |
| App | Flutter (Dart) — una base di codice per iOS e Android, controllo sul rendering. |
| Stato | Riverpod — stato condiviso tra mappa ed elenco, test facili sui calcoli di risparmio. |
| Dati locali | Drift o Isar — l'ultima zona resta su disco: l'app apre sempre con qualcosa. |
| Mappa | MapLibre + OpenFreeMap: istanza pubblica gratuita, senza chiave né limiti dichiarati. Piano B: tile auto-ospitate. |
| Dati prezzi | Open data MIMIT, licenza IODL 2.0 con attribuzione obbligatoria. |
| Elaborazione | Job notturno su GitHub Actions: scarica, valida, pubblica file statici per provincia. |
| Distribuzione | GitHub Pages o Cloudflare Pages: CDN gratuita, nessun server da gestire. |
| Backend vero | Solo quando servirà: Go o Node + PostgreSQL con PostGIS e cache Redis. |
| Errori e crash | Sentry (piano gratuito) o Crashlytics. |

## Le uniche spese non evitabili

Pubblicare sugli store: 99 $ all'anno per Apple, 25 $ una tantum per Google. Finché si resta in prova non si paga nulla: APK Android distribuita a mano e build iOS firmate gratuitamente, valide sette giorni sul proprio dispositivo.

## Perché niente server all'inizio

L'intero dataset nazionale è piccolo: ventitremila impianti con quattro carburanti stanno in pochi megabyte. I quattro carburanti considerati sono **Benzina, Gasolio (diesel), GPL, Metano** (forma canonica in `05-dati-e-qualita.md`; nomi definiti dal committente, il PDF indica solo il numero). Tagliato per provincia e compresso, ogni file scaricato dall'app pesa poche centinaia di chilobyte e viene servito da una CDN gratuita. Il filtro per raggio e il calcolo del risparmio avvengono sul telefono.

Il server con PostGIS serve quando arrivano le funzioni che il telefono non può fare da solo: confronto lungo un percorso su scala nazionale, storico dei prezzi, aggregazione delle segnalazioni. Non prima.

## Attribuzioni obbligatorie

- «Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0» nella schermata Impostazioni e nella scheda dello store.
- «© OpenStreetMap contributors» visibile sulla mappa.
- Se si userà un servizio di percorsi, la relativa attribuzione secondo la sua licenza.

## Regola di spesa

Nessun servizio a pagamento entra nel progetto prima che esista una funzione che gli utenti usano davvero. Ogni dipendenza esterna deve essere sostituibile: mappa, percorsi e ospitalità passano tutti dietro un'interfaccia.

## Fluidità e risposta

- Tutto il filtro sul telefono nella prima fase: la zona è già in memoria, il raggio e l'ordinamento non richiedono rete.
- File per provincia serviti da CDN, con intestazioni di cache lunghe e nome versionato: si riscarica solo quando cambia.
- Offline-first: l'ultima zona resta su disco. L'app non mostra mai una schermata vuota all'apertura, al massimo un dato dichiarato come vecchio.
- Prefetch direzionale: mentre l'utente si muove, si scarica la provincia confinante nella direzione di marcia.
- Un solo GPS fix per aprire: precisione «bilanciata», non massima, che costa secondi e batteria.
- Quando arriverà il server: `ST_DWithin` su indice GIST e risposte pre-aggregate per cella, con cache di 10 minuti.

## Obiettivi di prestazione

| Soglia | Metrica |
| --- | --- |
| < 1 s | dal tocco sull'icona al primo prezzo utile a schermo |
| p95 < 120 ms | risposta dell'API «vicini», quando esisterà |
| 60 fps | durante scorrimento e trascinamento della mappa |
| > 99,5% | sessioni senza crash |
