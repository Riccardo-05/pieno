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
