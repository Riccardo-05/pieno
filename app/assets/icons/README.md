# Icone

Asset immagine dell'app, registrati in `pubspec.yaml` sotto `flutter: assets:`.

| File | Uso |
| --- | --- |
| `logo.png` | Marchio. È anche la sorgente dell'**icona applicazione**. |
| `caricamento/` | Asset della schermata di avvio (vedi il README lì). |

## Icona applicazione

Non si disegnano a mano le decine di formati per Android e iOS: si generano da `logo.png`
con `flutter_launcher_icons`, configurato in `pubspec.yaml`.

```bash
cd app
dart run flutter_launcher_icons
```

Sostituisce le icone native in `android/.../mipmap-*` e
`ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Su iOS l'alpha viene rimossa
(`remove_alpha_ios: true`): l'App Store rifiuta le icone con trasparenza.

Rigenerare dopo ogni modifica di `logo.png`, altrimenti le icone native restano quelle
vecchie senza che nulla lo segnali.

## Iconografia dell'interfaccia

I comandi (impostazioni, posizione, ordinamento) usano le icone di sistema Material, non
file da qui. I marcatori-prezzo sulla mappa non sono icone: sono pillole disegnate a
runtime in `lib/ui/map/pillole.dart`, perché «il prezzo è il marcatore» (pag. 6).
