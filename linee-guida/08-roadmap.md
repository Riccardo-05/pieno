# Roadmap

Le sette tappe con i rispettivi esiti (pagina 14 del documento di progetto). Ogni tappa si chiude con qualcosa di verificabile. Non si passa alla successiva finché la precedente non produce il suo esito.

## Stato di avanzamento

| Tappa | Stato | Nota |
| --- | --- | --- |
| 01 · Dati | ✅ conclusa | Pipeline in `data-pipeline/`, validatore + report + job notturno. Dati pubblici su GitHub Pages: https://riccardo-05.github.io/pieno/manifest.json |
| 02 · Scheletro dell'app | ✅ conclusa | Progetto Flutter in `app/`, verificato con `flutter run -d chrome` su dati veri. |
| 03 · Vicino a te | ✅ conclusa | Schermata 3 completa: più conveniente, risparmio sul pieno, tre alternative, «Portami qui», stati vuoto/offline. Provata su Chrome. Provincia fissa a MI (vedi Tappa 04). |
| 04 · Mappa | ✅ conclusa | MapLibre + stile personalizzato, marcatori-pillola con collisioni e cluster, foglio inferiore, selezione condivisa, puntino posizione, «cerca in questa zona», provincia dalla posizione. |
| 05 · Impostazioni e account | ✅ conclusa | Schermata 4 (cinque gruppi) e Schermata 1 (accesso/registrazione/«entra senza account»). Impostazioni **funzionanti**: carburante, navigatore, ordinamento (3 vie), raggio, capacità serbatoio, escludi età — tutte persistite localmente. Manca solo la sincronizzazione (serve backend account). |
| 06 · Fiducia | ✅ conclusa (lato app) | Segnalazione prezzo errato (coda locale), ritorno dopo il rifornimento. Lato server/processo (regola tre conferme, notifiche push, audit sul campo) documentato, da eseguire. |
| 07 · Prova e rilascio | 🔨 materiali pronti | Documenti in `rilascio/` (privacy, scheda store, piano test). Nome app «Pieno» e **icona** impostati; l'app gira su iPhone reale. Restano da fare da te: account sviluppatore, prova utenti/campo, cambio bundle id, build e upload (Android → iOS). |
| 08 · Extra e rifiniture | 🔨 in corso | **Fatto:** stelle valutazione interne (le esterne richiedono un'API); schermata di caricamento; prezzi **solo self** e **orari da OpenStreetMap** (`opening_hours`), con Aperto/Chiuso calcolato nell'app; foglio della mappa riscritto come box + lista (vedi `07-mappa-e-navigazione.md`); switch flottante fermo e uguale nelle due viste; alternative toccabili che portano alla Mappa. **Da fare:** accessibilità dei prezzi (`Semantics`), tema scuro. |

## 01 · Dati — 2–3 settimane

- Scaricare i due CSV MIMIT e documentarne colonne, separatore e codifica.
- Scrivere il validatore con le sette regole di pagina 12.
- Generare i file per provincia in formato compatto e versionato.
- Automatizzare tutto in un job notturno su GitHub Actions.
- Pubblicare su CDN gratuita e produrre il report giornaliero di qualità.

**Esito:** un URL pubblico con dati puliti e datati.

## 02 · Scheletro dell'app — 2 settimane

- Progetto Flutter, token di design come costanti, font Sora e Manrope.
- Componenti di base: pillola, switch, pulsante tondo, bottone primario, scheda.
- Archivio locale e scaricamento del file di provincia.
- Permessi di posizione con la spiegazione prima del dialogo.

**Esito:** l'app apre e mostra dati veri, senza interfaccia definitiva.

## 03 · Vicino a te — 2 settimane

- Calcolo del più conveniente e del risparmio sul pieno.
- Schermata 3 completa, incluse le tre alternative.
- «Portami qui» verso il navigatore di sistema.
- Stato senza risultati e stato senza connessione.

**Esito:** la prima versione utile a un vero automobilista.

## 04 · Mappa — 3 settimane

- MapLibre con stile personalizzato ed etichette ridotte.
- Marcatori-prezzo con collisioni e raggruppamento.
- Foglio inferiore trascinabile e selezione condivisa con l'elenco.
- Switch flottante e stato unico tra le due viste.

**Esito:** la schermata di avvio definitiva.

## 05 · Impostazioni e account — 2 settimane

- Schermata 4 con i cinque gruppi e la persistenza locale.
- Schermata 1 con accesso, registrazione ed «entra senza account».
- Sincronizzazione di preferiti e preferenze.
- Attribuzioni di licenza e informativa privacy.

**Esito:** prodotto completo nelle quattro schermate.

## 06 · Fiducia — 2 settimane

- Segnalazione di prezzo errato e regola delle tre conferme.
- Notifica di ritorno dopo il rifornimento.
- Pagina pubblica sulla qualità dei dati.
- Primo audit sul campo su 100 impianti.

**Esito:** la difesa contro la disinstallazione.

## 07 · Prova e rilascio — 2 settimane

- Test con cinque utenti nei tre scenari, due iterazioni.
- Account sviluppatore, materiali per gli store, informativa.
- Rilascio prima su Android, poi su iOS.

## Dopo il rilascio

Confronto lungo il percorso, CarPlay e Android Auto, tema scuro, e solo allora la valutazione della navigazione interna con Ferrostar.

---

## Cosa manca, dichiarato

Tutto ciò che il documento di progetto colloca **«solo quando servirà»** o **«dopo il rilascio»**, più i limiti reali dell'ambiente:

- **Backend:** account e sincronizzazione, aggregazione delle segnalazioni con la **regola delle tre conferme**, notifiche push. Oggi le segnalazioni restano in **coda locale** e il ritorno dopo il rifornimento è un **prompt all'avvio**, non una notifica.
- **Voci «da definire»:** titolare privacy e contatto, **bundle id** (ancora `com.example.pieno`), hosting dell'informativa privacy.
- **Pagina pubblica sulla qualità dei dati** scritta per chi guida, non il log tecnico del job: finché non esiste, dalle Impostazioni non si linka il `report-qualita.md`.
- **Accessibilità:** lettura vocale dei prezzi («2,059 euro al litro»), oggi assente — è anche una voce della checklist di rilascio.
- **Fase 5 e oltre:** navigazione interna con **Ferrostar**, tema scuro, confronto lungo il percorso, CarPlay / Android Auto.

## Direzione consigliata

In ordine di valore, con la regola di spesa del progetto (niente servizi a pagamento prima che esista una funzione usata davvero):

1. **Chiudere la Tappa 07 sul serio:** cambiare bundle id, pubblicare la privacy e fare un **rilascio interno Android**. È il passo che trasforma il progetto in prodotto. Font e icona ci sono già; l'app gira su iPhone reale.
2. **Attendibilità del dato** — è il capitolo che decide tutto. Prima i due guasti aperti in `revisione/REVISIONE.md` (`E5`, la data del dato non letta dal CSV, e `I3`, il job notturno fermo), poi la **Ricerca dell'Osservatorio** come seconda fonte e la **regola R1** con i confini comunali ISTAT. Infine il primo **audit sul campo** su 100 impianti.
3. **Backend minimo, solo quando i numeri lo giustificano:** un endpoint per **ricevere le segnalazioni** (svuotare la coda locale) e applicare la regola delle tre conferme. Da qui, account e sincronizzazione.
4. **Rifiniture UX:** tema scuro (stesso vetro su fondo `#0E1620`), stato «senza connessione» curato, accessibilità dei prezzi.
5. **Fase 5** (navigazione interna con Ferrostar) **solo** quando esiste un server percorsi e un numero di utenti che lo giustifica: prima, uscire verso il navigatore di sistema è la scelta corretta, non un ripiego.
