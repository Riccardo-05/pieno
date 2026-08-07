# To-do — Pieno

Lista di lavoro temporanea. **Si cancella quando è tutta chiusa.**

Legenda: `[ ]` da fare · `[~]` in corso · `[x]` fatto · `[?]` serve una tua decisione

---

## Generali

- [x] **G1 · Dissolvenza della schermata di caricamento.** Ora entra come una superficie sola (420 ms): prima il logo sfumava per conto suo e marchio, sottotitolo e barra comparivano di colpo. L'uscita resta la dissolvenza incrociata verso l'app.

- [x] **G2 · Verifica del dato self/servito.** Contati sulla fonte: **928** impianti
  hanno solo il servito per la benzina, **927** per il gasolio, e **924 sparivano del
  tutto** non avendo nessun prezzo self. Troppi per essere una perdita accettabile: chi ne
  ha uno sotto casa vedeva il nulla. Ora il servito resta dove è l'unico prezzo di quel
  carburante ed è **dichiarato** nella scheda («Servito»), così il confronto resta leggibile.

- [x] **G3 · Copertura metano verificata** sul pubblicato (`20260806-085435`): **1.532
  impianti in 99 province su 107**. Le otto scoperte — GO, IS, KR, NU, OR, SS, SU, TS —
  sono reali e non un residuo del filtro: quattro sono sarde, e in Sardegna la rete del
  metano non esiste. GPL 4.363 impianti in tutte le province.

## Mappa

- [x] **M1 · Selezione dall'elenco.** Ora la selezione ha due comportamenti a seconda di dove nasce: dal **marcatore** la mappa si muove solo se il punto è fuori schermo; dall'**elenco** o da «Vicino a te» il punto va al centro della fascia scoperta e il foglio torna all'altezza di riposo. Il centro si calcola sull'altezza a cui il foglio sta andando, non su quella che ha in quell'istante.

- [x] **M2 · Altezza di riposo del foglio** da 0,46 a **0,52**: la scheda misura ~330 pt fino alla pastiglia del risparmio, che ora si vede senza alzare niente, col bottone che si intravede e invita a salire.

- [x] **M3 · Zoom di partenza a 12,6**, appena sopra `clusterMaxZoom: 12`: si leggono i singoli prezzi e i cluster ricompaiono allargando di poco.

- [x] **M4 · Occhiello «ALTRE STAZIONI»**, e l'elenco ora **esclude** l'impianto della scheda: «altre» dice il vero. È caduto anche lo stato «riga attiva», che non ha più senso.

- [~] **M5 · La scheda segue il criterio di ordinamento** — collegamento verificato nel
  codice, resta da guardare sul telefono con i dati nuovi. Comportamento atteso: senza
  selezione, scheda e marcatore in menta si aggiornano insieme al cambio di criterio; con
  un impianto selezionato la scheda resta su quello (la scelta esplicita vince) e si
  sposta solo il marcatore.

- [x] **M6 · L'elenco torna sulla scheda quando cambia la selezione.** Chi stava scorrendo
  «ALTRE STAZIONI» restava a metà lista senza vedere la scheda cambiata.

## Vicino a te

- [x] **V1 · Tolta la nota in fondo** al foglio di segnalazione.

## Impostazioni

- [x] **I1 · «Escludi dati più vecchi di»: rimosso del tutto.** La soglia resta quella
  della pipeline (R5, 30 giorni): i listini abbandonati non arrivano proprio all'app.
  Tolti la riga, il provider, il filtro per età in `filtra` e il componente `_SceltaChip`
  rimasto senza usi. L'informazione tecnica non si mostra; l'età del dato resta visibile.

- [x] **I2 · «Avvisi sul percorso»: capito e tolto.** Doveva segnalare una stazione più conveniente **lungo il percorso** mentre la decisione è ancora aperta (`07-mappa-e-navigazione.md`). Richiede il percorso (Fase 5) e le notifiche (backend): non esistono, e l'interruttore veniva salvato senza che nessuno lo leggesse. Tolto con il suo provider; torna quando la funzione esiste.

- [x] **I3 · Tolto «Cancella i dati salvati»**, con il dialogo di conferma ormai orfano.

- [x] **I4 · Tolto «Segnala un prezzo errato» dalle impostazioni.** Resta dove sa di quale impianto si parla: la scheda.

- [?] **I5 · Card di accesso: cosa cambiare?** **Serve la tua decisione.**

---

## Note

- Ogni voce chiusa aggiorna anche le linee guida quando la tocca: il progetto vuole codice
  e documenti nella stessa modifica.
- `revisione/REVISIONE.md` resta il registro dei difetti; questa lista è solo il piano di
  questo giro di lavoro.
