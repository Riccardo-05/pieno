# Roadmap

Le sette tappe con i rispettivi esiti (pagina 14 del documento di progetto). Ogni tappa si chiude con qualcosa di verificabile. Non si passa alla successiva finché la precedente non produce il suo esito.

## Stato di avanzamento

| Tappa | Stato | Nota |
| --- | --- | --- |
| 01 · Dati | ✅ conclusa | Pipeline in `data-pipeline/`, validatore + report + job notturno. Dati pubblici su GitHub Pages: https://riccardo-05.github.io/pieno/manifest.json |
| 02 · Scheletro dell'app | ✅ conclusa | Progetto Flutter in `app/`, verificato con `flutter run -d chrome` su dati veri. |
| 03 · Vicino a te | ✅ conclusa | Schermata 3 completa: più conveniente, risparmio sul pieno, alternative toccabili che portano alla Mappa, «Portami qui», stati vuoto/offline. La provincia si sceglie dalla posizione (Tappa 04). |
| 04 · Mappa | ✅ conclusa | MapLibre + stile personalizzato, marcatori-pillola con collisioni e cluster, foglio sovrapposto (box + lista), selezione condivisa, puntino posizione, «cerca in questa zona», provincia dalla posizione. |
| 05 · Impostazioni e account | ✅ conclusa | Schermata 4 (cinque gruppi) e Schermata 1 (accesso/registrazione/«entra senza account»). Impostazioni **funzionanti**: carburante, navigatore, ordinamento (3 vie), raggio, capacità serbatoio, escludi età — tutte persistite localmente. Manca solo la sincronizzazione (serve backend account). |
| 06 · Fiducia | ✅ conclusa (lato app) | Segnalazione prezzo errato (coda locale), ritorno dopo il rifornimento. Lato server/processo (regola tre conferme, notifiche push, audit sul campo) documentato, da eseguire. |
| 07 · Prova e rilascio | 🔨 materiali pronti | Documenti in `rilascio/` (privacy, scheda store, piano test). Nome «Pieno», **icona**, **bundle id** (`io.github.riccardo05.pieno`) e **versione** (`1.0.0+1`) a posto; l'app gira su iPhone reale. Restano da fare da te: account sviluppatore, screenshot, privacy pubblicata a un URL, prova utenti e prova sul campo, build e upload (Android → iOS). |
| 08 · Extra e rifiniture | 🔨 in corso | **Fatto:** stelle valutazione interne (le esterne richiedono un'API); schermata di caricamento; prezzi **solo self** e **orari da OpenStreetMap** (`opening_hours`), con Aperto/Chiuso calcolato nell'app; foglio della mappa riscritto come box + lista (vedi `07-mappa-e-navigazione.md`); switch flottante fermo e uguale nelle due viste; alternative toccabili che portano alla Mappa; accessibilità (lettura vocale dei prezzi e contrasto AA misurato, con tre colori scuriti); media del risparmio ancorata alla provincia; distanza dichiarata «in linea d'aria»; avvio non più in fila con l'attesa della schermata di caricamento. **Da fare:** tema scuro, testo dinamico. |

## Le sette tappe e i loro esiti

Il piano originale, tenuto per memoria di cosa doveva produrre ogni tappa. Le stime in
settimane sono state tolte: erano previsioni, e oggi confondono chi legge lo stato.

| Tappa | Esito che doveva produrre | Prodotto? |
| --- | --- | --- |
| 01 · Dati | Un URL pubblico con dati puliti e datati | ✅ |
| 02 · Scheletro | L'app apre e mostra dati veri | ✅ |
| 03 · Vicino a te | La prima versione utile a un vero automobilista | ✅ |
| 04 · Mappa | La schermata di avvio definitiva | ✅ |
| 05 · Impostazioni e account | Prodotto completo nelle quattro schermate | ✅ tranne la sincronizzazione (serve il backend) |
| 06 · Fiducia | La difesa contro la disinstallazione | ✅ lato app; regola delle tre conferme e audit sul campo restano |
| 07 · Prova e rilascio | Pubblicazione sugli store | 🔨 in corso |

## In corso, fuori dalle sette tappe

**Percorsi reali** — servizio OSRM auto-ospitato sul mini PC di casa, per distanze su
strada e risparmio al netto della deviazione. Piano completo in
[`10-percorsi-e-backend.md`](10-percorsi-e-backend.md). È anche il server su cui
arriveranno, dopo, segnalazioni e account.

## Dopo il rilascio

Confronto lungo il percorso, CarPlay e Android Auto, tema scuro, e solo allora la valutazione della navigazione interna con Ferrostar.

---

## Cosa manca, dichiarato

Tutto ciò che il documento di progetto colloca **«solo quando servirà»** o **«dopo il rilascio»**, più i limiti reali dell'ambiente:

- **Backend:** account e sincronizzazione, aggregazione delle segnalazioni con la **regola delle tre conferme**, notifiche push. Oggi le segnalazioni restano in **coda locale** e il ritorno dopo il rifornimento è un **prompt all'avvio**, non una notifica.
- **Voci «da definire»:** titolare privacy e contatto, hosting dell'informativa privacy.
- **Pagina pubblica sulla qualità dei dati** scritta per chi guida, non il log tecnico del job: finché non esiste, dalle Impostazioni non si linka il `report-qualita.md`.
- **Accessibilità:** restano il **testo dinamico**, mai provato con i corpi ingranditi, e i **marcatori sulla mappa**, disegnati da MapLibre come layer nativo e quindi muti allo screen reader.
- **Fase 5 e oltre:** navigazione interna con **Ferrostar**, tema scuro, confronto lungo il percorso, CarPlay / Android Auto.

## Direzione consigliata

In ordine di valore, con la regola di spesa del progetto (niente servizi a pagamento prima che esista una funzione usata davvero):

1. **Chiudere la Tappa 07 sul serio:** account sviluppatore, screenshot, privacy pubblicata a un URL, prova utenti e sul campo, poi **rilascio interno Android**. È il passo che trasforma il progetto in prodotto. Font, icona, bundle id e versione sono già a posto; l'app gira su iPhone reale.
2. **Attendibilità del dato** — è il capitolo che decide tutto. Il primo **audit sul campo** su 100 impianti, che è l'unica cosa capace di riempire la misura «scarto mediano < 0,01 €/l»; poi la **Ricerca dell'Osservatorio** come seconda fonte e la **regola R1** con i confini comunali ISTAT.
3. **Backend minimo, solo quando i numeri lo giustificano:** un endpoint per **ricevere le segnalazioni** (svuotare la coda locale) e applicare la regola delle tre conferme. Da qui, account e sincronizzazione.
4. **Rifiniture UX:** tema scuro (stesso vetro su fondo `#0E1620`), stato «senza connessione» curato, testo dinamico.
5. **Fase 5** (navigazione interna con Ferrostar) **solo** quando esiste un server percorsi e un numero di utenti che lo giustifica: prima, uscire verso il navigatore di sistema è la scelta corretta, non un ripiego.
