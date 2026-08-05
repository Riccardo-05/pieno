// Costruzione del GeoJSON dei prezzi per la mappa (pag. 6, 13).
// Il prezzo è il marcatore: nessuna icona di pompa, il numero è l'informazione,
// disegnato in un layer con gestione delle collisioni (non come widget).

import '../models/carburante.dart';
import '../models/impianto.dart';

/// FeatureCollection con un punto per impianto che ha il carburante indicato.
/// Proprietà per feature: id, prezzo (testo "1,859"), prezzoNum, migliore (bool),
/// selezionato (bool) — quest'ultimo distingue sulla mappa l'impianto aperto nel
/// foglio, con lo stesso stato condiviso dall'elenco (pag. 3).
Map<String, dynamic> geoJsonPrezzi(
  List<Impianto> impianti,
  Carburante carburante, {
  String? idMigliore,
  String? idSelezionato,
}) {
  final features = <Map<String, dynamic>>[];
  for (final i in impianti) {
    final p = i.prezzoDi(carburante);
    if (p == null || i.lat == null || i.lon == null) continue;
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [i.lon, i.lat], // GeoJSON = [lon, lat]
      },
      'properties': {
        'id': i.id,
        'prezzo': p.valore.toStringAsFixed(3).replaceAll('.', ','),
        'prezzoNum': p.valore,
        'migliore': i.id == idMigliore,
        'selezionato': idSelezionato != null && i.id == idSelezionato,
      },
    });
  }
  return {'type': 'FeatureCollection', 'features': features};
}
