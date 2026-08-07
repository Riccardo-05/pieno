// Formattazione condivisa dei prezzi carburante.
// Formato del design (pag. 10): tre decimali, virgola come separatore decimale.
// Unico punto di verità: se il formato cambia, si tocca solo qui.

/// «1,899» — tre decimali, virgola decimale. Senza unità (€/l va aggiunta a parte).
String formattaPrezzo(double valore) =>
    valore.toStringAsFixed(3).replaceAll('.', ',');
