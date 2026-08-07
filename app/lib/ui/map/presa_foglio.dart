// Che cosa muove un trascinamento verticale che parte dalla scheda dell'impianto, dentro
// il foglio della mappa.
//
// La scheda è il primo elemento della lista, quindi di suo il gesto finirebbe allo
// scorrimento: DraggableScrollableSheet lo converte in altezza del box solo finché la
// lista è esattamente in cima. Basta averla scorsa di pochi pixel e la stessa presa fa
// una cosa diversa — la maniglia diventa di fatto l'unico appiglio affidabile, ed è
// piccola e poco evidente.
//
// Qui la regola è dichiarata una volta sola, in forma pura e testabile:
//
//   verso l'alto   il box cresce finché non è tutto aperto; poi scorre la lista
//   verso il basso il box cala, ma solo con la lista in cima (altrimenti prima si
//                  torna in cima scorrendo, come ci si aspetta da un elenco)
//
// Le righe sotto la scheda non passano di qui: mantengono lo scorrimento di serie, con
// la sua inerzia.

enum PresaFoglio { alzaBox, abbassaBox, scorriLista }

/// [dy] è lo spostamento del dito in pixel (negativo = verso l'alto), [dimensioneBox] e
/// [boxMin]/[boxMax] sono frazioni di schermo, [offsetLista] lo scorrimento corrente.
PresaFoglio decidiPresa({
  required double dy,
  required double dimensioneBox,
  required double offsetLista,
  required double boxMin,
  required double boxMax,
}) {
  const epsilon = 0.001; // il controller non atterra mai esattamente sui limiti
  if (dy < 0) {
    return dimensioneBox < boxMax - epsilon ? PresaFoglio.alzaBox : PresaFoglio.scorriLista;
  }
  if (dy > 0) {
    final inCima = offsetLista <= 0.5;
    return inCima && dimensioneBox > boxMin + epsilon
        ? PresaFoglio.abbassaBox
        : PresaFoglio.scorriLista;
  }
  return PresaFoglio.scorriLista;
}
