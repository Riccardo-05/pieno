# Font

`pubspec.yaml` dichiara **Sora** (numeri e prezzi, cifre tabulari) e **Manrope** (tutto il
resto), come da pag. 4 del documento di progetto. I file sono **inclusi nel repository**:
non serve scaricare nulla prima di `flutter run`.

| File | Uso |
| --- | --- |
| `Sora[wght].ttf` | Prezzi e numeri (pesi 300, 400, 500, 600) |
| `Manrope[wght].ttf` | Testi, titoli, bottoni (pesi 500, 600, 700, 800) |

Sono i **font variabili** ufficiali: un solo file per famiglia copre tutti i pesi lungo
l'asse `wght`, quindi in `pubspec.yaml` non si dichiara `weight` per ciascun taglio. Pesano
insieme circa 270 kB, meno degli otto file statici che sostituiscono.

## Licenza

Entrambi sono distribuiti con **SIL Open Font License 1.1** — gratuita e ridistribuibile,
coerente con la "regola di spesa" del progetto. Il testo integrale è in `OFL-Sora.txt` e
`OFL-Manrope.txt` e **va mantenuto insieme ai font**: è la condizione della licenza.

Origine: repository ufficiale [google/fonts](https://github.com/google/fonts)
(`ofl/sora/`, `ofl/manrope/`).
