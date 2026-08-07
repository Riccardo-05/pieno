# Schermate

Le quattro schermate: misure e comportamenti (pagine 5–8 del documento di progetto).

## Schermata 1 — Accesso e registrazione

1. **Marchio e promessa.** Logo 34 px con il gradiente dell'azione primaria, nome in Manrope 800, 26 px. Sotto, una riga che dice cosa fa l'app e da dove vengono i dati: è la prima prova di affidabilità che l'utente riceve.
2. **Switch Accedi / Registrati.** Identico per forma e comportamento allo switch «Mappa / Vicino a te»: pillola in vetro, padding 5 px, selettore in inchiostro. Non è una nuova schermata: cambia il contenuto della scheda sotto con una transizione di 200 ms.
3. **Scheda campi.** Vetro 72%, raggio 32 px. Etichetta sopra il campo invece del solo segnaposto: resta leggibile anche a campo compilato. Campi alti 56 px, raggio 20 px.
4. **Stato di registrazione.** Con «Registrati» la scheda mostra tre campi (email, password, conferma) più il consenso privacy come riga con interruttore. Il bottone diventa «Crea account».
5. **Accessi esterni.** Apple e Google alla pari, alti 54 px. Apple è obbligatorio su iOS se si offre un accesso social di terze parti.
6. **Entra senza account.** La via d'uscita, sempre presente. Registrarsi non serve per vedere i prezzi: serve a sincronizzare preferiti e impostazioni. È la scelta che protegge il tasso di attivazione.

## Schermata 2 — Mappa

1. **Ricerca e filtro.** Barra in vetro e filtro carburante in inchiostro pieno: è l'unico elemento scuro sulla mappa, così si trova sempre. Alti 48 px, distanziati 9 px, a 52 px dal bordo alto. Il filtro carburante seleziona tra i quattro carburanti del progetto — **Benzina, Gasolio (diesel), GPL, Metano** (forma canonica in `05-dati-e-qualita.md`).
2. **Stile mappa.** Terra `#E7EDEE`, isolati `#DFE7E8`, verde `#D6E7DF`, acqua `#D3E4EA`, strade bianche piene (17/15/13 px le principali, 6 px le minori). Nessuna etichetta stradale: i soli testi sono i prezzi.
3. **Marcatori prezzo.** Pillola bianca 94%, Sora 400 15 px, coda a rombo 9 px. Il più conveniente è più grande (17 px, peso 600), in gradiente menta, con alone radiale Ø 96 px che lo isola.
4. **Comandi a destra.** Due pulsanti tondi in vetro da 52 px: impostazioni sopra, posizione sotto. Non si sovrappongono mai ai marcatori: i prezzi hanno la precedenza nello spazio.
5. **Foglio inferiore.** Vetro con sfocatura 26 px, raggio 36 px in alto, maniglia 44×5 px. A riposo mostra l'impianto selezionato; trascinato in alto diventa l'elenco completo. Stesso bottone della schermata 3, alto 70 px.
6. **Gerarchia verticale.** Dall'alto: ricerca, mappa, comandi tondi, foglio. I comandi tondi e l'attribuzione restano sopra il foglio e ne seguono l'altezza; se il foglio sale, scompaiono in dissolvenza.
7. **Switch flottante.** *Decisione presa, diversa dal documento di progetto* (che lo voleva sopra il foglio, in dissolvenza quando il foglio sale). Lo switch sta **fermo in fondo allo schermo, alla stessa altezza della schermata 3**, e galleggia sopra il foglio. Ragione: lo switch non è navigazione ma un cambio di vista sullo stesso stato (pag. 3), quindi non deve spostarsi né sparire a seconda di quanto è alto il foglio — chi lo cerca lo trova sempre nello stesso punto in tutte e due le viste. Perché non risulti appiccicato sopra il contenuto, il foglio gli riserva spazio in coda alla lista e ne dissolve l'ultimo tratto nel colore del pannello.

## Schermata 3 — Vicino a te

1. **Riga di contesto.** Luogo e data del dato a sinistra. A destra la pillola del carburante e il pulsante impostazioni: due comandi, mai di più. Margini 22 px.
2. **Scheda principale.** Vetro bianco 72%, raggio 36 px, margine laterale 18 px. Contiene sempre e solo: nome, via, distanza, prezzo, risparmio, azione. La distanza è dichiarata **«in linea d'aria»**: è calcolata sulle coordinate e diverge dai km che il navigatore mostrerà un istante dopo. Il valore stradale arriverà solo con un servizio di percorsi (Fase 5).
3. **Prezzo.** Sora 300, 78 px, cifre tabulari. Interi in peso 300, decimali in 500: il numero resta leggero ma i millesimi si distinguono.
4. **Pastiglia risparmio.** Menta al 10%, testo menta scura. Dichiara sempre la base: «sul pieno» (capacità impostata, 50 litri di default). Il confronto è con la **media provinciale** calcolata dalla pipeline, non con la media dell'elenco a schermo: così il risparmio non cambia quando l'utente muove il raggio di ricerca. Sotto 0,50 € sparisce invece di mostrare cifre irrilevanti.
5. **Azione primaria.** Altezza 74 px, raggio 26 px, gradiente menta. Apre il navigatore scelto nelle impostazioni con le coordinate dell'impianto.
6. **Alternative.** Fino a cinque chip in vetro 50%, raggio 24 px (il documento di progetto ne indicava tre: vedi `01-principi-ux.md`). Prezzo a destra in Sora 400; rame solo se sopra la media di zona. Il chip è **toccabile**: seleziona l'impianto e porta alla Mappa, che lo mostra già scelto e centrato (selezione condivisa, pag. 3). Il chip selezionato si distingue come la riga attiva nel foglio della mappa: vetro pieno velato d'inchiostro e nome in grassetto.
7. **Switch flottante.** Due sole destinazioni, selettore in inchiostro, staccato 30 px dal bordo inferiore. Stesso componente della schermata di accesso.

## Schermata 4 — Impostazioni

1. **Struttura a gruppi.** Macro-sezioni con etichetta in grafite (11 px, +0,14 em, maiuscolo) e gruppi in vetro con raggio 22 px. Righe alte 50 px, divisori rientrati di 16 px: la lista si legge come un blocco, non come tante linee.
2. **Testata account.** Prima riga più alta (78 px) con avatar 46 px nel gradiente menta. Senza account, al suo posto compare «Accedi per sincronizzare», che porta alla schermata 1.
3. **Rifornimento.** Carburante, modalità e capacità del serbatoio: i tre valori che rendono possibile il messaggio «risparmi X € sul pieno».
4. **Ricerca.** Raggio, ordinamento e «Escludi dati più vecchi di»: è il controllo che dà all'utente potere sull'attendibilità.
5. **Mappa e navigazione.** «Apri con» sceglie il navigatore esterno: Apple Maps, Google Maps o Waze, con il predefinito di sistema come prima opzione. *L'interruttore «avvisi sul percorso» previsto qui **non c'è**: quell'avviso richiede il percorso (Fase 5) e le notifiche (backend), e un interruttore che si accende senza fare nulla promette una funzione inesistente. Torna quando la funzione esiste.*
6. **Dati.** Fonte dei dati, ora dell'ultimo aggiornamento, permessi di posizione. *«Segnala un prezzo errato» **non sta qui**: è un'azione su un impianto preciso e vive nella sua scheda, dove si sa di quale impianto si parla; nelle impostazioni obbligava a indovinarlo. Anche «cancella i dati salvati» è stata tolta. Nella versione completa seguiranno esporta o elimina account.*
