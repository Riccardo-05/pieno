# Flusso di navigazione

Ordine, punti d'ingresso, stato condiviso tra mappa ed elenco (pagina 3 del documento di progetto).

## Il percorso

Quattro schermate, un solo percorso. L'accesso si attraversa una volta sola; da lì in poi l'app vive tra Mappa e Vicino a te, che sono due viste dello stesso dato e si scambiano con lo switch flottante. Le impostazioni sono raggiungibili da entrambe e tornano sempre da dove si è entrati.

1. **Accesso** — o «entra senza account». Da qui si preme «Entra».
2. **Mappa** — schermata di avvio.
3. **Vicino a te** — elenco per prezzo. Si passa da/verso la Mappa con lo switch.
4. **Impostazioni** — torna da dove si è entrati.

Da Vicino a te e dalla scheda impianto, «Portami qui» apre il navigatore del telefono (Apple Maps · Google Maps · Waze).

## Dove si entra davvero (decisione presa)

Il documento di progetto elenca l'Accesso come primo passo, ma l'app **apre direttamente
sulla Mappa**: l'Accesso si raggiunge da Impostazioni → «Accedi per sincronizzare». È una
scelta deliberata, non una dimenticanza, e discende da una regola che sta più in alto:
*l'account non è mai obbligatorio, l'app funziona al primo avvio, senza registrazione*.
Mettere una schermata di login davanti a chi vuole solo vedere un prezzo costa attivazioni
senza dare nulla in cambio, finché la sincronizzazione non esiste.

Al primo avvio l'unica cosa che precede la Mappa è la **spiegazione della posizione**: un
foglio che dice a cosa serve e cosa non viene fatto, prima del dialogo di sistema. Si può
rispondere «Non ora» e proseguire; la scelta si cambia in Impostazioni → Dati → Posizione.

## Regole del flusso

- La mappa è la schermata di avvio dopo il primo accesso: è quella che orienta. Chi preferisce l'elenco lo imposta e la scelta viene ricordata.
- Lo switch non è navigazione: Mappa e Vicino a te condividono stato, carburante e posizione. Passare dall'una all'altra non ricarica nulla.
- Impostazioni è una schermata sovrapposta, non una scheda: si apre dall'icona in alto (Vicino a te) o dal pulsante tondo a destra (Mappa) e si chiude tornando esattamente dove si era.
- L'accesso non si rivede più se non richiesto: chi entra senza account trova la riga «Accedi per sincronizzare» dentro le impostazioni.

## Punti d'ingresso alle impostazioni

| Schermata | Comando |
| --- | --- |
| Vicino a te | Pulsante tondo in vetro 40 px, a destra della pillola del carburante |
| Mappa | Pulsante tondo in vetro 52 px, sopra il pulsante di posizione |
| Accesso | Nessuno: non ci sono impostazioni prima di entrare |

## Coerenza tra le due viste

Se cambio carburante nella mappa, l'elenco è già aggiornato quando ci passo. Se seleziono un impianto nell'elenco e passo alla mappa, quell'impianto è già selezionato e centrato. Un solo stato, due rappresentazioni.
