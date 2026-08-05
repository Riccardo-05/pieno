# Pieno — App

Progetto Flutter delle quattro schermate: **Accesso, Mappa, Vicino a te, Impostazioni**
(Tappe 02–06 della roadmap). Le regole di forma e comportamento stanno in `linee-guida/`:
se il codice e le linee guida divergono, sbagliato è il codice.

## Struttura (`lib/`)

| Cartella | Contenuto |
| --- | --- |
| `design/` | `tokens.dart`, `typography.dart` — valori esatti da `linee-guida/design-tokens.json`. |
| `models/` | Impianto, carburante, manifest, navigatore, segnalazione. |
| `data/` | `repository.dart` (rete → cache), `local_store.dart` (offline-first), `location_service.dart`, `navigator_launcher.dart`. |
| `domain/` | Risparmio, ordinamento, geo, geojson. |
| `state/` | `app_state.dart` — un solo stato condiviso fra le due viste; impostazioni persistite. |
| `ui/components/` | Vetro, pillole, switch, scheda impianto, marcatori, shortcut, stelle. |
| `ui/screens/` | `home_shell`, `mappa_screen`, `vicino_a_te_screen`, `impostazioni_screen`, `accesso_screen`, `segnala_sheet`, `spiegazione_posizione`. |

## Come eseguire

```bash
cd app
flutter pub get
flutter test              # dominio + componenti, nessuna rete
dart analyze lib          # analisi statica
flutter run -d chrome     # oppure un dispositivo Android/iOS
```

I font Sora e Manrope sono **inclusi** in `assets/fonts/` (vedi il README lì): non serve
scaricare nulla.

> Su Windows `flutter analyze` richiede la Modalità sviluppatore attiva (symlink dei
> plugin). In mancanza, `dart analyze lib` copre lo stesso codice.

## Configurazione

- **`kBaseUrlDati`** in `lib/state/app_state.dart` — URL della build dati pubblica.
  In sviluppo si può servire `data-pipeline/build/public/` con `python -m http.server`
  e puntare la costante lì.
- **Bundle id** — ancora `com.example.pieno`: da cambiare prima della pubblicazione
  (`android/app/build.gradle.kts`, target iOS in Xcode).

## Posizione

Il dialogo di sistema non viene mai aperto a freddo: al primo avvio `home_shell` mostra
`spiegazione_posizione.dart`, che dice a cosa serve la posizione e cosa non viene fatto.
La scelta è persistita e resta modificabile in **Impostazioni → Dati → Posizione**. Senza
permesso l'app funziona lo stesso, senza distanze.

I permessi sono dichiarati in `android/app/src/main/AndroidManifest.xml`
(`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`) e in `ios/Runner/Info.plist`
(`NSLocationWhenInUseUsageDescription`).

## Rimandato

- Sincronizzazione di preferiti e preferenze (richiede il backend account).
- Invio delle segnalazioni: oggi restano in coda locale.
- Foglio della mappa sovrapposto invece che in colonna — da riprendere testando su mobile.
- Scelta definitiva dell'archivio locale (Drift/Isar) al posto della cache su file.
