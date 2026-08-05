// I quattro carburanti canonici (linee-guida/05-dati-e-qualita.md).
// Le chiavi combaciano con quelle prodotte dalla pipeline (data-pipeline).

enum Carburante {
  benzina('benzina', 'Benzina'),
  gasolio('gasolio', 'Gasolio (diesel)'),
  gpl('gpl', 'GPL'),
  metano('metano', 'Metano');

  const Carburante(this.chiave, this.etichetta);

  /// Chiave usata nei file JSON di provincia (campo "p").
  final String chiave;

  /// Etichetta leggibile mostrata nell'interfaccia.
  final String etichetta;

  static Carburante daChiave(String chiave) =>
      Carburante.values.firstWhere((c) => c.chiave == chiave);
}
