# Pieno

App per i **prezzi dei carburanti in Italia**. Ogni schermata risponde a una sola domanda:
*«dove faccio il pieno adesso e quanto risparmio»*. Un solo elemento dominante (il prezzo),
una sola azione primaria (**Portami qui**), tutto il resto in secondo piano.

I carburanti considerati sono quattro: **Benzina, Gasolio (diesel), GPL, Metano**.

Dati aperti del Ministero delle Imprese e del Made in Italy (IODL 2.0); mappa © OpenStreetMap.

- **Dati pubblici (live):** https://riccardo-05.github.io/pieno/manifest.json
- **Fonte del design:** `Pieno Design System.pdf` (documento di progetto v3).

---

## Cos'è, in breve

Tre pezzi indipendenti, un solo prodotto:

| Cartella | Cos'è | Tecnologia |
| --- | --- | --- |
| [`linee-guida/`](linee-guida) | Il **design system** e le regole di progetto (11 file), estratti dal PDF. La fonte di verità: se il codice diverge, sbagliato è il codice. | Markdown + `design-tokens.json` |
| [`data-pipeline/`](data-pipeline) | Il **job dati**: scarica i CSV MIMIT, li valida, pubblica file statici per provincia + report di qualità. | Python (stdlib + PyYAML) |
| [`app/`](app) | L'**app** nelle quattro schermate (Accesso, Mappa, Vicino a te, Impostazioni). | Flutter (Dart) + Riverpod |
| [`rilascio/`](rilascio) | Materiali per la pubblicazione: privacy, scheda store, piano di test. | Markdown |
| [`.github/workflows/`](.github/workflows) | Il job notturno che rigenera i dati e li pubblica su GitHub Pages. | GitHub Actions |

## Come scorrono i dati

```
CSV MIMIT ──> data-pipeline ──> file per provincia (JSON) + manifest ──> GitHub Pages (CDN)
                 │                                                            │
          validazione + report                                         l'app scarica
          (soglie di qualità)                                     la provincia vicina e
                                                                  filtra/ordina sul telefono
```

L'app sceglie la **provincia dal baricentro più vicino** alla posizione (baricentri calcolati
dalla pipeline e messi nel `manifest.json`), scarica quel file, e fa **tutto in locale**:
filtro per raggio/età, ordinamento, calcolo del risparmio. Offline-first: l'ultima zona resta
su disco e viene mostrata datata.

---

## Eseguire la pipeline dati

```bash
cd data-pipeline
pip install -r requirements.txt
python -m unittest discover -s tests          # test del validatore
python -m pieno_pipeline.pipeline --scarica   # scarico reale -> build/public/
```

