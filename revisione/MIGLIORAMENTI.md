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

- [x] **2.1 — Allarme quando il job notturno fallisce.** Job `avvisa` con `if:
  failure()`: apre una issue etichettata `job-notturno`, o commenta quella già aperta —
  altrimenti dopo una settimana di guasto ci sarebbero sette issue identiche e nessuno
  le leggerebbe più. L'avviso è una issue e non una mail perché non c'è niente da
  configurare, resta accanto al lavoro e si chiude quando il problema è risolto.
- [x] **2.2 — `test_validation.py` non dipende più dall'orologio.** La causa vera stava
  nel codice, non nel test: `report.genera` misurava la freschezza solo sull'orologio di
  sistema, quindi i test *dovevano* ancorarsi a `datetime.now()` per non far risultare
  scaduto il file di prova. Ora l'istante si inietta (`adesso=`), e le date dei test sono
  ferme. **Controprova:** i 45 test passano identici con `TZ` locale, `UTC` e
  `Pacific/Auckland` — prima era proprio il fuso del runner a farli cadere.
- [x] **2.3 — Lo storico che scade in silenzio.** Nuova `pipeline.avvisa()`: in CI gli
  avvisi diventano annotazioni GitHub (`::warning::`), che compaiono in cima al run
  invece di perdersi nel log. Applicata ai quattro punti dove la pipeline segnalava
  qualcosa e proseguiva: storico assente, data non leggibile, orari OSM giù, fattori
  stradali mancanti.

Chiuso l'8 agosto 2026. 45 test nella pipeline, verdi in tre fusi orari.

## Gruppo 3 · La pipeline deve girare sulla macchina di chi la scrive

- [x] **3.1 — `UnicodeEncodeError` su Windows.** `configura_uscita()` in `main()`: si
  tiene la codifica della console e si sostituiscono i caratteri che non ci stanno.
  Forzare UTF-8 su un terminale cp1252 non lo migliora, lo riempie di scarabocchi; un
  riepilogo con un `?` al posto di una freccia resta leggibile, un riepilogo che non
  arriva mai no. **Provato sul campo:** la pipeline gira ora fino in fondo e pubblica,
  uscita `0`, senza `PYTHONIOENCODING`.
- [x] **3.2 — Quando la build è bloccata, dirlo in modo utile.** `spiega_blocco()` dice
  l'età del dato, il limite, che **non è un guasto**, e — la cosa che serviva davvero —
  che riprovare adesso darà lo stesso esito perché il file nuovo arriva domattina.
  Provato sul campo con un dato di tre giorni: *«il dato ha 98.2 h, oltre il limite di
  48 h»*.

Chiuso l'8 agosto 2026. 49 test nella pipeline, verdi.

## Gruppo 4 · Privacy e superficie del servizio percorsi

- [x] **4.1 — La posizione esatta non arriva più al motore.** Origine e destinazioni si
  arrotondano alla cella di ~100 m **prima** di interrogare OSRM, su entrambe le rotte.
  Non si perde nulla di utile — entro cento metri la strada da prendere è la stessa — e
  in cambio due richieste dallo stesso isolato ricevono la stessa risposta anche alla
  prima chiamata, non solo quando la cache ha già colpito.
- [x] **4.2 — Tetto sulla risposta del motore.** `io.LimitReader` a 8 MB: largo per
  qualunque risposta sensata (una tabella verso cento destinazioni sta in poche decine
  di KB), stretto abbastanza da fermare una risposta impazzita. Il primo tentativo di
  test non discriminava — un JSON troncato dà errore comunque — quindi il test manda un
  JSON **valido** con dentro 40 MB di zavorra: prima veniva letto e decodificato tutto
  senza un lamento. Sono anche i primi test del package `osrm`.

Chiuso l'8 agosto 2026.

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
| 8 ago 2026 | Gruppo 2 · i guasti si fanno sentire | ✅ 3 voci su 3, 45 test verdi in tre fusi |
| 8 ago 2026 | Gruppo 3 · la pipeline gira su Windows | ✅ 2 voci su 2, provate sul campo |
| 8 ago 2026 | Gruppo 4 · privacy e superficie del servizio | ✅ 2 voci su 2 |
| — | Gruppo 5 · lavori grossi | ⬜ da affrontare a sé, uno per volta |
