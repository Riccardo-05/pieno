# Percorsi e backend

Piano d'azione per il servizio percorsi auto-ospitato, con le ragioni di ogni scelta.
Questo documento è la fonte di verità dell'implementazione: chi la esegue parte da qui.

## Perché esiste

Le distanze dell'app sono **in linea d'aria**, e questo non è un dettaglio estetico: falsa
la classifica. Due impianti a 4 km da te possono essere uno a 4,5 km di strada e l'altro a
11, e l'app oggi li presenta come equivalenti. Peggio, il «risparmi X € sul pieno» è
**lordo**: un impianto lontano che costa tre centesimi meno sembra conveniente anche quando
il viaggio per raggiungerlo costa più di quanto fa risparmiare.

Il documento di progetto lo aveva previsto — «al netto della deviazione», pag. 2 — e la
formula è rimasta a `deviazioneEuro = 0`, «da definire». Con le distanze reali quel debito
si può finalmente pagare, e il numero che l'app mostra diventa quello che resta in tasca.

## Che cosa NON cambia

**I prezzi restano su GitHub Pages.** Il server di casa serve solo per i percorsi. Se casa
va giù, l'app continua a mostrare prezzi, mappa ed elenco, e perde le distanze reali —
non tutto. Barattare una CDN che non cade mai con una connessione residenziale sarebbe un
pessimo scambio, e violerebbe l'offline-first che regge l'intera architettura.

Vale anche per il futuro: le segnalazioni e gli account arriveranno su questo server, ma
il **dato pubblico** resta statico e servito da CDN.

## L'ambiente

| | |
| --- | --- |
| Macchina | MagicNUC · Ryzen 7 · 32 GB DDR5 · SSD 1 TB · Windows |
| Rete | IP locale fisso `192.168.1.254` |
| Accensione | **spento dalle 02:00 alle 08:00** |
| Esposizione | Cloudflare Tunnel (nessuna porta aperta) |

Le sei ore di spegnimento non sono un ostacolo, sono un **requisito di progetto**: l'app
deve funzionare lo stesso, e ogni lavoro programmato deve stare nella finestra di veglia.

## Le scelte, con le ragioni

**Motore: OSRM.** Con 32 GB la memoria non è un vincolo, e OSRM è il più veloce sulle
**matrici** — «da qui verso 50 impianti in una richiesta sola», che è esattamente il caso
d'uso della classifica. Valhalla sarebbe stato la scelta obbligata sotto i 16 GB (lavora a
tessere su disco), e resta il piano B se un domani servissero isocrone o profili multipli.
Algoritmo **MLD** (`partition` + `customize`) e non CH: ricostruire il grafo mensilmente
costa molto meno tempo.

**API di Pieno davanti al motore, sempre.** OSRM non si espone mai direttamente. Il livello
davanti fa tre cose che il motore non fa: **cache**, **limite di frequenza** e **superficie
ridotta**. Ma soprattutto tiene in piedi la regola del progetto per cui ogni dipendenza
esterna dev'essere sostituibile: l'app parla al *nostro* contratto, non a OSRM, e cambiare
motore domani non tocca una riga dell'app.

**Linguaggio: Go.** Le linee guida dicono «Go o Node». Go dà un binario unico senza
dipendenze di runtime, consuma pochissimo e regge bene un servizio che deve stare acceso
per mesi su una macchina Windows. Node resta accettabile se chi implementa lo preferisce,
ma allora Fastify e niente altro.

**Niente database, niente Redis.** In questa fase non c'è nulla da persistere: la cache sta
in memoria e si ricostruisce da sola. PostgreSQL e Redis arriveranno con le segnalazioni,
come dicono già le linee guida — «solo quando servirà».

**Cloudflare Tunnel invece delle porte aperte.** Il demone apre una connessione **in
uscita** e Cloudflare pubblica il dominio con HTTPS valido: nessuna porta aperta sul modem,
IP di casa invisibile, certificati automatici, protezione DDoS inclusa nel piano gratuito.
Con le porte aperte servirebbero DDNS, certificati da rinnovare e un IP residenziale
esposto — più lavoro e più superficie d'attacco per lo stesso risultato.

