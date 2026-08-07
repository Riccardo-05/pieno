# Pieno — Servizio percorsi

Distanze **su strada** per la classifica e per il risparmio al netto della deviazione.
Piano e ragioni in [`../linee-guida/10-percorsi-e-backend.md`](../linee-guida/10-percorsi-e-backend.md);
questo file è il registro di come è costruito e dei numeri misurati.

```
app  →  API di Pieno (Go, :8080)  →  OSRM (MLD, :5000, solo localhost)
              ↑ cache · limite di frequenza · superficie ridotta
```

**I prezzi non passano di qui.** Restano file statici su CDN. Se questa macchina è spenta —
e lo è **dalle 02:00 alle 08:00** — l'app mostra prezzi, mappa ed elenco e ricade sulla
distanza stimata, dichiarandolo.

## Le tre rotte

| Rotta | A cosa serve |
| --- | --- |
| `POST /v1/distanze` | origine + N destinazioni → metri e secondi per ciascuna. È la classifica. |
| `GET /v1/percorso` | origine + destinazione → metri, secondi e geometria. È la scheda. |
| `GET /v1/salute` | stato, versione del grafo, da quanto è su. Serve all'app e al monitoraggio. |

```bash
curl -X POST http://127.0.0.1:8080/v1/distanze -H 'Content-Type: application/json' \
  -d '{"origine":{"lat":45.464,"lon":9.190},"destinazioni":[{"lat":45.478,"lon":9.227}]}'
# {"distanze":[{"metri":4717,"secondi":636,"raggiungibile":true}],"daCache":0,"dalMotore":1}

curl "http://127.0.0.1:8080/v1/percorso?origine=45.464,9.190&destinazione=45.478,9.227"
curl http://127.0.0.1:8080/v1/salute
```

`raggiungibile: false` non è un errore: è la risposta per le coordinate da cui non si arriva
via strada. Il limite di frequenza risponde **429** con `Retry-After` e un corpo che lo dice.

## I tre comportamenti obbligatori

**Cache** con le coordinate arrotondate a ~100 m (`internal/geo`, 0,001° ≈ 111 m in
latitudine). Lavora **per coppia** origine-destinazione, non per richiesta intera: due
persone nello stesso isolato che guardano impianti diversi si aiutano comunque.
L'arrotondamento non è solo prestazioni — la chiave in cache non è mai la posizione esatta
di qualcuno.

**Limite di frequenza** per client, a secchio di gettoni (`internal/limite`). Il client è
identificato da un'**impronta con sale casuale** dell'IP, che muore col processo: serve a
contare, non a riconoscere. `/v1/salute` resta fuori dal limite, perché il monitoraggio non
dev'essere la prima cosa a sparire sotto pressione.

**Nessun log delle coordinate.** Si registrano metodo, rotta, stato e millisecondi. Mai la
query, mai il corpo: è lì che stanno le posizioni.

## Struttura

| Package | Ruolo |
| --- | --- |
| `internal/geo` | coordinate, validità, arrotondamento a ~100 m e chiavi di cache |
| `internal/motore` | **il contratto**: cosa Pieno chiede a un motore. Non nomina OSRM |
| `internal/osrm` | l'unico punto che sa che il motore è OSRM |
| `internal/cache` | cache in memoria con scadenza e sfratto della meno usata |
| `internal/limite` | limite di frequenza a secchio di gettoni |
| `internal/api` | le tre rotte, il limite, il registro |
| `main.go` | configurazione da ambiente e chiusura ordinata |

Il confine fra `motore` e `osrm` è la regola di progetto per cui ogni dipendenza esterna
dev'essere sostituibile: cambiare motore domani non tocca una riga delle rotte, né dell'app.

## Costruire il grafo

