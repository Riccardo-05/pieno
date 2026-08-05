// Navigatore esterno scelto in Impostazioni → Mappa e navigazione → "Apri con"
// (pag. 8, 9). Il predefinito di sistema è la prima opzione.

enum Navigatore {
  sistema('Predefinito di sistema'),
  apple('Apple Maps'),
  google('Google Maps'),
  waze('Waze');

  const Navigatore(this.etichetta);
  final String etichetta;
}
