# Schermata di caricamento

Asset della schermata mostrata all'avvio, mentre l'app prepara posizione e dati
(`lib/ui/screens/caricamento_screen.dart`).

| File | Uso |
| --- | --- |
| `caricamento.png` | Immagine dell'avvio, referenziata dalla costante `_immagine`. |

La cartella è registrata in `pubspec.yaml` (`assets/icons/caricamento/`), quindi i file
aggiunti qui sono già inclusi nel bundle: basta referenziarli.

```dart
Image.asset('assets/icons/caricamento/caricamento.png')
```

Non è la splash screen nativa (quella che appare prima che Flutter parta, definita nei
progetti Android e iOS): è la **prima schermata dell'app**, e resta visibile finché
posizione e dati della provincia non sono pronti. Vedi `G4` in
[`revisione/REVISIONE.md`](../../../../revisione/REVISIONE.md) per la durata dell'attesa,
oggi più lunga dell'obiettivo dichiarato.
