// La scelta della provincia dalla posizione: il primo dato che l'app decide da sola,
// e quello che, se sbagliato, fa vedere un elenco di impianti tutti lontani senza
// dare all'utente nessun modo di capire perché.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/models/manifest.dart';

/// Due province come sono davvero: Milano grande, col baricentro spostato a sud, e
/// Monza piccola e appiccicata al suo confine.
const _conRiquadri = '''
{
  "versione": "1",
  "province": [
    {"sigla": "MI", "impianti": 1300,
     "centro": {"lat": 45.42, "lon": 9.10},
     "riquadro": {"latMin": 45.15, "latMax": 45.52, "lonMin": 8.70, "lonMax": 9.40}},
    {"sigla": "MB", "impianti": 260,
     "centro": {"lat": 45.65, "lon": 9.28},
     "riquadro": {"latMin": 45.53, "latMax": 45.78, "lonMin": 9.05, "lonMax": 9.50}}
  ]
}
''';

/// Lo stesso manifest come lo scriveva la pipeline prima: solo baricentri.
const _senzaRiquadri = '''
{
  "versione": "1",
  "province": [
    {"sigla": "MI", "impianti": 1300, "centro": {"lat": 45.42, "lon": 9.10}},
    {"sigla": "MB", "impianti": 260, "centro": {"lat": 45.65, "lon": 9.28}}
  ]
}
''';

Manifest leggi(String testo) =>
    Manifest.fromJson(jsonDecode(testo) as Map<String, dynamic>);

void main() {
  group('provincia più vicina', () {
    test('chi sta dentro un riquadro finisce in quella provincia', () {
      // Alle porte di Monza: dentro il riquadro di MB, ma con il baricentro di MI
      // più vicino di quello brianzolo.
      expect(leggi(_conRiquadri).provinciaPiuVicina(45.545, 9.10), 'MB');
    });

    test('col solo baricentro si sbagliava, ed è il difetto che il riquadro chiude', () {
      expect(leggi(_senzaRiquadri).provinciaPiuVicina(45.545, 9.10), 'MI');
    });

    test('nel cuore di Milano resta Milano', () {
      expect(leggi(_conRiquadri).provinciaPiuVicina(45.4641, 9.1901), 'MI');
    });

    test('fuori da tutti i riquadri vince il baricentro più vicino', () {
      expect(leggi(_conRiquadri).provinciaPiuVicina(44.0, 9.0), 'MI');
    });

    test('un manifest senza coordinate non sceglie nulla invece di indovinare', () {
      final m = leggi('{"versione":"1","province":[{"sigla":"MI","impianti":10}]}');

      expect(m.provinciaPiuVicina(45.46, 9.19), isNull);
    });

    test('i file salvati prima che il riquadro esistesse si leggono ancora', () {
      final m = leggi(_senzaRiquadri);

      expect(m.province.first.sigla, 'MI');
      expect(m.province.first.riquadro, isNull);
    });
  });
}
