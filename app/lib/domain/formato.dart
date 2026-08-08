// Formattazione condivisa dei prezzi carburante.
// Formato del design (pag. 10): tre decimali, virgola come separatore decimale.
// Unico punto di verità: se il formato cambia, si tocca solo qui.

/// «1,899» — tre decimali, virgola decimale. Senza unità (€/l va aggiunta a parte).
String formattaPrezzo(double valore) =>
    valore.toStringAsFixed(3).replaceAll('.', ',');

/// «1,899 euro al litro» — come deve leggerlo lo screen reader (pag. 13 e checklist di
/// rilascio). Sullo schermo «€/l» è un'unità affiancata e più piccola; letta a voce
/// diventerebbe una sigla, quindi va scritta per esteso nell'etichetta semantica.
String prezzoParlato(double valore) => '${formattaPrezzo(valore)} euro al litro';

/// «3,25 euro» — importo in euro con due decimali, per etichette e lettura vocale.
String formattaEuro(double valore) =>
    valore.toStringAsFixed(2).replaceAll('.', ',');

/// «07/08/2026, ore 00:00» — data e ora **nel fuso di chi guarda**.
///
/// Il `toLocal()` non è un dettaglio. La pipeline scrive `dato_del` con l'offset
/// italiano, e Dart restituisce quelle stringhe come istanti **in UTC**: stampandone i
/// componenti così com'erano, un dato del 7 agosto compariva come «06/08/2026, ore
/// 22:00». Lo stesso momento, raccontato nel fuso sbagliato — cioè un dato di oggi
/// spacciato per quello di ieri, proprio nella schermata che esiste per dire quanto è
/// fresco.
///
/// Un istante non ha una data finché non si sceglie da dove lo si guarda: qui si
/// sceglie il fuso del telefono, l'unico che l'utente riconosce.
String formattaDataOra(DateTime quando) {
  final l = quando.toLocal();
  String due(int n) => n.toString().padLeft(2, '0');
  return '${due(l.day)}/${due(l.month)}/${l.year}, ore ${due(l.hour)}:${due(l.minute)}';
}
