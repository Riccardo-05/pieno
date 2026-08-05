# Dati e qualità

Fonti, lavorazione, validazione, indicatori (pagina 12 del documento di progetto). L'attendibilità del dato è il capitolo che decide tutto: un utente disinstalla l'app la prima volta che arriva alla pompa e trova un prezzo diverso. Non basta prendere il dato aperto e mostrarlo: serve una catena di controlli e un modo per dichiarare quando il dato è vecchio.

## Carburanti considerati

Il progetto considera **quattro carburanti** (il PDF ne dichiara il numero — «ventitremila impianti con quattro carburanti» — ma non i nomi). I nomi, definiti dal committente, sono la forma canonica usata in tutte le linee guida e nel codice:

| Nome (canonico) | Chiave codice | Sinonimi |
| --- | --- | --- |
| Benzina | `benzina` | — |
| Gasolio (diesel) | `gasolio` | diesel |
| GPL | `gpl` | — |
| Metano | `metano` | — |

Ogni impianto espone i prezzi per questi quattro carburanti; il filtro carburante (Mappa e Vicino a te) e la voce «Carburante» in Impostazioni selezionano tra questi quattro valori.

## Le tre fonti, in ordine di fiducia

1. **Open data MIMIT (base).** Anagrafica impianti e prezzi praticati, pubblicati ogni giorno con i valori in vigore alle 8:00. Copertura nazionale, obbligo di legge per i gestori.
2. **Ricerca dell'Osservatorio (aggiornamento).** Interrogazione per punto o zona, più fresca del CSV. Solo per le zone realmente richieste, con cache e limite di chiamate.
3. **Segnalazioni degli utenti (correzione).** Non per inserire prezzi, ma per contestarli: è il segnale che il dato ufficiale è fermo.

## La catena di lavorazione

```
scarico → analisi → validazione → normalizzazione marchi →
controllo geografico → deduplica → storico → pubblicazione atomica
```

La pubblicazione avviene su una nuova versione dei file e viene scambiata solo se il report di qualità supera le soglie: se un giorno il file ministeriale è rotto, l'app continua a servire i dati del giorno prima, dichiarandone l'età.

## Cosa non fare mai

- Scrivere «in tempo reale»: il dato non lo è, e la promessa non mantenuta è la causa numero uno delle disinstallazioni.
- Mostrare un impianto senza sapere quando ha comunicato l'ultima volta.
- Usare la media regionale come termine di paragone: dentro la stessa provincia i prezzi variano più della media.

## Regole di validazione

| Controllo | Azione |
| --- | --- |
| Coordinate fuori dal confine comunale dichiarato | Scarto e segnalazione nel report |
| Latitudine e longitudine invertite | Correzione tentata, poi quarantena |
| Prezzo oltre ±30% dalla mediana nazionale | Quarantena, non mostrato |
| Salto superiore a 0,08 €/l in 24 ore | Quarantena fino alla conferma del giorno dopo |
| Nessuna comunicazione da oltre 2 giorni | Escluso dai risultati (soglia regolabile) |
| Due impianti a meno di 25 m con stesso marchio | Deduplica |

## Il ciclo di correzione

- Dalla scheda impianto: «Segnala un prezzo errato» con il prezzo visto e, se l'utente vuole, la foto del totem.
- Tre segnalazioni concordi entro 24 ore: il prezzo passa a «contestato», l'impianto scende in classifica e perde il badge di convenienza.
- Verifica sul campo mensile a campione (100 impianti) per misurare l'errore, non stimarlo.

## Misure di controllo

| Soglia | Indicatore |
| --- | --- |
| > 85% | impianti mostrati con dato non più vecchio di 24 ore |
| < 0,01 €/l | scarto mediano tra prezzo mostrato e reale |
| < 5‰ | segnalazioni ogni 1.000 navigazioni avviate |
| 0 | impianti mostrati senza età del dato |
