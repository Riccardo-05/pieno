// Costruzione del GeoJSON dei prezzi per la mappa (pag. 6, 13).
// Il prezzo è il marcatore: nessuna icona di pompa, il numero è l'informazione,
// disegnato in un layer con gestione delle collisioni (non come widget).

import '../models/carburante.dart';
import '../models/impianto.dart';
import 'formato.dart';

/// FeatureCollection con un punto per impianto che ha il carburante indicato.
/// Proprietà: id, prezzo (testo "1,859"), prezzoNum, migliore (bool).
/// La selezione NON sta qui: vive in una sorgente separata a una sola feature
/// (geoJsonUno), così toccare un marcatore non ricostruisce l'intero elenco (fluidità).
Map<String, dynamic> geoJsonPrezzi(
  List<Impianto> impianti,
  Carburante carburante, {
  String? idMigliore,
}) {
  final features = <Map<String, dynamic>>[
    for (final i in impianti)
      if (i.prezzoDi(carburante) != null && i.lat != null && i.lon != null)
        _feature(i, i.prezzoDi(carburante)!, i.id == idMigliore),
  ];
  return {'type': 'FeatureCollection', 'features': features};
}

/// FeatureCollection con la sola feature dell'impianto selezionato (0 o 1).
/// Aggiornata a ogni selezione: costa una feature, non l'intera provincia.
Map<String, dynamic> geoJsonUno(Impianto? i, Carburante carburante) {
  final p = i?.prezzoDi(carburante);
  if (i == null || p == null || i.lat == null || i.lon == null) {
    return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
  }
  return {
    'type': 'FeatureCollection',
    'features': [_feature(i, p, false)],
  };
}

Map<String, dynamic> _feature(Impianto i, Prezzo p, bool migliore) => {
      'type': 'Feature',
      // id a livello di feature: MapLibre lo restituisce nel callback del tocco, così
      // non serve interrogare la mappa (queryRenderedFeatures) → selezione immediata.
      'id': i.id,
      'geometry': {
        'type': 'Point',
        'coordinates': [i.lon, i.lat], // GeoJSON = [lon, lat]
      },
      'properties': {
        'id': i.id,
        'prezzo': formattaPrezzo(p.valore),
        // Arrotondato a 3 decimali: evita code in virgola mobile nell'etichetta cluster.
        'prezzoNum': double.parse(p.valore.toStringAsFixed(3)),
        'migliore': migliore,
      },
    };
