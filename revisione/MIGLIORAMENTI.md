# Piano di miglioramento — stabilità, sicurezza, dati

Compagno di [`REVISIONE.md`](REVISIONE.md), che registra **i difetti trovati**. Questo
registra invece **il lavoro deciso**: cosa vogliamo migliorare, perché, e a che punto è.

Chiesto l'8 agosto 2026 su tre assi: *maggiore stabilità*, *maggiore sicurezza*,
*maggiore fluidità e affidabilità sui dati*.

- Stato: `[ ]` da fare · `[~]` in corso · `[x]` fatto
- Ogni voce chiusa porta il test che la sorveglia
- Le voci si spuntano **solo** dopo che i test girano verdi

---

## Gruppo 1 · L'app non verifica ciò che scarica

Il manifest pubblica `sha256` e `bytes` per ogni file di provincia. L'app non li legge:
`Manifest.fromJson` prende solo `versione` e `province`, e `repository.dart` scarica e si
fida. Due conseguenze, una per asse.

**Affidabilità:** un file troncato a metà scaricamento che resti JSON valido viene
accettato, salvato e mostrato. Nessuno se ne accorge.

**Fluidità:** l'app riscarica l'intera provincia — circa 1300 impianti — a ogni avvio,
anche quando il file è identico a quello che ha già sul telefono. Il README della
pipeline promette «l'app riscarica solo ciò che cambia»: non è vero, non è mai stato
implementato.

- [x] **1.1 — Il manifest porta l'impronta fino all'app.** `VoceProvincia.sha256` e
  `Manifest.voceDi(sigla)`. Aggiunta la dipendenza `crypto`.
- [x] **1.2 — Non si riscarica ciò che non è cambiato.** `caricaProvincia(sigla,
  impronta:)`: se la copia locale ha già quell'impronta, la rete non si tocca affatto.
  Test: *«se la copia locale è già quella dichiarata, la rete non si tocca»*.
- [x] **1.3 — Non si crede a ciò che non torna.** Un corpo la cui impronta non
  corrisponde viene scartato **prima** di finire sul disco, e si ripiega sulla copia
  buona. Test con un file troncato che resta JSON valido — il caso che passava.
- [x] **1.4 — L'app sa dire se il dato è corrente.** `EsitoDati.origineRete` è diventato
  `EsitoDati.corrente`: il banner offline compare solo quando si sta davvero servendo
  qualcosa di potenzialmente superato, non ogni volta che non si è passati per la rete.

Chiuso l'8 agosto 2026. 74 test nell'app, verdi. Con questo il README della pipeline
smette di promettere una cosa che non succedeva: adesso l'app riscarica davvero solo ciò
che è cambiato.

## Gruppo 2 · I guasti devono farsi sentire

- [ ] **2.1 — Allarme quando il job notturno fallisce.** Oggi non esiste niente: nessun
  `if: failure()` nel workflow. Il job del 6 agosto è saltato e ce ne siamo accorti per
  caso, guardando altro. Un job che fallisce in silenzio è un job che non c'è.
- [ ] **2.2 — `test_validation.py` non deve più dipendere dall'orologio.** `OGGI =
  datetime.now()` alla riga 15: è **esattamente** il difetto che ha bloccato la
  pubblicazione del 6 agosto (I3 in REVISIONE), ed è ancora lì. Nel registro è H2,
  indicato come priorità 1.
- [ ] **2.3 — Lo storico che scade in silenzio.** La cache di GitHub Actions dura sette
  giorni: se il repo resta fermo, R4 riparte da zero e non scatta. Il report lo dichiara
  (`storico_disponibile`), ma nessuno legge il report — si chiude con 2.1.

## Gruppo 3 · La pipeline deve girare sulla macchina di chi la scrive

- [ ] **3.1 — `UnicodeEncodeError` su Windows.** La pipeline scarica, valida, deduplica
  ventimila impianti e poi muore sull'ultima `print`, perché la console Windows usa
  cp1252 e non sa stampare `→` e `·`. Su Linux, dove gira la CI, non si vede. Effetto
  pratico: dalla macchina di casa il job **non può concludersi**, a nessuna ora.
- [ ] **3.2 — Quando la build è bloccata, dirlo in modo utile.** Oggi stampa
  «Pubblicazione bloccata dal report di qualità». Non dice la cosa che serve sapere: che
  il file è quello di ieri, e che riprovare adesso non cambierà niente.

## Gruppo 4 · Privacy e superficie del servizio percorsi

- [ ] **4.1 — La posizione esatta arriva al motore.** Il servizio arrotonda a ~100 m solo
  per la *chiave di cache*; le coordinate girate a OSRM sono quelle precise. Arrotondare
  anche in ingresso costa poco e rende l'informativa privacy letteralmente vera invece
  che quasi.
- [ ] **4.2 — Nessun tetto sulla risposta del motore.** `MaxBytesReader` protegge la
  richiesta in ingresso; la risposta di OSRM si legge senza limiti. Rischio basso — il
  motore è in casa — ma è un'asimmetria che non ha ragione di esserci.

## Gruppo 5 · Lavori grossi, da affrontare a sé

- [ ] **5.1 — R1, confini comunali ISTAT.** Una delle sei regole non gira:
  `abilitato: false` in `config.yaml`. Oggi una coordinata sbagliata passa purché cada
  dentro l'Italia.
- [ ] **5.2 — `setGeoJsonSource` rigenera 1300 marcatori a ogni cambio carburante.** È L5
  in REVISIONE, ed è la cosa che sulla mappa si sente di più come mancanza di fluidità.
- [ ] **5.3 — Audit sul campo su 100 impianti.** Non è codice. È l'unica cosa che può
  riempire la misura «scarto mediano < 0,01 €/l», oggi *«da definire»* nel report — e il
  registro stesso la indica come più importante di tutto il resto.

---

## Registro di avanzamento

| Quando | Cosa | Esito |
| --- | --- | --- |
| 8 ago 2026 | Gruppo 1 · integrità e scaricamento condizionale | ✅ 4 voci su 4, 74 test verdi |
