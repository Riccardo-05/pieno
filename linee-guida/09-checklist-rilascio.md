# Checklist di rilascio

Controlli obbligatori prima di ogni pubblicazione. Voci ricavate dal documento di progetto (pagine 12, 13 e 10).

## Prova sul campo

- [ ] Prova sul campo obbligatoria prima di ogni rilascio: un pieno vero, con l'app in mano.

## Verifica di usabilità

- [ ] Test con cinque utenti per iterazione, tre scenari: fermo a casa, a piedi in città, da passeggero in auto.
- [ ] Metrica guida: percentuale di sessioni in cui si arriva a «Portami qui» con al massimo un tocco.

## Accessibilità

- [ ] Testo dinamico.
- [ ] Contrasto AA.
- [ ] Lettura vocale dei prezzi come «2,059 euro al litro».

## Qualità del dato (misure di controllo)

- [ ] > 85% impianti mostrati con dato non più vecchio di 24 ore.
- [ ] < 0,01 €/l scarto mediano tra prezzo mostrato e reale.
- [ ] < 5‰ segnalazioni ogni 1.000 navigazioni avviate.
- [ ] 0 impianti mostrati senza età del dato.

## Prestazioni

- [ ] < 1 s dal tocco sull'icona al primo prezzo utile a schermo.
- [ ] 60 fps durante scorrimento e trascinamento della mappa.
- [ ] > 99,5% sessioni senza crash.
- [ ] p95 < 120 ms risposta dell'API «vicini» (quando esisterà).

## Parole dell'interfaccia

- [ ] Il bottone dice cosa succede: «Portami qui», non «Naviga».
- [ ] Il risparmio dichiara la base: «Risparmi 3,25 € sul pieno».
- [ ] Prezzi sempre a tre decimali, virgola decimale, unità «€/l» separata.
- [ ] Gli errori spiegano cosa fare: «Nessun impianto entro 8 km. Allarga il raggio».

## Attribuzioni obbligatorie

- [ ] «Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0» nella schermata Impostazioni e nella scheda dello store.
- [ ] «© OpenStreetMap contributors» visibile sulla mappa.
- [ ] Se si usa un servizio di percorsi, la relativa attribuzione secondo la sua licenza.

## Materiali per gli store

- [ ] Account sviluppatore attivo (Apple 99 $/anno, Google 25 $ una tantum).
- [ ] Materiali per gli store e informativa privacy.
- [ ] Ordine di rilascio: prima su Android, poi su iOS.

## Passi di pubblicazione (Tappa 07)

Documenti pronti in `rilascio/`: `privacy.md`, `store-listing.md`, `test-usabilita.md`.

- [ ] Cambiare il **package/bundle id** da `com.example.pieno` a un identificativo proprio.
- [ ] Impostare **nome visibile** «Pieno» (Android `android:label`, iOS `CFBundleDisplayName`).
- [ ] Allineare **versione** (`app/pubspec.yaml → version`).
- [ ] Icona app e screenshot (vedi `rilascio/store-listing.md`).
- [ ] **Pubblicare l'informativa privacy** a un URL raggiungibile e inserirlo nelle schede store.
- [ ] Eseguire la **prova di usabilità** (`rilascio/test-usabilita.md`) e la **prova sul campo**.
- [ ] **Android**: `flutter build appbundle`, caricare su Google Play (traccia interna → produzione).
- [ ] **iOS** (dopo Android): `flutter build ipa`, caricare su App Store Connect via Xcode/Transporter.
