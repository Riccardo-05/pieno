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

## Z · Aperti dopo la messa in servizio dei percorsi (7 agosto 2026)

Trovati usando l'app su iPhone con le distanze reali, non leggendo il codice.

- [ ] 🔴 **Z1 — «Portami qui» finisce sotto lo switch flottante.** Nel foglio della mappa,
  ad altezza di riposo, l'azione primaria della schermata è coperta dalla pillola
  «Mappa | Vicino a te». La lista ha già la riserva `kSpazioSwitchFlottante` in coda, ma
  serve solo a fine scorrimento: a riposo la scheda è più alta della porzione visibile e il
  bottone cade proprio sotto lo switch. Misure sullo screenshot: scheda ~378 pt + maniglia
  ~26, riserva switch ~80, disponibili 440 a 0,52 → ne servirebbero ~484 (0,58). Tre strade:
  alzare l'altezza di riposo, accorciare la scheda, spostare lo switch. È una scelta di
  design, non un aggiustamento.
- [ ] 🟡 **Z2 — I marcatori-prezzo passano sotto i comandi in alto.** Una pillola vicina al
  bordo superiore finisce dietro l'ordinamento o il selettore carburante. Per costruzione:
  i marcatori sono un layer della mappa, i comandi ci galleggiano sopra. Si attenua con un
  margine di sicurezza in `_centroVisibile`, non si elimina.
- [ ] 🟡 **Z3 — La pastiglia del risparmio sparisce su impianti lontani. DA VERIFICARE se
  è il comportamento previsto.** Con la Fase 6 il risparmio è al netto della deviazione e
  la soglia di visibilità resta 0,50 €: su un impianto ~13 km più lontano del più vicino la
  deviazione vale ~1,27 € e se lo mangia. Prova che discrimina: portare «Consumo medio» a
  3,0 l/100 km e vedere se la pastiglia torna. Se torna, funziona come previsto e la voce
  si chiude; se non torna, c'è dell'altro.

Da valutare, non un difetto: oggi la deviazione si paga **rispetto all'impianto più vicino
in assoluto**, anche se è uno dove non andresti mai. Misurarla rispetto a quello che
sceglieresti comunque sarebbe più fedele al vero, ma cambia la sostanza del calcolo.

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
- [x] 🟠 **B9 — Marcatore "migliore" e scheda del foglio discordi.** `idMigliore` ora esce
  dallo stesso `elencoProvider` che alimenta la scheda, con ripiego sull'intera provincia
  se il raggio non lascia nulla. Aggiunto un `listen` su `elencoProvider`, perché al
  cambio di raggio i marcatori non si muovono ma il migliore sì.
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

- [x] 🔴 **E5 — La data del dato non veniva letta dal CSV.** L'intestazione era cercata
  per i due punti (`Estrazione del : ...`), forma che il file ha smesso di avere: quella
  reale è `Estrazione del 2026-08-05`. La pipeline ripiegava su `datetime.now()`, quindi
  la freschezza confrontava l'orologio con sé stesso e l'app scriveva «aggiornato oggi»
  su dati di due giorni prima. Ora entrambe le forme sono accettate, il ripiego è
  dichiarato (`data_dato_letta` + avviso su stderr) e la soglia di età è tarata a 48 h
  sulle misure della fonte. Test in `tests/test_parsing.py`.
- [x] 🟠 **E1 — «Media di zona» instabile.** La media è ora **provinciale** e la calcola
  la pipeline (`build._medie_provinciali` → campo `medie` nel file di provincia), come
  già dichiarava `config.yaml` (`risparmio.confronto: provincia`). L'app la legge da lì
  (`mediaRiferimentoProvider`) e ripiega sulla media dell'elenco solo per i file salvati
  prima che il campo esistesse. Il «risparmi X €» non si muove più col raggio.
- [~] 🟠 **E2 — Distanza in linea d'aria.** Dichiarata nella scheda («a 4,2 km in linea
  d'aria»), ma resta il difetto vero: **falsa la classifica**, perché due impianti alla
  stessa distanza in aria possono essere a 4,5 e 11 km di strada. Si chiude con le distanze
  reali — piano in `linee-guida/10-percorsi-e-backend.md`.
- [~] 🟠 **E3 — «al netto della deviazione» non implementato.** Il risparmio è lordo
  (`deviazioneEuro` = 0), quindi un impianto lontano può risultare conveniente anche quando
  raggiungerlo costa più di ciò che fa risparmiare. Si chiude nella Fase 6 dello stesso
  piano, sui chilometri veri. Alzato a media: non è una rifinitura, è un numero falso.
- [ ] 🟡 **E4 — Orari OSM a copertura parziale** (dichiarato). Nessuna azione.

## F · Accessibilità

