# Revisione codebase — Pieno

Registro dei difetti noti: organizzazione, struttura, bug, incoerenze. Le linee guida
dicono come dovrebbe essere; questo file dice **dove il codice non ci arriva ancora**.

- Severità: 🔴 alta · 🟠 media · 🟡 bassa/cosmetica
- Stato: `[ ]` da fare · `[~]` parziale · `[x]` risolto
- Metodo: lettura integrale di `state/app_state.dart` e `ui/screens/mappa_screen.dart`,
  scansioni mirate su `app/lib` e `data-pipeline`, misure sugli screenshot e test mirati.
- Voci marcate **DA VERIFICARE**: vanno confermate a runtime.

Aggiornare gli stati man mano che si correggono: è la fonte di verità della revisione.

---

## A · Struttura & organizzazione

- [x] 🟠 **A1 — `mappa_screen.dart` troppo grande.** Estratti `ui/map/pillole.dart`,
  `ui/map/attribuzione_mappa.dart` e `ui/map/presa_foglio.dart`. Il file resta il più
  lungo dell'app (~800 righe) ma ogni pezzo autonomo è ormai fuori.
- [ ] 🟠 **A4 — Logica di dominio dentro `app_state.dart`.** `ordina` e `filtra` sono
  logica pura ma stanno tra i provider. Spostarle in `domain/ricerca.dart` le renderebbe
  testabili senza Riverpod.
- [ ] 🟡 **A2 — Import disordinati.** Es. `vicino_a_te_screen.dart` righe 21–23: modelli
  in mezzo ai componenti. Convenzione: `dart:` → `package:` → relativi, ciascun gruppo
  ordinato.
