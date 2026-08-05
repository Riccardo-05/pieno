# Pieno — App (Tappa 02: scheletro)

Progetto Flutter. Obiettivo della tappa (linee-guida/08-roadmap.md): *«l'app apre e mostra
dati veri, senza interfaccia definitiva»*.

## Cosa c'è

- **Token di design come costanti** — `lib/design/tokens.dart`, `lib/design/typography.dart`
  (fonte unica: `linee-guida/design-tokens.json`, pag. 4).
- **Componenti di base** — `lib/ui/components/`: Vetro, SwitchPillola, BottonePrimario,
  PulsanteTondo, PrezzoText, SfondoAurore.
- **Archivio locale + download provincia** — `lib/data/`: `local_store.dart` (cache su file,
  offline-first), `repository.dart` (rete → cache).
- **Permessi di posizione con spiegazione** — `lib/data/location_service.dart` (un solo fix,
  precisione bilanciata; il dialogo di sistema va preceduto dalla schermata di spiegazione).
- **Stato condiviso (Riverpod)** — `lib/state/app_state.dart` (carburante, provincia, dati).
- **Schermata scheletro** — `lib/ui/screens/boot_screen.dart`: elenco impianti per prezzo,
  età del dato e sorgente sempre visibili.

## Come eseguire (sulla tua macchina)

L'ambiente di stesura non ha Flutter installato: i comandi seguenti vanno lanciati da te.

```bash
cd app
flutter pub get
flutter test           # test del modello (nessuna rete)
flutter run            # avvia l'app
```

Prima di `flutter run`: aggiungere i font in `assets/fonts/` (vedi `assets/fonts/README.md`)
e generare le cartelle di piattaforma se assenti (`flutter create .`).

## Da configurare

- **`kBaseUrlDati`** in `lib/state/app_state.dart`: URL pubblico della build dati (Tappa 01).
  In sviluppo si può servire `data-pipeline/build/public/` con un server statico locale, es.
  `python3 -m http.server` dentro quella cartella, e puntare `kBaseUrlDati` a quell'indirizzo.

## Rimandato alle tappe successive

- Selezione carburante a 4 vie e impostazioni → Tappa 05.
- Calcolo del più conveniente e del risparmio sul pieno, «Portami qui» → Tappa 03.
- Mappa, marcatori, foglio inferiore → Tappa 04.
- Scelta definitiva archivio locale (Drift/Isar) → Tappa 03.
