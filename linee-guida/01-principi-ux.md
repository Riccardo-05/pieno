# Principi UX

I principi che tengono insieme le schermate, in forma di regole verificabili (pagina 2 del documento di progetto).

## Una domanda, una risposta

Ogni schermata risponde a «dove faccio il pieno adesso e quanto risparmio». Un solo elemento dominante (il prezzo), una sola azione primaria (Portami qui), tutto il resto in secondo piano.

## Leggibile a due distanze

Prezzo e bottone si leggono a braccio teso in meno di un secondo: servono in auto o mentre si cammina. Nome, via e alternative restano per chi ha tempo di guardarle.

## Il risparmio è in euro

«2,059 €/l» non dice nulla mentre si guida. «Risparmi 3,25 € sul pieno» sì. Base dichiarata: 50 litri, confronto con la media della zona, al netto della deviazione.

## Superfici morbide, contenuto netto

Pannelli in vetro semitrasparente su un fondo con due aurore tenui. Raggi ampi, ombre diffuse, nessuna linea dura: la morbidezza è nelle superfici, mai nei numeri.

## Bersagli grandi

Nessun elemento toccabile sotto i 50 px di altezza. L'azione primaria è alta 66–74 px e occupa tutta la larghezza utile.

## Onestà sul dato

La data del dato è sempre visibile. Gli impianti con listini fermi da giorni vengono esclusi, non mostrati come attendibili.

## Le quattro regole da non violare

1. Una sola azione primaria per schermata. Se ne servono due, la seconda è testo, non bottone.
2. Il rame compare solo per i prezzi sopra la media di zona. Il blu solo per la posizione dell'utente.
3. Massimo **cinque** alternative sotto la scheda principale. Il resto sta nella mappa. *(Il documento di progetto ne indicava tre: alzate a cinque perché restano leggibili a colpo d'occhio senza diventare un elenco, e perché ogni alternativa è ora toccabile e porta alla Mappa su quell'impianto — il «resto sta nella mappa» vale ancora, con una porta in più per arrivarci. Il numero è `_maxAlternative` in `ui/screens/vicino_a_te_screen.dart`.)*
4. L'account non è mai obbligatorio: l'app funziona al primo avvio, senza registrazione.

## Regola di crescita

Ogni nuova schermata deve poter essere descritta in una frase che comincia con un verbo dell'utente. Se non ci riesce, non è una schermata: è un'impostazione.