- [x] 🟡 **A3 — Commenti d'intestazione obsoleti.** Corretti gli header di `app_state.dart`
  («Tappa 02»), `mappa_screen.dart` (descriveva il foglio «in colonna sotto la mappa»,
  struttura non più esistente) e il commento di `Vista` («l'avvio resta su Vicino a te»).

## B · Bug / correttezza

- [x] 🔴 **B2 — `jsonDecode` senza try/catch all'init dei provider persistiti.** Con le
  preferenze corrotte l'app andava in crash all'avvio. Ora fallback vuoto su
  `segnalazioni`, `valutazioni`, `rientro`.
- [x] 🟠 **B1 — Parametri con tipo implicito `dynamic`.** Tipizzati come `Carburante`.
- [x] 🟠 **B8 — Banda bianca sopra la maniglia del foglio** (vedi anche C1). Con uno
  scorrimento deciso verso il basso, il contenuto del foglio scivolava scoprendo lo sfondo
  del pannello. Diagnosi per misura su due screenshot: il riquadro restava fermo a 622,3 pt
  in entrambi mentre il vuoto passava da 131,7 a 181,0 pt → non era layout, era **overscroll
  in testa** della lista. Corretto con `_fisicaFoglio` (rimbalzo iOS solo in coda).
- [ ] 🟠 **B3 — Scrittura di `foglioExtentProvider` dentro `onNotification`.** Aggiornare
  uno `StateProvider` durante il dispatch della notifica può causare «markNeedsBuild during
  build». **DA VERIFICARE**; se problematico, differire con `addPostFrameCallback`.
- [ ] 🟠 **B5 — `_mostraSelezionato` usa `getVisibleRegion` senza inset.** La regione
  visibile non considera il foglio: un punto "sotto il foglio" è ritenuto visibile, quindi
  la mappa può non ricentrarsi quando dovrebbe. Coordinare con `_centroVisibile`.
- [ ] 🟠 **B9 — Il marcatore "migliore" e la scheda del foglio possono indicare impianti
  diversi.** `_aggiornaSorgente` calcola `idMigliore` su `marcatoriProvider` (tutta la
  provincia, senza raggio), mentre il foglio mostra `elenco.first` da `elencoProvider`
  (filtrato per raggio). Con raggio 10 km la pillola menta può stare su un impianto a 40 km
  mentre la scheda ne mostra un altro.
- [ ] 🟡 **B4 — `_centroVisibile` approssima la densità pixel.** Formula Web Mercator su
  pixel logici senza `devicePixelRatio`: centramento "quasi" corretto.
- [ ] 🟡 **B6 — `filtra` esclude gli impianti con `comunicatoIl == null`** quando
  `etaMaxGiorni` è attivo. Coerente col principio «0 senza età», da verificare sul campo.
- [ ] 🟡 **B7 — Campo `s` (self) sempre `true`.** Con i prezzi solo-self è dato morto
  (vedi K8).

## C · Piattaforma

- [x] 🟠 **C1 — Foglio sovrapposto alla mappa.** Il layout a colonna esisteva perché su web
  il platform-view della mappa cattura i gesti. Ora il foglio è sovrapposto e funziona su
  iOS reale; **su web resta da riverificare** il trascinamento.
- [x] 🟢 **C2 — `updateContentInsets` non su web** → risolto con `_centroVisibile`.
- [ ] 🟡 **C3 — Haptics no-op su web** (atteso, nessuna azione).

## D · Prestazioni

- [x] 🟡 **D1 — Rebuild ad ogni frame durante il drag del foglio.** Ridotto: `home_shell`
  non osserva più `foglioExtentProvider` (lo switch è fermo), restano solo i due `Consumer`
  isolati dei comandi e della dissolvenza. La mappa non si ridisegna.
- [ ] 🟡 **D2 — `elencoProvider`/`marcatoriProvider` non memoizzati.** Rieseguono
  `filtra`+`ordina` a ogni cambio di dipendenza; per province grandi (~1300 impianti) è
  accettabile ma senza caching.

## E · Onestà sul dato

- [ ] 🔴 **E5 — La data del dato non viene letta dal CSV.** Nel manifest pubblicato
  `dato_del` è `2026-08-05T09:12:35.186809`: ha i microsecondi ed è a due minuti da
  `generato_il`, cioè è il fallback `datetime.now()` di `pipeline.py`, non la riga
  «Estrazione del :». Conseguenze: la misura di freschezza confronta l'ora del job con sé
  stessa e **passa sempre**, e la regola R5 (età massima) usa la data sbagliata come
  riferimento. È un guasto silenzioso, la categoria che il progetto si è dato la regola di
  evitare.
- [ ] 🟠 **E1 — «Media di zona» instabile.** Il risparmio (e il colore rame) si calcolano
  sulla media dell'elenco **filtrato** per raggio ed età, non su una media provinciale
  stabile: cambiando il raggio cambia il «risparmi X €» e quali chip diventano rame.
  Andrebbe ancorata a una media provinciale calcolata dalla pipeline.
- [ ] 🟠 **E2 — Distanza in linea d'aria, non stradale.** Diverge dai km di Apple/Google
  Maps. Minimo: etichettare «in linea d'aria».
- [ ] 🟡 **E3 — «al netto della deviazione» non implementato.** Il risparmio è lordo
  (`deviazioneEuro` = 0, «da definire»).
- [ ] 🟡 **E4 — Orari OSM a copertura parziale** (dichiarato). Nessuna azione.

## F · Accessibilità

- [ ] 🟠 **F1 — Nessun `Semantics` per i prezzi.** Il PDF (pag. 13) chiede la lettura
  vocale «2,059 euro al litro»: oggi lo screen reader legge «2,059 €/l» come glifi. Serve
  su `PrezzoText`, sui chip e sulle righe. Voce della checklist di rilascio.
- [ ] 🟡 **F2 — Contrasto AA non verificato.** Grafite su vetro chiaro: da misurare.

## G · Avvio

- [ ] 🟠 **G4 — Attesa fissa di 4 s all'avvio.** `main.dart` mostra la schermata di
  caricamento per 4.000 ms prima ancora di iniziare i permessi, contro l'obiettivo
  dichiarato «< 1 s dal tocco sull'icona al primo prezzo utile»
  (`06-architettura.md`, `09-checklist-rilascio.md`). Decidere: o si accorcia, o si
  aggiorna l'obiettivo dichiarandone la ragione.

## H · Test

- [ ] 🟠 **H1 — Copertura bassa.** 20 test: risparmio, ordinamento, modello, geojson,
  presa del foglio, uno smoke widget. Mancano `filtra`, `domain/orari.dart` (il parser
  `opening_hours` ha molti rami), `manifest.provinciaPiuVicina`, e uno smoke di
  mappa/impostazioni.
- [ ] 🟡 **H2 — `test_validation.py` time-dipendente.** `OGGI` è ancorato a
  `datetime.now()`: resta sensibile all'orologio.

## I · Pipeline (Python)

- [ ] 🟠 **I1 — Overpass in CI può andare in timeout.** `orari.py` interroga tutta Italia
  sull'istanza pubblica: best-effort già gestito (skip su errore), ma la copertura dipende
  dal mirror. Valutare mirror alternativo + un retry.
- [ ] 🟠 **I3 — Il job notturno non pubblica da giorni.** Al 7 agosto 2026 il manifest
  pubblico è fermo alla versione `20260805-091452`. Da verificare nelle Actions: potrebbe
  essere il blocco del report di qualità, un timeout Overpass o il deploy su Pages.
- [ ] 🟡 **I2 — «da definire» dichiarati.** `report.py` (scarto mediano, segnalazioni),
  R1 (confini comunali ISTAT), R7 (settima regola): noti e documentati.

## J · Duplicazione

- [x] 🟠 **J1 — Helper di formattazione prezzo.** `domain/formato.dart` (`formattaPrezzo`),
  usato ovunque al posto dei cinque `toStringAsFixed(3).replaceAll(...)`.
- [x] 🟠 **J2 — Token per il colore del foglio.** `PienoColors.foglio`.
- [x] ~~🟠 **J3 — Widget `ManigliaFoglio`.**~~ Non necessario: la maniglia esiste in un solo
  punto (ora chrome del box in `mappa_screen`).
- [x] 🟠 **J7 — Estrarre il disegno delle pillole** → `ui/map/pillole.dart`.
- [x] 🟡 **J6 — Token vetro 50%** → `PienoColors.vetro50`.
- [ ] 🟠 **J4 — `PannelloInferiore` / `FoglioBase` condiviso.** Il contenitore bianco con
  angoli tondi in alto + ombra è ridefinito in `segnala_sheet.dart`,
  `spiegazione_posizione.dart` e nel foglio della mappa.
- [ ] 🟡 **J5 — `CampoTesto` unico.** `InputDecoration` ridefinita in `accesso_screen.dart`
  e `segnala_sheet.dart`.
- [ ] 🟡 **J8 — `EsitoDati` → record.** Classe con due campi mentre `caricaProvincia`
  ritorna già un record: usare `({DatiProvincia? dati, bool rete})`.

## K · Pulizia

- [x] 🟠 **K4 — Unificare `ordinaPerPrezzo` e `ordina`.** `ordinaPerPrezzo` era un
  doppione tenuto in vita da un solo test: rimosso, il test usa `ordina`.
- [x] 🟡 **K9 — Codice e file morti.** Rimossi `_fondaleFoglio` (mascherava un difetto che
  non esisteva più), due `is String` sempre veri nel callback del tocco, `app/flutter_01.png`
  (0 byte) e i `.DS_Store`. `flutter analyze` è ora **pulito**: zero warning.
- [ ] 🟠 **K5 — Colori hardcoded diffusi.** ~40 occorrenze di `Color(0x…)` in `lib`. I
  ricorrenti (divisori `0x14000000`, overlay selezione, bordi `0x22000000`) vanno nei token.
- [ ] 🟡 **K7 — Stringhe UI sparse.** «Portami qui», «€/l», «sul pieno», messaggi di stato:
  sparse nei widget. Un file di stringhe faciliterebbe coerenza e localizzazione.
- [ ] 🟡 **K8 — Dato morto `selfService`.** Sempre `true` da quando i prezzi sono solo self:
  rimuovere da pipeline (`s`) e app (`Prezzo.selfService`) se non servirà.
- [ ] 🟡 **K6 — `_SceltaChip` con un solo uso** (impostazioni, «escludi età»).
- [ ] 🟡 **K10 — API deprecate in vista di Riverpod 3.** 13 usi di `listenSelf` in
  `app_state.dart` (da portare su `Notifier.listenSelf`) e un `activeColor` in
  `impostazioni_screen.dart` (→ `activeThumbColor`). Oggi solo `info`, ma `listenSelf`
  è dichiarato in rimozione: da affrontare tutto insieme al prossimo aggiornamento
  maggiore, non un pezzo per volta.

## L · Fluidità

- [x] 🔴 **L1 — `ListView` eager nel foglio mappa** → `ListView.builder`, costruzione lazy.
- [x] 🟠 **L2 — Isolare la mappa dai rebuild.** Il contenuto del foglio ha il suo `Consumer`:
  `MapLibreMap` non si ricostruisce più sui cambi di carburante/elenco/selezione.
- [x] 🟠 **L3 — Debounce degli slider Impostazioni** (raggio, capacità) su `onChangeEnd`.
- [x] 🟠 **L4 — Rebuild ogni frame durante il drag del foglio** → vedi D1.
- [x] 🟡 **L11 — Elenco del foglio limitato a 35 righe.** Prima si costruiva l'intera
  provincia (~1300): oltre le prime decine nessuno scorre.
- [ ] 🟠 **L5 — `setGeoJsonSource` dell'intera provincia su cambio carburante/età.**
  Ricostruisce ~1300 feature verso il nativo: valutare `setFilter` o un diff.
- [ ] 🟡 **L6 — `const` mancanti.** Attivare `prefer_const_constructors` (oggi solo `info`:
  ~10 occorrenze fra `impostazioni_screen`, `segnala_sheet`, `vicino_a_te_screen`).
- [ ] 🟡 **L7 — `RepaintBoundary`** attorno al foglio e ai controlli flottanti.
- [ ] 🟡 **L8 — `ref.watch(provider.select(...))`** dove serve un solo campo.
- [ ] 🟡 **L9 — Calcoli nel `build`** (`mediaZona`, selezionato) ad ogni ricostruzione.
- [ ] 🟡 **L10 — Verificare rigenerazione pillole** allo ricarico dello stile.

**Come misurare:** `flutter run --profile` + Performance/Timeline di DevTools per i frame
oltre i 16 ms (8 ms a 120 Hz). In debug, `P` attiva l'overlay prestazioni.

---

## Priorità suggerite

1. **E5** — la data del dato non viene letta: falsa la misura di freschezza e la regola R5.
2. **I3** — capire perché il job notturno non pubblica da due giorni.
3. **B9** — marcatore migliore e scheda che indicano impianti diversi: è una bugia visibile.
4. **E1 / E2** — media di zona stabile ed etichetta «in linea d'aria».
5. **F1** — accessibilità dei prezzi: è anche una voce della checklist di rilascio.
6. **G4** — i 4 s di avvio contro l'obiettivo di 1 s.
7. **A4 / J4** — logica in `domain/`, foglio base condiviso.
8. **B3 / B5** — verifiche runtime sul foglio e sul ricentraggio.

**Quick win a basso rischio:** L6 (`const`), A2 (import), J8 (record), K8 (dato morto).
