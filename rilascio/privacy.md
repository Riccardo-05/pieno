# Informativa sulla privacy — Pieno

*Ultimo aggiornamento: da definire (data di pubblicazione).*

Titolare del trattamento: **da definire** (nome ed email di contatto richiesti dagli store).

Pieno mostra i prezzi dei carburanti in Italia a partire dai dati aperti del Ministero.
È pensata per raccogliere il **minimo indispensabile** e funzionare senza account.

## Dati trattati

- **Posizione** *(facoltativa)*: viene acquisito **un solo rilevamento** a precisione
  bilanciata. Serve sul dispositivo a scegliere la provincia più vicina e a ordinare gli
  impianti. Senza permesso l'app funziona lo stesso.
  Se il **servizio percorsi** è attivo (vedi sotto), la posizione viene inviata a quel
  servizio insieme alle coordinate degli impianti, per ottenere le distanze **su strada**
  invece che in linea d'aria. Non viene inviata da nessun'altra parte.
- **Preferenze** (carburante, navigatore, ordinamento, raggio, capacità serbatoio, ecc.):
  salvate **solo localmente** sul dispositivo.
- **Segnalazioni di prezzo errato**: restano in **coda locale** sul dispositivo. Finché non
  esiste un servizio dati non vengono trasmesse.

## Il servizio percorsi

Le distanze su strada le calcola un servizio nostro, ospitato su una macchina in Italia.
È l'**unico** caso in cui la tua posizione lascia il telefono, e vale la pena dire con
precisione che cosa succede — perché è poco:

- La richiesta contiene la tua posizione e le coordinate degli impianti da confrontare.
  Nient'altro: nessun identificativo, nessun account, nessun cookie.
- Le coordinate **non vengono registrate**. Nei log finiscono soltanto conteggi e tempi di
  risposta.
- La posizione viene **arrotondata a circa 100 metri appena arriva**, prima di qualunque
  calcolo: il motore che traccia le strade non riceve mai la tua posizione esatta, solo la
  cella in cui ti trovi. Entro cento metri la strada da prendere è la stessa, quindi non
  perdi niente in precisione.
- Sulla stessa cella si appoggia la cache che evita di rifare due volte lo stesso calcolo.
  Sta in memoria, non su disco, e sparisce quando il servizio si ferma.
- Per difendersi dagli abusi il servizio conta le richieste per client. Non conserva
  l'indirizzo IP: ne tiene un'**impronta con un numero casuale** che cambia a ogni riavvio.
- Il servizio può essere spento (di notte lo è). Quando non risponde, l'app **ricade sulla
  distanza stimata e te lo dice**: non aspetta e non riprova all'infinito.

Se nella tua versione dell'app il servizio non è configurato, l'app non contatta nulla e
usa solo la stima.

## Cosa NON facciamo

- Nessun **account obbligatorio**.
- Nessun **tracciamento pubblicitario**, nessun profilo, nessuna vendita di dati.
- Nessuna **registrazione** delle posizioni: né sul telefono né sul servizio percorsi.

## Servizi esterni

- Aprendo **«Portami qui»** le coordinate dell'impianto vengono passate all'app di
  navigazione scelta (Apple Maps, Google Maps o Waze), soggetta alla **loro** informativa.
- La mappa usa tile di OpenFreeMap / OpenStreetMap.

## Attribuzioni

- Dati carburanti: **Ministero delle Imprese e del Made in Italy — IODL 2.0**.
- Mappa: **© OpenStreetMap contributors**.

## Diritti dell'utente

Non c'è un profilo da consultare o cancellare da remoto, perché non ne esiste nessuno: il
servizio percorsi non conserva né le posizioni né chi le ha chieste. Disinstallando l'app o
svuotandone i dati si rimuove tutto ciò che è salvato in locale.
Per domande: **da definire (email di contatto)**.

## Modifiche

Eventuali aggiornamenti saranno pubblicati a questo indirizzo (URL di hosting: da definire,
es. GitHub Pages accanto ai dati).