- [x] 🟠 **F1 — `Semantics` per i prezzi.** `prezzoParlato()` in `domain/formato.dart`
  produce «2,059 euro al litro»; applicato a `PrezzoText`, `PastigliaRisparmio`,
  `ChipAlternativa` e alle righe del foglio, con `excludeSemantics` per non far leggere
  due volte gli stessi glifi. **Restano fuori i marcatori sulla mappa**: li disegna
  MapLibre come layer nativo, non sono widget Flutter e non espongono semantica.
- [x] 🟡 **F2 — Contrasto AA misurato.** Tutte le combinazioni reali della palette.
  Passavano inchiostro (17,6:1), bianco su inchiostro (18,2:1) e bianco su menta scura
  (4,9:1); **non passavano** grafite (3,39), rame (3,96) e menta scura sulla pastiglia
  (4,40). I tre colori sono stati scuriti del minimo necessario — `#646F78`, `#B15835`,
  `#007D6D` — mantenendo la tinta. Deviazione dal PDF dichiarata in `02-design-tokens.md`.

## G · Avvio

- [x] 🟠 **G4 — Attesa fissa di 4 s all'avvio.** L'attesa era **in fila** col lavoro:
  l'avvio costava 4 s *più* posizione e dati. Ora il minimo di visibilità
  (`_minimoVisibile`, 1,5 s) parte insieme al lavoro e si aspetta solo l'eventuale
  residuo. Da misurare su device se si avvicina all'obiettivo di 1 s.

## M · Da guardare sul telefono

- [ ] 🟡 **M5 — La scheda segue il criterio di ordinamento.** Collegamento verificato nel
  codice; resta da confermare sul device. Atteso: senza selezione, scheda e marcatore in
  menta si aggiornano insieme al cambio di criterio; con un impianto selezionato la scheda
  resta su quello — la scelta esplicita vince — e si sposta solo il marcatore.
- [ ] 🟡 **M7 — Card di accesso nelle Impostazioni.** Riccardo non ne è convinto. Strade:
  toglierla finché la sincronizzazione non esiste, ridurla a una riga come le altre, o
  lasciarla. **Serve una sua decisione.**

## H · Test

- [ ] 🟠 **H1 — Copertura bassa.** 20 test: risparmio, ordinamento, modello, geojson,
  presa del foglio, uno smoke widget. Mancano `filtra`, `domain/orari.dart` (il parser
  `opening_hours` ha molti rami), `manifest.provinciaPiuVicina`, e uno smoke di
  mappa/impostazioni.
- [ ] 🟡 **H2 — `test_validation.py` time-dipendente.** `OGGI` è ancorato a
  `datetime.now()`: resta sensibile all'orologio.

## I · Pipeline (Python)

- [ ] 🟡 **I4 — Il calcolo dei fattori stradali passerà sul mini PC** (Fase 5 del piano
  percorsi), togliendo a GitHub Actions un lavoro che i suoi 14 GB di disco reggerebbero a
  fatica. Fino ad allora la distanza resta in linea d'aria.
- [ ] 🟠 **I1 — Overpass in CI può andare in timeout.** `orari.py` interroga tutta Italia
  sull'istanza pubblica: best-effort già gestito (skip su errore), ma la copertura dipende
  dal mirror. Valutare mirror alternativo + un retry.
- [x] 🟠 **I3 — Il job notturno saltato il 6 agosto 2026.** Falliva al passo «Test del
  validatore», per il test dipendente dall'orologio (H2): il runner gira in UTC e la
  freschezza si misura in ora italiana. Corretto nel frattempo; l'orario del cron è stato
  spostato a **08:00 UTC** perché alle 06:20 il Ministero non ha ancora riscritto il CSV
  (lo fa verso le 06:45) e il job rischiava di lavorare sul file del giorno prima.
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
- [x] 🟡 **K8 — `selfService` non è più dato morto.** Da quando GPL e metano tengono anche
  il prezzo servito, il campo `s` distingue davvero le due modalità: `true` sempre per
  benzina e gasolio, quasi sempre `false` per GPL e metano. L'app però non lo mostra
  ancora — valutare se dirlo nella scheda, visto che per il GPL il prezzo è servito.
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

1. **H2** — test dipendenti dall'orologio: hanno già fatto saltare una pubblicazione.
2. **A4 / J4** — logica di dominio fuori dai provider, foglio base condiviso.
3. **B3 / B5** — verifiche runtime sul foglio e sul ricentraggio.
4. **D2 / L5** — memoizzare elenco e marcatori, evitare di riserializzare l'intera
   provincia a ogni cambio di carburante.
5. **K5 / K7** — colori hardcoded e stringhe UI nei token e in un file di stringhe.

Fuori dal codice, e più importante di tutto quanto sopra: **l'audit sul campo su 100
impianti**, l'unica cosa che può riempire la misura «scarto mediano < 0,01 €/l», oggi
«da definire» nel report.

**Quick win a basso rischio:** L6 (`const`), A2 (import), J8 (record).
