# Checklist di rilascio

Controlli obbligatori prima di ogni pubblicazione. Voci ricavate dal documento di progetto (pagine 12, 13 e 10).

## Prova sul campo

- [ ] Prova sul campo obbligatoria prima di ogni rilascio: un pieno vero, con l'app in mano.

## Verifica di usabilità

- [ ] Test con cinque utenti per iterazione, tre scenari: fermo a casa, a piedi in città, da passeggero in auto.
- [ ] Metrica guida: percentuale di sessioni in cui si arriva a «Portami qui» con al massimo un tocco.

## Accessibilità

- [ ] Testo dinamico.
- [x] Contrasto AA — misurato su tutte le combinazioni reali della palette. Grafite, menta scura e rame sono stati scuriti del minimo necessario (erano a 3,39 · 4,40 · 3,96 contro il 4,5:1 richiesto): vedi `02-design-tokens.md`.
- [x] Lettura vocale dei prezzi come «2,059 euro al litro» — `Semantics` su prezzo principale, pastiglia risparmio, chip alternativa e righe dell'elenco (`domain/formato.dart → prezzoParlato`). **Restano fuori i marcatori sulla mappa**: sono disegnati da MapLibre come layer nativo, non da widget Flutter, quindi non espongono semantica.

## Qualità del dato (misure di controllo)

- [x] Freschezza del dato verificata a ogni build, con soglia **48 h** invece di 24: il file ministeriale nasce vecchio di un giorno e la sua intestazione non porta l'ora (misure e motivazione in `05-dati-e-qualita.md`). Sotto soglia la build non viene pubblicata.
- [ ] < 0,01 €/l scarto mediano tra prezzo mostrato e reale.
- [ ] < 5‰ segnalazioni ogni 1.000 navigazioni avviate.
- [x] 0 impianti mostrati senza età del dato — verificato dal report a ogni build (`impianti_senza_eta`).

## Prestazioni

- [ ] < 1 s dal tocco sull'icona al primo prezzo utile a schermo.
- [ ] 60 fps durante scorrimento e trascinamento della mappa.
- [ ] > 99,5% sessioni senza crash.
- [ ] p95 < 120 ms risposta dell'API «vicini» (quando esisterà).

## Parole dell'interfaccia

- [x] Il bottone dice cosa succede: «Portami qui», non «Naviga».
- [x] Il risparmio dichiara la base: «Risparmi 3,25 € sul pieno», sulla capacità impostata e contro la **media provinciale** (stabile: non cambia se muovi il raggio).
- [x] Prezzi sempre a tre decimali, virgola decimale, unità «€/l» separata — un solo punto di verità, `domain/formato.dart`.
- [x] Gli errori spiegano cosa fare: «Nessun impianto con … entro il raggio. Allarga il raggio o cambia carburante».

## Attribuzioni obbligatorie

- [x] «Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0» nelle Impostazioni e nella scheda store (`rilascio/store-listing.md`).
- [x] «© OpenStreetMap contributors» visibile sulla mappa (in basso a sinistra, sempre presente).
- [ ] Se si usa un servizio di percorsi, la relativa attribuzione secondo la sua licenza.

## Materiali per gli store

- [ ] Account sviluppatore attivo (Apple 99 $/anno, Google 25 $ una tantum).
- [ ] Materiali per gli store e informativa privacy.
- [ ] Ordine di rilascio: prima su Android, poi su iOS.

## Passi di pubblicazione (Tappa 07)

Documenti pronti in `rilascio/`: `privacy.md`, `store-listing.md`, `test-usabilita.md`.

- [x] **Permessi di posizione** dichiarati (Android `ACCESS_*_LOCATION`, iOS
      `NSLocationWhenInUseUsageDescription`) e spiegazione mostrata prima del dialogo di sistema.
- [x] **Font** Sora e Manrope inclusi in `app/assets/fonts/` con le rispettive licenze OFL.
- [x] **Bundle id** portato a `io.github.riccardo05.pieno` (Android `namespace` + `applicationId`, target iOS, package Kotlin).
- [x] Impostare **nome visibile** «Pieno» (Android `android:label`, iOS `CFBundleDisplayName`).
- [x] **Versione** allineata a `1.0.0+1`.
- [x] Icona app generata da `assets/icons/logo.png` con `flutter_launcher_icons`.
- [ ] **Screenshot** per le schede store (vanno catturati da device).
- [ ] **Pubblicare l'informativa privacy** a un URL raggiungibile e inserirlo nelle schede store.
- [ ] Eseguire la **prova di usabilità** (`rilascio/test-usabilita.md`) e la **prova sul campo**.
- [ ] **Android**: `flutter build appbundle`, caricare su Google Play (traccia interna → produzione).
- [ ] **iOS** (dopo Android): `flutter build ipa`, caricare su App Store Connect via Xcode/Transporter.
