# Formato dei CSV MIMIT

Roadmap 01, task 1: «Scaricare i due CSV MIMIT e documentarne colonne, separatore e codifica».

> Questo file descrive il formato **osservato/atteso**. Va **confermato a ogni scarico reale**:
> il parser (`pieno_pipeline/parsing.py`) è tollerante (rileva separatore e codifica), ma le
> colonne vanno riverificate se il Ministero cambia il tracciato.

## Sorgenti

Configurate in `config.yaml → sorgenti`. Open data MIMIT, licenza **IODL 2.0** con attribuzione obbligatoria.

- `anagrafica_impianti_attivi.csv` — anagrafica impianti.
- `prezzo_alle_8.csv` — prezzi praticati, valori in vigore alle 8:00.

## Struttura comune

- **Separatore:** `;` (atteso; confermato a runtime dal Sniffer).
- **Codifica:** `utf-8` attesa; fallback `utf-8-sig` e `latin-1`.
- **Prima riga:** intestazione di estrazione, usata come **data del dato**. Ne esistono almeno due forme, entrambe osservate sul file reale e entrambe accettate da `parsing.data_estrazione`: `Estrazione del : 05/08/2026 08:00:00` e `Estrazione del 2026-08-05` (senza due punti, data ISO, **senza ora**). Se non è interpretabile la pipeline lo dichiara (`data_dato_letta` nel report) invece di ripiegare in silenzio sull'ora del job.

## anagrafica_impianti_attivi.csv

| Colonna | Uso nel modello |
| --- | --- |
| `idImpianto` | `Impianto.id` |
| `Gestore` | `Impianto.gestore` |
| `Bandiera` | `Impianto.marchio` (normalizzato per la deduplica) |
| `Tipo Impianto` | `Impianto.tipo` |
| `Nome Impianto` | `Impianto.nome` |
| `Indirizzo` | `Impianto.indirizzo` |
| `Comune` | `Impianto.comune` |
| `Provincia` | `Impianto.provincia` (sigla; chiave del file per provincia) |
| `Latitudine` | `Impianto.lat` |
| `Longitudine` | `Impianto.lon` |

## prezzo_alle_8.csv

| Colonna | Uso nel modello |
| --- | --- |
| `idImpianto` | collega all'anagrafica |
| `descCarburante` | mappato sulle 4 chiavi canoniche (`benzina`, `gasolio`, `gpl`, `metano`) |
| `prezzo` | `Prezzo.valore` (€/l, tre decimali; virgola o punto accettati) |
| `isSelf` | **filtro**: righe «servito» scartate per benzina e gasolio, tenute per GPL e metano (vedi sotto) |
| `dtComu` | `Prezzo.comunicato_il` (età del dato → regola R5) |

## Note di normalizzazione

- **Self e servito:** `parsing.CARBURANTI_SOLO_SELF` elenca i carburanti per cui il servito si scarta — benzina e gasolio, dove è lo stesso prodotto con un sovrapprezzo. Per **GPL e metano** il servito si tiene: sono venduti quasi solo così (167 impianti GPL su 4.598 hanno un prezzo self, 102 su 1.513 per il metano), e scartarlo cancella il 96% del GPL dall'app. Dove esistono entrambe le modalità vince il self; a parità, la comunicazione più recente. Il campo `s` del record pubblicato dice quale delle due è: `true` sempre per benzina e gasolio, quasi sempre `false` per GPL e metano.
- **Orari di apertura:** non sono nel CSV — `isSelf` distingue self/servito, non le ore. Vengono aggiunti da OpenStreetMap in `orari.py`, dopo la validazione (vedi il README della pipeline).
- **Carburanti:** `descCarburante` contiene varianti commerciali (es. «Blue Diesel», «Hi-Q Diesel», «Benzina 98»). Vengono ricondotte alle 4 chiavi canoniche; le voci non riconducibili sono ignorate. Vedi `normalizza_carburante`.
- **Marchi (bandiera):** normalizzati a minuscolo/spazi singoli. Gli **alias di bandiera** (stesso marchio scritto in modi diversi) sono **da definire** con l'anagrafica reale.
- **Confini comunali (regola R1):** richiedono i poligoni **ISTAT** — sorgente **da definire** in `config.yaml`. Finché non collegata, R1 è riportata come «non verificata» nel report, non simulata.