**Serve un dominio** (~10 €/anno, al costo su Cloudflare Registrar): il Tunnel richiede una
zona nel proprio account. È la prima spesa ricorrente del progetto oltre alla corrente, e
si ripaga subito perché **serve comunque**: l'informativa privacy deve stare a un URL
pubblico raggiungibile per le schede store (voce aperta della checklist di rilascio). Un
dominio, due problemi risolti.

## Le fasi

Ognuna si chiude con qualcosa di verificabile. Non si passa alla successiva prima.

### Stato di avanzamento

| Fase | Stato | Esito misurato |
| --- | --- | --- |
| 1 · Motore | ✅ conclusa | Grafo italiano MLD nel volume Docker `pieno-osrm`. Matrice verso 50 destinazioni in **16–33 ms** (obiettivo < 200 ms). Numeri in [`../percorsi/README.md`](../percorsi/README.md). |
| 2 · API | ✅ conclusa | Servizio Go in [`../percorsi/`](../percorsi). Le tre rotte rispondono su dati veri; la cache porta la stessa richiesta da 23,7 ms a 1,5–3,7 ms. |
| 3 · Esposizione | ⏸ **in attesa del dominio** | `cloudflared` installato, procedura scritta nel README del servizio. Serve una zona Cloudflare: è l'unico passo che richiede una spesa e un account, e resta a chi possiede il progetto. |
| 4 · L'app parla all'API | ✅ conclusa | `app/lib/data/percorsi_repository.dart` dietro interfaccia, tetto di 2 s, ripiego dichiarato, cache a 300 m, nessun tentativo ripetuto a vuoto. |
| 5 · Fattori stradali | ✅ conclusa | `percorsi/cmd/fattori` calcola il rapporto mediano; la pipeline lo incorpora come `fs` (`--fattori`); l'app lo usa nella stima. |
| 6 · Risparmio netto | ✅ conclusa | `costoDeviazione()` e la voce «Consumo medio» nel gruppo Rifornimento. Il risparmio mostrato è netto quando le distanze sono reali. |

La Fase 3 è ferma per una ragione dichiarata, non per una dimenticanza: **senza dominio non
c'è tunnel**. Fino ad allora l'app non contatta nulla e resta sulla stima, dicendolo — che è
lo stesso comportamento previsto per le sei ore di spegnimento, quindi non è una strada mai
percorsa: è quella che si percorre un quarto delle giornate.

### Fase 1 · Il motore, solo in casa

Docker Desktop con back-end WSL2. In `%UserProfile%\.wslconfig` si assegna a WSL una
memoria sufficiente (16 GB bastano con abbondanza; il default è metà della RAM fisica).

Estratto `italy-latest.osm.pbf` da Geofabrik, poi `osrm-extract` con il profilo `car`,
`osrm-partition`, `osrm-customize`. **I file del grafo vanno tenuti nel filesystem di WSL o
in un volume Docker, mai in un bind mount su disco Windows**: l'I/O attraverso il confine
Windows→WSL è lento al punto da falsare i tempi.

Nessuna porta pubblicata verso l'esterno. Si prova dalla rete locale.

**Esito:** una matrice verso 50 destinazioni che risponde in meno di 200 ms, e i numeri
misurati di RAM occupata, tempo di costruzione e spazio su disco annotati nel README del
servizio.

### Fase 2 · L'API di Pieno

Servizio in `percorsi/`, tre rotte versionate:

| Rotta | A cosa serve |
| --- | --- |
| `POST /v1/distanze` | origine + N destinazioni → metri e secondi per ciascuna. È la classifica. |
| `GET /v1/percorso` | origine + destinazione → metri, secondi e geometria. È la scheda e l'anteprima del percorso. |
| `GET /v1/salute` | stato del servizio e versione del grafo. Serve all'app e al monitoraggio. |

Tre comportamenti obbligatori:

- **Cache** con le coordinate arrotondate a ~100 m. In città la stessa richiesta si ripete
  moltissimo: il tasso di successo sarà altissimo e il motore quasi non verrà interrogato.
  L'arrotondamento non è solo prestazioni — è anche privacy, perché la chiave in cache non
  è mai la posizione esatta di qualcuno.
- **Limite di frequenza** per client, con risposta esplicita quando scatta.
- **Nessun log delle coordinate.** Si registrano conteggi e tempi, non posizioni. È ciò che
  permette di scrivere un'informativa privacy corta e vera.

