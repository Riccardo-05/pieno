// Test del parsing modello: verifica che l'app legga esattamente il formato prodotto
// dalla pipeline (chiavi corte id/n/v/c/m/lat/lon/p). Nessuna rete richiesta.
//
// Esecuzione: flutter test

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/domain/geojson.dart';
import 'package:pieno/models/carburante.dart';
import 'package:pieno/models/impianto.dart';
import 'package:pieno/state/app_state.dart';

// Estratto reale del formato prodotto da data-pipeline (province/MI.json).
const _json = '''
{
  "versione": "20260805-235718",
  "dato_del": "2026-08-05T08:00:00",
  "provincia": "MI",
  "attribuzione": "Dati: MIMIT — IODL 2.0. © OpenStreetMap contributors.",
  "impianti": [
    {"id":"1001","n":"Eni Stazione Centrale","v":"Via Roma 1","c":"Milano","m":"Eni",
     "lat":45.464,"lon":9.19,
     "p":{"benzina":{"v":1.859,"s":true,"t":"2026-08-05T07:30:00"},
          "gasolio":{"v":1.749,"s":true,"t":"2026-08-05T07:30:00"}}},
    {"id":"1002","n":"Q8 Navigli","v":"Via Naviglio 5","c":"Milano","m":"Q8",
     "lat":45.45,"lon":9.178,
     "p":{"benzina":{"v":1.829,"s":true,"t":"2026-08-05T06:00:00"}}}
  ]
}
''';

void main() {
  test('DatiProvincia.fromJson legge il formato della pipeline', () {
    final dati = DatiProvincia.fromJson(jsonDecode(_json) as Map<String, dynamic>);
    expect(dati.provincia, 'MI');
    expect(dati.impianti.length, 2);
    expect(dati.datoDel, DateTime(2026, 8, 5, 8));

    final eni = dati.impianti.first;
    expect(eni.nome, 'Eni Stazione Centrale');
    expect(eni.prezzoDi(Carburante.benzina)!.valore, 1.859);
    expect(eni.prezzoDi(Carburante.gasolio)!.selfService, true);
  });

  test('l\'ordinamento per prezzo mette il più conveniente per primo', () {
    final dati = DatiProvincia.fromJson(jsonDecode(_json) as Map<String, dynamic>);
    final ordinati =
        ordina(dati.impianti, Carburante.benzina, Ordinamento.prezzo, null);
    expect(ordinati.first.id, '1002'); // 1,829 < 1,859
  });

  test('le quattro chiavi carburante combaciano con la pipeline', () {
    expect(Carburante.values.map((c) => c.chiave).toSet(),
        {'benzina', 'gasolio', 'gpl', 'metano'});
  });

  group('marcatori della mappa', () {
    List<Map<String, dynamic>> features({String? migliore}) {
      final dati = DatiProvincia.fromJson(jsonDecode(_json) as Map<String, dynamic>);
      final geo = geoJsonPrezzi(dati.impianti, Carburante.benzina, idMigliore: migliore);
      return (geo['features'] as List).cast<Map<String, dynamic>>();
    }

    Map<String, dynamic> props(List<Map<String, dynamic>> f, String id) =>
        f.firstWhere((e) => (e['properties'] as Map)['id'] == id)['properties']
            as Map<String, dynamic>;

    test('solo gli impianti col carburante scelto diventano marcatori', () {
      expect(features().length, 2); // entrambi hanno benzina
    });

    test('il migliore è marcato, gli altri no', () {
      final f = features(migliore: '1002');
      expect(props(f, '1002')['migliore'], isTrue);
      expect(props(f, '1001')['migliore'], isFalse);
    });

    test('il prezzo del marcatore è formattato con la virgola', () {
      expect(props(features(), '1002')['prezzo'], '1,829');
    });

    // La selezione NON vive più tra i marcatori: sta in una sorgente separata a una sola
    // feature (geoJsonUno), così toccare un marcatore non ricostruisce l'intero elenco.
    test('geoJsonUno contiene solo l\'impianto selezionato (0 o 1 feature)', () {
      final dati = DatiProvincia.fromJson(jsonDecode(_json) as Map<String, dynamic>);
      final sel = geoJsonUno(dati.impianti.first, Carburante.benzina);
      final feats = (sel['features'] as List).cast<Map<String, dynamic>>();
      expect(feats.length, 1);
      expect((feats.first['properties'] as Map)['id'], '1001');

      final vuoto = geoJsonUno(null, Carburante.benzina);
      expect(vuoto['features'] as List, isEmpty);
    });
  });
}
