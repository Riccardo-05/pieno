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

**La regola del salto ha bisogno del giorno prima.** Il controllo «salto > 0,08 €/l in 24
ore» confronta i prezzi di oggi con quelli dell'ultima build pubblicata: se il job riparte
da zero, non ha con cosa confrontare e la regola non scatta mai — in silenzio. Perciò il
job notturno **recupera la build precedente** (cache di GitHub Actions,
`.github/workflows/data-nightly.yml`) e il report dichiara sempre se lo storico c'era
(`storico_disponibile`, `storico_impianti`). Assente alla primissima esecuzione è normale;
assente dopo, è un guasto da riparare.

**Taratura operativa della soglia «listino fermo».** Il PDF indica 2 giorni ma la dichiara esplicitamente «soglia regolabile». Sui dati reali MIMIT una soglia di 2 giorni escluderebbe ~88% degli impianti, perché in Italia la maggior parte dei distributori non ritocca il prezzo ogni 48 ore (un prezzo invariato resta comunque valido). La soglia è quindi impostata a **30 giorni** (`data-pipeline/config.yaml → eta_massima_giorni`): esclude solo i listini davvero abbandonati, mantenendo la copertura nazionale. L'età del singolo prezzo resta sempre visibile all'utente (onestà sul dato).

## Il ciclo di correzione

- Dalla scheda impianto: «Segnala un prezzo errato» con il prezzo visto e, se l'utente vuole, la foto del totem.
- Tre segnalazioni concordi entro 24 ore: il prezzo passa a «contestato», l'impianto scende in classifica e perde il badge di convenienza.
- Verifica sul campo mensile a campione (100 impianti) per misurare l'errore, non stimarlo. **Processo (Tappa 06):** estrarre 100 impianti a campione, rilevare il prezzo reale al distributore, confrontarlo con quello mostrato dall'app, registrare lo scarto e alimentare la misura «scarto mediano < 0,01 €/l». Da eseguire prima di ogni rilascio.

**Stato nell'app (Tappa 06).** La segnalazione «prezzo errato» è raccolta dalla scheda impianto e messa in **coda locale** (nessun backend ancora: l'invio e la regola delle tre conferme sono lato server). Il **ritorno dopo il rifornimento** è chiesto all'avvio successivo. La **pagina pubblica di qualità** è il report del job notturno (`report-qualita.md`), linkato dalle Impostazioni.

## Misure di controllo

| Soglia | Indicatore |
| --- | --- |
| > 85% | impianti mostrati con dato non più vecchio di 24 ore (vedi nota) |
| < 0,01 €/l | scarto mediano tra prezzo mostrato e reale |
| < 5‰ | segnalazioni ogni 1.000 navigazioni avviate |
| 0 | impianti mostrati senza età del dato |

**Nota su «dato non più vecchio di 24 ore».** Il dato servito è il file ministeriale: la sua «età» è l'età del file, non la data dell'ultimo ritocco del singolo prezzo. La misura di freschezza (`data-pipeline/pieno_pipeline/report.py`) verifica quindi l'età del file pubblicato; la quota di listini ritoccati di recente resta nel report come **diagnostica non vincolante**.

*Soglia effettiva: 48 ore (`config.yaml → qualita.eta_massima_file_ore`), non 24.* Due motivi misurati sulla fonte, non stimati: il Ministero riscrive il CSV ogni mattina verso le 06:45 UTC ma con il **contenuto del giorno prima**, quindi alla partenza del job il file è già vecchio di oltre 24 ore; e la sua intestazione (`Estrazione del AAAA-MM-GG`) **non porta l'ora**, quindi la data vale mezzanotte e l'età apparente cresce fino a 24 ore ulteriori. Caso peggiore osservato: ~35 ore. A 24 ore la pubblicazione si bloccherebbe ogni giorno; a 48 tollera il ritardo strutturale e scatta ancora se il Ministero salta davvero una pubblicazione. Per lo stesso motivo il job notturno parte alle **08:00 UTC** e non prima.

**La data del dato va letta, non supposta.** Se l'intestazione non è interpretabile, la pipeline ripiega sull'ora del job — ma allora la freschezza confronta l'orologio con sé stesso e passa sempre. Il ripiego è quindi dichiarato: avviso su stderr e campo `data_dato_letta` nel report. *(Errore realmente commesso: l'intestazione era cercata per i due punti, forma che il file ha smesso di avere; per giorni l'app ha scritto «aggiornato oggi» su dati di due giorni prima.)* Lo scarto mediano prezzo/reale (< 0,01 €/l) e le segnalazioni (< 5‰) sono misurabili solo con audit sul campo e in produzione: nel report restano «da definire».

## Prezzi solo self e orari di apertura

**Self dove il self esiste.** Per **benzina e gasolio** si mostrano solo i prezzi self: il servito è lo stesso prodotto con un sovrapprezzo, e mescolarli falserebbe la classifica. Costa poco, perché il self esiste nel 95,6% degli impianti.

Per **GPL e metano no**, e la differenza non è un dettaglio: in Italia quei carburanti si erogano quasi sempre con l'addetto, quindi `isSelf=0` non segnala un sovrapprezzo — è l'unico modo in cui il prodotto viene venduto. Sul dato reale il self copre 167 impianti GPL su 4.598 e 102 su 1.513 per il metano. *(Errore realmente commesso: applicando il filtro a tutti e quattro i carburanti, il 96% degli impianti GPL e il 93% di quelli a metano sono spariti dall'app — a Roma erano rimasti 6 impianti GPL su 242. La regola sta in `parsing.CARBURANTI_SOLO_SELF`, con i test in `tests/test_parsing.py`.)*

Dove per lo stesso impianto esistono entrambe le modalità, vince il self; a parità, la comunicazione più recente.

**Orari di apertura (OpenStreetMap).** MIMIT non contiene orari (il flag `isSelf` è solo self/servito, senza ore). L'orario di apertura — che di norma coincide con l'orario in cui il servito è disponibile — viene arricchito da **OpenStreetMap** (`opening_hours`) tramite Overpass e abbinato per vicinanza in `data-pipeline/pieno_pipeline/orari.py`. È **gratuito, best-effort e a copertura parziale**: dove OSM non ha l'orario, l'app non mostra nulla (mai un dato inventato). L'app calcola Aperto/Chiuso lato client (`app/lib/domain/orari.dart`).
