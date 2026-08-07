# Pieno — Linee guida

App prezzi carburanti · Italia. Design system delle quattro schermate, piano d'azione tecnico e roadmap operativa.

## Cos'è il progetto

Pieno è un'app per i prezzi dei carburanti in Italia. Ogni schermata risponde a una sola domanda: «dove faccio il pieno adesso e quanto risparmio». Un solo elemento dominante (il prezzo), una sola azione primaria (Portami qui), tutto il resto in secondo piano.

I carburanti considerati sono quattro — **Benzina, Gasolio (diesel), GPL, Metano** — la cui forma canonica è definita in `05-dati-e-qualita.md` e riusata in modo uniforme in tutte le linee guida.

Le quattro schermate sono:

1. Accesso
2. Mappa
3. Vicino a te
4. Impostazioni

## Come si usano gli altri file

Questa cartella di linee guida resta accanto al codice e viene letta a ogni sessione di sviluppo. Il documento di progetto («Pieno Design System») è la fonte; da qui vanno prodotte queste linee guida in testo.

| File | Contenuto |
| --- | --- |
| `00-README.md` | Cos'è il progetto e come si usano gli altri file. |
| `01-principi-ux.md` | I principi di pagina 2, in forma di regole verificabili. |
| `02-design-tokens.md` | Colori, caratteri, raggi, ombre, spaziature. |
| `03-schermate.md` | Le quattro schermate: misure e comportamenti. |
| `04-flusso-navigazione.md` | Ordine, punti d'ingresso, stato condiviso tra mappa ed elenco. |
| `05-dati-e-qualita.md` | Fonti, lavorazione, validazione, indicatori. |
| `06-architettura.md` | Stack, file per provincia, job notturno. |
| `07-mappa-e-navigazione.md` | Stile mappa, marcatori, handoff, Ferrostar. |
| `08-roadmap.md` | Le sette tappe con i rispettivi esiti. |
| `09-checklist-rilascio.md` | Controlli obbligatori prima di ogni pubblicazione. |
| `design-tokens.json` | Colori, caratteri, raggi, ombre e spaziature in chiavi leggibili da codice. |

## Come tenerli vivi

- Le linee guida stanno nello stesso repository del codice e si modificano nella stessa richiesta di modifica.
- Se il codice e le linee guida divergono, sbagliato è il codice finché non si decide il contrario esplicitamente.
- Ogni tappa della roadmap si chiude aggiornando il file corrispondente.

### Le decisioni prese

Dove il progetto si discosta dal documento di partenza, la deviazione è **dichiarata nel file corrispondente** insieme alla sua ragione, in corsivo. Non sono dimenticanze e non vanno "corrette" riportandole al PDF senza discuterne. Ad oggi:

| Decisione | Dove | Al posto di |
| --- | --- | --- |
| L'app apre sulla **Mappa**, l'Accesso si raggiunge dalle Impostazioni | `04-flusso-navigazione.md` | Accesso come primo passo |
| Soglia «listino fermo» a **30 giorni** | `05-dati-e-qualita.md` | 2 giorni (dichiarati «regolabili») |
| Prezzi **solo self**, orari da OpenStreetMap | `05-dati-e-qualita.md` | non previsto dal PDF |
| Switch flottante **fermo in fondo** e uguale nelle due viste | `03-schermate.md` | sopra il foglio, in dissolvenza |
| Fino a **cinque** alternative, e sono toccabili | `01-principi-ux.md`, `03-schermate.md` | massimo tre |

Gli scarti che restano **da definire** (non inventati) sono invece elencati dove servono: settima regola di validazione e confini comunali ISTAT in `05-dati-e-qualita.md`, costo della deviazione nel calcolo del risparmio in `01-principi-ux.md`.

## I difetti noti

Non stanno qui: il registro dei difetti della codebase, con stato e priorità, è in [`../revisione/REVISIONE.md`](../revisione/REVISIONE.md). Le linee guida dicono come dovrebbe essere; la revisione dice dove il codice non ci arriva ancora.

## Prima riga da scrivere

La cartella `linee-guida` e il job notturno dei dati. Prima ancora dell'app: senza dati puliti e datati, non c'è niente da mostrare in nessuna schermata.
