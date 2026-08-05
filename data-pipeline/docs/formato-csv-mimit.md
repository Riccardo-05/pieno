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
- **Prima riga:** intestazione di estrazione, es. `Estrazione del : 05/08/2026 08:00:00` — viene scartata e usata come **data del dato**.

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
| `isSelf` | `Prezzo.self_service` (si preferisce il self, è il prezzo mostrato) |
| `dtComu` | `Prezzo.comunicato_il` (età del dato → regola R5) |

## Note di normalizzazione

- **Carburanti:** `descCarburante` contiene varianti commerciali (es. «Blue Diesel», «Hi-Q Diesel», «Benzina 98»). Vengono ricondotte alle 4 chiavi canoniche; le voci non riconducibili sono ignorate. Vedi `normalizza_carburante`.
- **Marchi (bandiera):** normalizzati a minuscolo/spazi singoli. Gli **alias di bandiera** (stesso marchio scritto in modi diversi) sono **da definire** con l'anagrafica reale.
- **Confini comunali (regola R1):** richiedono i poligoni **ISTAT** — sorgente **da definire** in `config.yaml`. Finché non collegata, R1 è riportata come «non verificata» nel report, non simulata.
