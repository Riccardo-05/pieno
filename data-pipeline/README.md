# Pieno — Data pipeline (Tappa 01)

Job dei dati: scarica i due CSV MIMIT, li valida con le regole di pag. 12, genera file
statici **per provincia** (compatti e versionati) e un **report di qualità**. È la «prima
riga da scrivere» (linee-guida/00-README.md): senza dati puliti e datati non c'è niente da
mostrare in nessuna schermata.

Catena di lavorazione (linee-guida/05-dati-e-qualita.md):

```
scarico → analisi → validazione → normalizzazione marchi →
controllo geografico → deduplica → storico → arricchimento orari → pubblicazione atomica
```

| Modulo | Ruolo |
| --- | --- |
| `sources.py` | scarico dei CSV e rilettura dell'ultima build (storico per R4) |
| `parsing.py` | codifica/separatore, mappatura nel modello, **solo prezzi self** |
| `validation.py` | le sei regole di pag. 12 (la settima è «da definire») |
| `geo.py` | distanze, coordinate invertite, confini comunali (R1, non collegata) |
| `orari.py` | orari di apertura da OpenStreetMap, abbinati per vicinanza |
| `report.py` | misure di controllo e **esito della pubblicazione** |
| `build.py` | file per provincia, manifest, scambio atomico |
| `pipeline.py` | orchestrazione e CLI |

## Requisiti

- Python 3.12 (in CI) / 3.9+ in locale.
- `pip install -r requirements.txt`

## Uso

```bash
# 1) Test del validatore
python -m unittest discover -s tests -v

# 2) Esecuzione con file locali (sviluppo)
python -m pieno_pipeline.pipeline --anagrafica anagrafica.csv --prezzi prezzo_alle_8.csv

# 3) Esecuzione con scarico reale dalle URL di config.yaml
python -m pieno_pipeline.pipeline --scarica
```

Output in `build/public/`:

- `manifest.json` — versione, elenco province, sha256 per file. Ogni provincia porta il
  **baricentro** e il **riquadro** che contiene i suoi impianti: il secondo serve all'app
  per non sbagliare provincia sui confini, dove il baricentro da solo manda chi sta alle
  porte di Monza su Milano.
- `province/{SIGLA}.json` — impianti e prezzi della provincia (chiavi corte).
- `storico.json` — tutti i prezzi letti oggi, **compresi quelli in quarantena**. Non è un
  file per l'app: è la memoria che serve alla regola R4 (vedi sotto).
- `report-qualita.json` / `report-qualita.md` — misure di controllo ed esito.

Le date (`dato_del` e il campo `t` di ogni prezzo) escono in ISO-8601 **con l'offset**,
p.es. `2026-08-05T08:00:00+02:00`. I CSV ministeriali sono in ora italiana e non lo dicono:
scriverle così com'erano voleva dire che il telefono le rileggeva come ora *sua* — giusta
per caso in Italia d'inverno, sbagliata di un'ora d'estate e di più all'estero.

La **pubblicazione è atomica**: si costruisce in `build/_staging/` e si scambia solo se il
report supera le soglie verificabili (freschezza > 85%, 0 impianti senza età). Altrimenti
resta l'ultima build valida (offline-first: «l'app continua a servire i dati del giorno
prima»). Lo scambio rinomina due directory, quindi un istante senza `build/public/` esiste
per forza; se però il secondo spostamento fallisce, il giorno prima torna al suo posto
invece di restare sotto un altro nome.

## Configurazione

Tutto in [`config.yaml`](config.yaml): sorgenti (sostituibili), soglie di validazione,
parametri del risparmio e target di qualità — valori esatti da pag. 12.

## Storico e regola R4

La regola R4 (salto > 0,08 €/l in 24 h) confronta i prezzi con quelli dell'ultima build:
`sources.carica_storico()` li rilegge da `build/public/storico.json`, e ripiega sui file di
provincia per le build fatte prima che quel file esistesse. In locale funziona da sé dalla
seconda esecuzione in poi; in CI il job **recupera la build precedente** con la cache di
GitHub Actions, altrimenti ripartirebbe da zero ogni notte e la regola non scatterebbe mai.

**Perché serve un file a parte.** La regola dice «quarantena fino alla conferma del giorno
dopo», e la seconda metà ha bisogno di memoria. Finché lo storico si ricostruiva dai file
di provincia, il prezzo messo in quarantena non ci finiva mai — non viene pubblicato — e il
giorno dopo il confronto ripartiva dal valore vecchio: un rialzo di mercato vero restava
invisibile *finché il salto non rientrava da sé*. Ora i prezzi sospesi vivono in
`Impianto.prezzi_in_quarantena` e finiscono in `storico.json`: il secondo giorno il prezzo
non si mostra, il terzo — se confermato — torna al suo posto.

Il report dichiara sempre l'esito: `storico_disponibile` e `storico_impianti` nelle misure
di controllo, più un avviso su stderr. Storico assente alla prima esecuzione è normale;
dopo, significa che il recupero si è rotto.

## Orari di apertura (OpenStreetMap)

MIMIT non pubblica gli orari: `isSelf` distingue self e servito, non le ore. Dopo la
validazione, `orari.py` interroga **Overpass** una volta per l'intera Italia, indicizza i
distributori con `opening_hours` e li abbina per vicinanza. Il valore finisce nel campo
`oh` del record; Aperto/Chiuso viene calcolato nell'app (`domain/orari.dart`).

È **gratuito, best-effort e a copertura parziale**: se Overpass non risponde la build
prosegue senza orari (nessun dato inventato: dove manca, l'app non mostra nulla). In CI
l'istanza pubblica può andare in timeout — vedi `I1` in `revisione/REVISIONE.md`.

## Stato e limiti dichiarati

- **Regola R1 (confine comunale):** richiede i poligoni ISTAT — sorgente **da definire**;
  finché non collegata è riportata come «non verificata» nel report, non simulata.
- **«Sette regole»:** pag. 12 cita sette regole ma ne elenca sei in tabella. La settima è
  **da definire** (`validation.REGOLE → R7`): non inventata.
- **Formato CSV:** vedi [`docs/formato-csv-mimit.md`](docs/formato-csv-mimit.md). Colonne da
  riconfermare a ogni scarico reale.
- **Pubblicazione su CDN:** la build è pronta al deploy; lo step finale su GitHub/Cloudflare
  Pages è **da completare** nel workflow quando si sceglie l'hosting.

## Attribuzioni obbligatorie

Ogni file di provincia e il manifest riportano:
«Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0. © OpenStreetMap contributors.»