Docker Desktop con back-end WSL2 e `%UserProfile%\.wslconfig` che assegna a WSL **16 GB**
(non è abbondanza: l'estratto italiano ne ha usati 15,7 al picco).

I file del grafo stanno in un **volume Docker** (`pieno-osrm`), mai in un bind mount su
disco Windows: l'I/O attraverso il confine Windows→WSL falserebbe i tempi.

```bash
scripts/ricostruisci-grafo.sh          # scarica, costruisce e scambia in modo atomico
```

## Uso

```bash
go test ./...
go build -o percorsi.exe .
PERCORSI_ASCOLTO=127.0.0.1:8080 ./percorsi.exe
```

| Variabile | Predefinito | |
| --- | --- | --- |
| `PERCORSI_ASCOLTO` | `127.0.0.1:8080` | dove ascolta l'API |
| `PERCORSI_MOTORE` | `http://127.0.0.1:5000` | dove sta OSRM |
| `PERCORSI_MAX_DESTINAZIONI` | `100` | destinazioni per richiesta |
| `PERCORSI_VOCI_CACHE` | `200000` | coppie tenute in cache |
| `PERCORSI_DURATA_CACHE` | `24h` | durata di una voce |
| `PERCORSI_RAFFICA` | `30` | richieste di raffica per client |
| `PERCORSI_AL_MINUTO` | `60` | ricarica, richieste al minuto |
| `PERCORSI_FILE_VERSIONE` | `versione-grafo.txt` | riga letta da `/v1/salute` |

OSRM è pubblicato **solo su `127.0.0.1:5000`**: non è raggiungibile dalla rete locale, e il
tunnel della Fase 3 punta all'API, non al motore.

## I numeri misurati

MagicNUC · Ryzen 7 · 32 GB DDR5 · SSD 1 TB · Windows 11 · WSL2 con 16 GB e 8 core.
Estratto `italy-latest.osm.pbf` di Geofabrik (2,1 GB, md5 verificato), profilo `car`,
algoritmo **MLD**. Misure del 7 agosto 2026.

| Passo | Tempo | Picco RAM |
| --- | --- | --- |
| `osrm-extract` | 564 s | **15,69 GB** |
| `osrm-partition` | 144 s | 4,56 GB |
| `osrm-customize` | 19 s | 2,90 GB |
| **totale** | **727 s** (~12 min) | |

Il grafo copre 31,9 milioni di coordinate e 21,0 milioni di archi.

| Spazio su disco (volume `pieno-osrm`) | |
| --- | --- |
| estratto `.osm.pbf` | 2,1 GB |
| file del grafo | 5,0 GB |
| **totale** | **7,1 GB** |

| A regime | |
| --- | --- |
| RAM di `osrm-routed` | 4,26 GB |
| **matrice verso 50 destinazioni** | **16–33 ms** (obiettivo: < 200 ms) |
| `/v1/distanze`, 50 destinazioni, cache vuota | 23,7 ms |
| `/v1/distanze`, 50 destinazioni, cache piena | 1,5–3,7 ms |

L'estrazione è il collo di bottiglia, ed è quella che vuole i 16 GB: con il default di WSL
(metà della RAM fisica) su questa macchina passerebbe, ma con poco margine.

## Esporre il servizio (Fase 3) — in attesa del dominio

`cloudflared` è installato. Manca **una zona su Cloudflare**, cioè un dominio (~10 €/anno
al costo su Cloudflare Registrar): il Tunnel la richiede. Non è una spesa solo per questo —
l'informativa privacy deve comunque stare a un URL pubblico per le schede store.

Il demone apre una connessione **in uscita** e Cloudflare pubblica il nome con HTTPS valido:
nessuna porta aperta sul modem, IP di casa invisibile, certificati automatici.

```powershell
cloudflared tunnel login                      # apre il browser, scegli la zona
cloudflared tunnel create pieno-percorsi      # annota l'UUID stampato
cloudflared tunnel route dns pieno-percorsi percorsi.<dominio>
```

Poi `%UserProfile%\.cloudflared\config.yml`:

```yaml
tunnel: pieno-percorsi
credentials-file: C:\Users\<utente>\.cloudflared\<UUID>.json

ingress:
  # Il tunnel punta all'API, MAI a OSRM: il motore non si espone.
  - hostname: percorsi.<dominio>
    service: http://127.0.0.1:8080
  - service: http_status:404
```

```powershell
cloudflared service install    # riparte da solo dopo l'accensione delle 08:00
```

**Esito da verificare:** `https://percorsi.<dominio>/v1/salute` risponde da fuori casa con
certificato valido, e nessuna porta risulta aperta sul modem.

Fatto questo, l'app va costruita con l'URL:

```bash
flutter build apk --dart-define=PIENO_PERCORSI=https://percorsi.<dominio>
```

Senza `--dart-define` l'app non contatta nulla e resta sulla stima dichiarata: è il
comportamento corretto finché il dominio non c'è.

## Il fattore stradale (Fase 5)

```bash
go run ./cmd/fattori -uscita fattori-stradali.json
```

Per ogni impianto misura il rapporto mediano fra distanza su strada e linea d'aria da otto
punti attorno a 2 km e otto attorno a 5 km. Ne esce **un numero per impianto** — 1,18 per
quello sulla statale, 2,40 per quello di là dal fiume. La mediana e non la media: un punto
finito in una zona pedonale sposterebbe la media, la mediana quasi no.

Dove meno di metà delle misure riesce, il fattore **non viene scritto**: meglio nessun
numero che un numero inventato, e l'app resta alla linea d'aria pura.

Il file lo incorpora la pipeline dati nella build notturna:

```bash
python -m pieno_pipeline.pipeline --scarica --fattori ../percorsi/fattori-stradali.json
```

È **facoltativo**: la build gira su GitHub Actions e non deve dipendere da una macchina di
casa. Senza il file i record escono senza `fs`, e va bene lo stesso.

Prova su una sola provincia: `go run ./cmd/fattori -provincia AO`. In Valle d'Aosta escono
fattori fra 1,9 e 3,5 — una valle dove non si va mai dritti è esattamente il posto in cui
la linea d'aria mente di più.

## Manutenzione

**Ricostruzione mensile con scambio atomico:** `scripts/ricostruisci-grafo.sh` costruisce il
nuovo grafo mentre il vecchio serve le richieste, verifica che risponda, e solo allora
scambia. Se la costruzione fallisce resta in piedi quella buona — lo stesso principio della
pubblicazione atomica della pipeline dati.

Va programmata **dentro la finestra di veglia** (domenica 09:00, mai a cavallo delle 02:00):
`scripts/programma-manutenzione.ps1` registra l'attività nell'Utilità di pianificazione.

`/v1/salute` dice versione del grafo e da quanto è su: senza, un grafo vecchio di mesi non
se ne accorgerebbe nessuno.

## Attribuzioni

Percorsi calcolati con [OSRM](https://project-osrm.org) (BSD-2-Clause) su dati
© OpenStreetMap contributors (ODbL), estratto da [Geofabrik](https://download.geofabrik.de).
