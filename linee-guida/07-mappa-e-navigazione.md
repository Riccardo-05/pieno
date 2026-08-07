# Mappa e navigazione

Stile mappa, marcatori, handoff, Ferrostar (pagine 6, 9 e 13 del documento di progetto).

## Stile mappa

- Terra `#E7EDEE`, isolati `#DFE7E8`, verde `#D6E7DF`, acqua `#D3E4EA`.
- Strade bianche piene: 17/15/13 px le principali, 6 px le minori.
- Nessuna etichetta stradale: i soli testi sono i prezzi.
- In codice: stile personalizzato con i colori di pagina 6, etichette disattivate.

## Marcatori prezzo

- Pillola bianca 94%, Sora 400 15 px, coda a rombo 9 px.
- Il più conveniente è più grande (17 px, peso 600), in gradiente menta, con alone radiale Ø 96 px che lo isola.
- Il prezzo è il marcatore. Nessuna icona di pompa: il numero è l'informazione, disegnato in un layer con gestione delle collisioni, non come widget, oltre i 50 elementi.
- **Il selezionato è in inchiostro.** L'impianto aperto nel foglio si distingue con una pillola in inchiostro pieno, la più grande di tutte, con alone e sottile anello bianco. L'inchiostro è già il colore della «voce selezionata» (pag. 4) ed è l'unico scuro sulla mappa chiara: non introduce tinte nuove e si trova a colpo d'occhio. Quando un impianto è insieme il più conveniente e il selezionato, vince la selezione: si disegna una sola pillola.
- Il marcatore selezionato **non cede mai il posto alle collisioni** e sta sopra tutti gli altri: è quello di cui l'utente sta leggendo la scheda.
- **Toccando un marcatore** la mappa porta l'impianto in vista solo se è fuori schermo: non deve scappare sotto il dito di chi l'ha appena toccato. Il foglio si apre all'altezza di riposo se era più in basso.
- **Selezionando dall'elenco** (o da un'alternativa in «Vicino a te») vale il contrario: l'utente non stava guardando la mappa, quindi il marcatore va portato al **centro della fascia di mappa che resterà scoperta**, e il foglio riportato all'altezza di riposo — se resta alto copre il punto che si è appena chiesto di vedere.
- **Zoom di partenza** appena sopra la soglia dei raggruppamenti: all'apertura si leggono i prezzi dei singoli impianti, e i cluster ricompaiono allargando di poco.
- Raggruppamento sotto lo zoom 12 mostrando il minimo della zona, non il conteggio: «da 2,059» dice qualcosa, «14 impianti» no.

## Il foglio dei prezzi

Il foglio è un pannello **sovrapposto** alla mappa, fatto di due pezzi che vanno tenuti distinti — è la loro confusione a generare i difetti visibili (contenuto che scivola scoprendo lo sfondo, prese che funzionano a intermittenza).

- **Box.** Il pannello: tre altezze, 0,30 · 0,46 (riposo) · 0,92 di schermo. La **maniglia è chrome del box**, non un elemento della lista: non scorre via col contenuto.
- **Lista.** Il contenuto scorrevole dentro il box, ritagliato da esso: scheda dell'impianto selezionato, occhiello **«ALTRE STAZIONI»**, poi le righe — che escludono l'impianto già mostrato nella scheda, altrimenti «altre» sarebbe falso. **Massimo 35 righe**: oltre, nessuno scorre e il foglio diventa un muro di numeri — il resto della provincia si guarda sulla mappa, che è la sua rappresentazione. L'occhiello dichiara sempre quante righe mostra («I PRIMI 35 IMPIANTI»), mai «tutti» su un elenco tagliato.

Regole di gesto, entrambe scritte perché la coppia box + lista non ha un comportamento ovvio:

- **Rimbalzo solo in coda.** In testa il rimbalzo è bloccato: lì il gesto serve ad abbassare il box, e lasciandolo libero il contenuto scivola in basso scoprendo lo sfondo del pannello sopra la maniglia.
- **La scheda è una presa.** Trascinando la scheda dell'impianto si alza il box anche a lista già scorsa; per abbassarlo, invece, la lista dev'essere in cima (altrimenti prima si torna in cima scorrendo, come ci si aspetta da un elenco). La maniglia da sola è un bersaglio troppo piccolo per essere l'unico appiglio.

## Comportamento della mappa

- «Cerca in questa zona» quando la mappa viene spostata: nessun ricaricamento automatico che sposta i risultati sotto il dito.
- Selezione condivisa con l'elenco: toccare un marcatore apre il foglio; tornare all'elenco mantiene lo stesso impianto in cima.
- Permessi graduali: si spiega perché serve la posizione prima del dialogo di sistema; senza permesso si chiede una città e l'app funziona lo stesso.

## Navigazione — oggi fuori (Fase 1)

Le indicazioni si aprono nel navigatore del telefono. «Portami qui» passa le coordinate dell'impianto all'app scelta dall'utente: su iPhone Apple Maps, su Android Google Maps, con Waze come alternativa su entrambi. La scelta vive in Impostazioni → Mappa e navigazione → Apri con e il valore iniziale è il navigatore predefinito del dispositivo.

- Costo zero e nessuna infrastruttura: nessun server di routing, nessuna quota da rispettare.
- Nessun rischio di qualità: traffico, autovelox, ricalcolo e voce sono quelli che l'utente già conosce.
- Nessun consumo di batteria a carico dell'app.
- Implementazione: apertura di un URL universale con le coordinate, più un ripiego sul navigatore di sistema se l'app scelta non è installata.

### Il difetto, dichiarato

L'utente esce dall'app. È il motivo per cui il ritorno va progettato: alla fine del tragitto una notifica chiede se il pieno è stato fatto e se il prezzo corrispondeva. L'utente rientra, e la risposta alimenta la qualità del dato.

## Navigazione — domani dentro (Fase 5)

Mappa e indicazioni interamente dentro l'app. Non si costruisce un navigatore da zero: si adotta un motore già pronto e open source, vestito con questo design system.

| Pezzo | Scelta |
| --- | --- |
| Motore turn-by-turn | Ferrostar — SDK open source con licenza BSD per iOS, Android e web, interfaccia costruita su MapLibre |
| Calcolo del percorso | Valhalla (auto-ospitato) oppure un servizio compatibile OSRM |
| Mappa | La stessa MapLibre già usata nella schermata 2: lo stile non cambia |
| Voce | Sintesi vocale di sistema, nessun servizio esterno |

### Condizioni per passare alla Fase 5

- Un server per il calcolo dei percorsi: è la prima spesa reale del progetto.
- Integrazione nativa: l'SDK è pensato per iOS e Android nativi, quindi va valutato il costo di adattamento al resto dell'app.
- Un numero di utenti che giustifichi entrambe le cose.

Prima di allora, uscire verso il navigatore di sistema è la scelta corretta, non un ripiego.

### Nel frattempo, dentro l'app

- Anteprima del percorso sulla mappa (linea, distanza, tempo) prima di consegnare al navigatore.
- CarPlay e Android Auto con l'elenco dei prezzi: l'utente resta nell'app fino al momento di partire.
- Avviso sul percorso: la notifica arriva prima, quando la decisione è ancora aperta.
