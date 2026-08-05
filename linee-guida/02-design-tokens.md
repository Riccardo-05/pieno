# Design tokens

Colore, tipografia, forma (pagina 4 del documento di progetto). I valori numerici sono riportati esatti. La versione leggibile da codice è in `design-tokens.json`.

## Palette

| Nome | Valore | Uso |
| --- | --- | --- |
| Inchiostro | `#0E1620` | testo principale, filtro attivo, voce selezionata |
| Grafite | `#77848F` | testo secondario, valori nelle impostazioni |
| Menta (gradiente) | `#00C2A6 → #00887E`, 135° | azione primaria, marcatore migliore, interruttori attivi |
| Menta scura | `#00806F` | testo del risparmio e azioni testuali |
| Menta velo | `rgba(0,179,154,.10)` | sfondo pastiglia risparmio |
| Rame | `#C0603A` | solo prezzi sopra la media di zona |
| Blu posizione | `#2F6BFF` | solo il puntino "sono qui" |
| Fondo | `#EDF2F3` · `#E7EDEE` mappa | fondo delle schermate |
| Vetro | bianco 72% · bordo bianco 85% | schede, pillole, gruppi, foglio |

## Aurore di fondo

Due cerchi sfocati dietro tutto il contenuto, mai visibili come forme:

- Menta: `rgba(0,179,154,.30)`, Ø 420 px, in alto a destra.
- Lavanda: `rgba(122,150,255,.24)`, Ø 380 px, in basso a sinistra.
- Blur: 70 px.

## Caratteri

Sora per numeri e prezzi — peso leggero, cifre tabulari. Manrope per tutto il resto.

| Ruolo | Specifica |
| --- | --- |
| Prezzo principale | Sora 300 · 78 px · −0,05 em · tabular |
| Decimali del prezzo | Sora 500 (stesso corpo) |
| Prezzo nel foglio mappa | Sora 300 · 52 px |
| Prezzo in lista | Sora 400 · 21 px · −0,03 em |
| Marcatore mappa | Sora 400 · 15 px · migliore 600 · 17 px |
| Titolo di pagina | Manrope 800 · 27 px · −0,03 em |
| Nome impianto | Manrope 700 · 21 px · −0,015 em |
| Voce di impostazione | Manrope 600 · 15,5 px |
| Valore / dettaglio | Manrope 500 · 15 px · grafite |
| Bottone primario | Manrope 700 · 18–19 px |
| Occhiello / sezione | Manrope 700 · 11–12,5 px · +0,14 em · maiuscolo |

## Forma e profondità

| Elemento | Raggio / ombra |
| --- | --- |
| Scheda principale | 36 px · `0 20 50 rgba(14,32,38,.10)` + inset bianco |
| Scheda campi (accesso) | 32 px · stessa ombra |
| Gruppo impostazioni | 22 px · `0 10 26 rgba(14,32,38,.07)` |
| Bottone primario | 22–26 px · `0 14 30 rgba(0,150,130,.32)` |
| Pulsanti tondi | 40 px (elenco) · 52 px (mappa) |
| Pillole e switch | 999 px · `0 8 22 rgba(14,32,38,.10)` |
| Sfocatura vetro | 14 px (campi) — 26 px (schede) |