**Esito:** le tre rotte rispondono in locale con dati veri e la cache mostra il suo effetto
sui tempi.

### Fase 3 · Esposizione

`cloudflared` come servizio di Windows, così riparte da solo dopo l'accensione delle 08:00.
Il tunnel punta all'API, **non** a OSRM. Sul dominio si pubblica un solo nome, es.
`percorsi.<dominio>`.

**Esito:** `https://percorsi.<dominio>/v1/salute` risponde da fuori casa, con certificato
valido, e nessuna porta risulta aperta sul modem.

### Fase 4 · L'app parla all'API

Nuovo repository lato app dietro un'interfaccia, con **tetto di tempo di due secondi**. Se
il server non risponde — di notte è spento, e sono sei ore su ventiquattro — si ricade
sulla distanza in linea d'aria e **lo si dichiara**, esattamente come si fa già col dato
salvato quando manca la rete.

Cache sul telefono: finché non ti sposti di qualche centinaio di metri non si richiede
nulla. E niente tentativi ripetuti a vuoto quando il servizio è irraggiungibile.

**Esito:** distanze reali quando il server c'è, stima dichiarata quando non c'è, e nessun
rallentamento percepibile nei due casi.

### Fase 5 · Fattori stradali precalcolati

Per ogni impianto si calcola, con lo stesso OSRM, il rapporto mediano fra distanza su
strada e distanza in linea d'aria da otto punti attorno a 2 e 5 km. Ne esce **un numero per
impianto** — `1,18` per quello sulla statale, `2,40` per quello di là dal fiume — che pesa
pochissimo e finisce nel file di provincia.

Serve come **paracadute**: quando il server è spento, la stima resta molto più vicina al
vero della linea d'aria pura. Il calcolo gira sul mini PC una volta al mese, nella finestra
di veglia, e produce un file che la pipeline dati incorpora nella build notturna.

**Esito:** i file di provincia contengono il fattore, e con il server spento la distanza
mostrata resta ragionevole.

### Fase 6 · Il risparmio diventa vero

Costo della deviazione calcolato sui chilometri reali, rispetto all'impianto più vicino:
chi è già il più vicino non paga nulla, gli altri pagano i chilometri in più, andata e
ritorno, al consumo dichiarato dall'utente. Serve una voce **consumo medio** nel gruppo
«Rifornimento», accanto alla capacità del serbatoio.

Il risparmio mostrato diventa netto. **Metti in conto che i numeri caleranno** e che in
alcune zone la pastiglia sparirà: non è un peggioramento, è l'app che smette di promettere
risparmi che non esistono.

**Esito:** un impianto lontano non risulta più conveniente di uno vicino quando non lo è.

## Manutenzione

**Ricostruzione mensile del grafo** con **scambio atomico**: si costruisce il nuovo grafo
mentre il vecchio serve le richieste, si verifica, e solo allora l'API cambia motore. È lo
stesso principio della pubblicazione atomica della pipeline dati — se la costruzione
fallisce, resta in piedi quella buona.

Va programmata **dentro la finestra di veglia** (es. domenica alle 09:00, Utilità di
pianificazione di Windows), mai a cavallo delle 02:00.

**Monitoraggio minimo:** `/v1/salute` deve dire da quanto è su e con che versione del
grafo. Senza, un grafo vecchio di mesi non se ne accorge nessuno.

## Privacy: la cosa che cambia davvero

Oggi l'app ha una storia semplice — **niente lascia il telefono**. Con i percorsi, posizione
e destinazione arrivano a un server. È un cambiamento sostanziale e va scritto in
`rilascio/privacy.md` **prima** del rilascio, non dopo.

Il modo per tenerla corta è progettuale, non redazionale: **non registrare nulla di
identificabile**. Nessun log delle coordinate, cache con chiavi arrotondate a 100 m, nessun
identificativo utente, nessun cookie. Così l'informativa dice il vero in tre righe, e il
titolare del trattamento — che diventi tu — ha poco da custodire.

## Dopo, non adesso

Le **segnalazioni** con la regola delle tre conferme, gli **account** con la
sincronizzazione e le **notifiche** vivranno sullo stesso server, con PostgreSQL. Sono
un'altra cosa e non devono ritardare i percorsi: si affrontano quando le Fasi 1–6 sono
chiuse e in uso.
