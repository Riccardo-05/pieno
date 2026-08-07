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
| `domain/` | `risparmio.dart`, `geo.dart`, `geojson.dart`, `formato.dart` (formato unico dei prezzi), `orari.dart` (parser `opening_hours` di OSM). |
| `state/` | `app_state.dart` — un solo stato condiviso fra le due viste; `filtra`/`ordina`; impostazioni persistite. |
| `ui/components/` | Vetro, pillole, switch, scheda impianto, chip alternativa, shortcut, stelle. |
| `ui/map/` | Pezzi della sola Mappa: `pillole.dart` (disegno dei marcatori-prezzo), `attribuzione_mappa.dart`, `presa_foglio.dart` (regola del trascinamento sul foglio). |
| `ui/screens/` | `home_shell`, `caricamento_screen`, `mappa_screen`, `vicino_a_te_screen`, `impostazioni_screen`, `accesso_screen`, `segnala_sheet`, `spiegazione_posizione`. |

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
- **Bundle id** — `io.github.riccardo05.pieno` (Android `namespace` e `applicationId`,
  target iOS, package Kotlin). Versione `1.0.0+1`.

## Posizione

Il dialogo di sistema non viene mai aperto a freddo: al primo avvio `home_shell` mostra
`spiegazione_posizione.dart`, che dice a cosa serve la posizione e cosa non viene fatto.
La scelta è persistita e resta modificabile in **Impostazioni → Dati → Posizione**. Senza
permesso l'app funziona lo stesso, senza distanze.

I permessi sono dichiarati in `android/app/src/main/AndroidManifest.xml`
(`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`) e in `ios/Runner/Info.plist`
(`NSLocationWhenInUseUsageDescription`).

## Il foglio della Mappa

È la parte più delicata dell'app e la fonte dei suoi difetti storici, quindi vale la pena
sapere com'è fatta prima di toccarla. Sono **due pezzi distinti**:

- il **box** — il pannello sovrapposto alla mappa, alto 0,30 / 0,46 / 0,92 di schermo;
- la **lista** — il contenuto scorrevole dentro il box: scheda dell'impianto selezionato,
  occhiello, fino a 35 righe.

La maniglia è chrome del **box**, non un elemento della lista: non scorre via col contenuto.
Sulla giuntura fra i due pezzi vivono due regole scritte apposta:

- `_fisicaFoglio` (in `mappa_screen.dart`) — rimbalzo iOS **solo in coda**. In testa è
  bloccato: lì il gesto serve ad abbassare il box, e col rimbalzo il contenuto scivolava
  scoprendo lo sfondo del pannello (banda bianca sopra la maniglia).
- `ui/map/presa_foglio.dart` — afferrando la **scheda** si alza il box anche con la lista
  già scorsa, mentre per abbassarlo la lista dev'essere in cima. Regola pura e testata
  (`test/presa_foglio_test.dart`).

## Rimandato

- Sincronizzazione di preferiti e preferenze (richiede il backend account).
- Invio delle segnalazioni: oggi restano in coda locale.
- Scelta definitiva dell'archivio locale (Drift/Isar) al posto della cache su file.
- Testo dinamico: mai verificato con i corpi di sistema ingranditi.
- Semantica dei **marcatori sulla mappa**: li disegna MapLibre come layer nativo, quindi
  non sono raggiungibili dallo screen reader. I prezzi nei widget sì (`prezzoParlato`).
