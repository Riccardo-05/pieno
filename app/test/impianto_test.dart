// Test del parsing modello: verifica che l'app legga esattamente il formato prodotto
// dalla pipeline (chiavi corte id/n/v/c/m/lat/lon/p). Nessuna rete richiesta.
//
// Esecuzione: flutter test

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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

  test('ordinaPerPrezzo mette il più conveniente per primo', () {
    final dati = DatiProvincia.fromJson(jsonDecode(_json) as Map<String, dynamic>);
    final ordinati = ordinaPerPrezzo(dati.impianti, Carburante.benzina);
    expect(ordinati.first.id, '1002'); // 1,829 < 1,859
  });

  test('le quattro chiavi carburante combaciano con la pipeline', () {
    expect(Carburante.values.map((c) => c.chiave).toSet(),
        {'benzina', 'gasolio', 'gpl', 'metano'});
  });
}