Output in `data-pipeline/build/public/`: `manifest.json`, `province/<SIGLA>.json`,
`report-qualita.{json,md}`. La pubblicazione è **atomica** e avviene solo se il report supera
le soglie (altrimenti resta l'ultima build valida). Dettagli in
[`data-pipeline/README.md`](data-pipeline/README.md).

## Eseguire l'app

```bash
cd app
flutter pub get
flutter test
flutter run -d chrome     # oppure -d macos / un dispositivo Android/iOS
```

L'app punta ai dati pubblici via `kBaseUrlDati` in `lib/state/app_state.dart`. I font Sora e
Manrope (licenza OFL) sono inclusi in `app/assets/fonts/`. Su Windows `flutter analyze`
richiede la Modalità sviluppatore: in mancanza si usa `dart analyze lib`. Dettagli in
[`app/README.md`](app/README.md).

### Struttura dell'app (`app/lib`)

- `design/` — token e tipografia, derivati esatti da `linee-guida/design-tokens.json`.
- `models/` — impianto, carburante, manifest, navigatore, segnalazione.
- `data/` — repository (rete→cache), archivio locale, posizione, apertura navigatore.
- `domain/` — calcolo risparmio, ordinamento (prezzo/bilanciato/distanza), geo, geojson.
- `state/` — provider Riverpod: un solo stato, due viste; impostazioni **persistite**.
- `ui/components/` — vetro, pillole, switch, scheda impianto, marcatori, shortcut…
- `ui/screens/` — `home_shell`, `mappa_screen`, `vicino_a_te_screen`, `impostazioni_screen`,
  `accesso_screen`, `segnala_sheet`.

---

## Stato per tappe (roadmap)

| Tappa | Stato |
| --- | --- |
| 01 · Dati | ✅ pipeline completa, dati pubblici online |
| 02 · Scheletro app | ✅ progetto Flutter su dati veri |
| 03 · Vicino a te | ✅ risparmio, alternative, «Portami qui», stati vuoto/offline |
| 04 · Mappa | ✅ MapLibre, marcatori-pillola con collisioni e cluster, foglio, selezione, posizione |
| 05 · Impostazioni e account | ✅ cinque gruppi + Accesso; impostazioni funzionanti e persistite |
| 06 · Fiducia | ✅ (lato app) segnalazione prezzo + ritorno dopo il rifornimento |
| 07 · Prova e rilascio | 🔨 materiali pronti; account, test e upload restano manuali |

Dettaglio vivo in [`linee-guida/08-roadmap.md`](linee-guida/08-roadmap.md).

## Cosa manca (dichiarato)

Tutto ciò che il PDF colloca **"solo quando servirà"** o **"dopo il rilascio"**, più i limiti reali dell'ambiente:

- **Backend**: account e sincronizzazione, aggregazione delle segnalazioni con la **regola
  delle tre conferme**, notifiche push. Oggi le segnalazioni restano in **coda locale** e il
  ritorno è un **prompt all'avvio**, non una notifica.
- **Verifica su device reale** iOS/Android (finora provata su Chrome/web).
- **Voci "da definire"**: titolare privacy e contatto, **bundle id** (`com.example.pieno`),
  icona app, hosting dell'informativa privacy.
- **Rifinitura mappa**: il foglio inferiore è "a colonna" (robusto su web) invece che
  sovrapposto come nel PDF — l'effetto sovrapposto va ripreso testando su mobile.
- **Pagina pubblica sulla qualità dei dati** scritta per chi guida, non il log tecnico del
  job: finché non esiste, dalle Impostazioni non si linka il `report-qualita.md`.
- **Fase 5 e oltre**: navigazione interna con **Ferrostar**, tema scuro, confronto lungo il
  percorso, CarPlay / Android Auto.

## Direzione consigliata

In ordine di valore, con la regola di spesa del progetto (niente servizi a pagamento prima che
esista una funzione usata davvero):

1. **Chiudere la Tappa 07 sul serio**: provare su un **device reale**, cambiare bundle id,
   aggiungere i font, generare l'icona, pubblicare la privacy, e fare un **rilascio interno
   Android**. È il passo che trasforma il progetto in prodotto.
2. **Attendibilità del dato** (è il capitolo che decide tutto): collegare la **Ricerca
   dell'Osservatorio** come seconda fonte nella pipeline e completare la **regola R1**
   (confini comunali ISTAT), oggi "non verificata". Poi il primo **audit sul campo** su 100
   impianti.
3. **Backend minimo, solo quando i numeri lo giustificano**: un endpoint per **ricevere le
   segnalazioni** (svuotare la coda locale) e applicare la regola delle tre conferme. Da qui,
   account e sincronizzazione.
4. **Rifiniture UX**: foglio mappa sovrapposto su mobile, tema scuro (stesso vetro su fondo
   `#0E1620`), stato "senza connessione" curato, primo avvio con la posizione spiegata.
5. **Fase 5** (navigazione interna con Ferrostar) **solo** quando esiste un server percorsi e
   un numero di utenti che lo giustifica: prima, uscire verso il navigatore di sistema è la
   scelta corretta, non un ripiego.

---

## Attribuzioni obbligatorie

- «Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0» (in Impostazioni e in scheda store).
- «© OpenStreetMap contributors» (sulla mappa).

## Licenza

Da definire.
