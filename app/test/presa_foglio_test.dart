// La regola della presa sulla scheda dell'impianto (foglio della mappa).
// Il difetto che questi test presidiano: con la lista scorsa anche di poco, afferrare la
// scheda scorreva l'elenco invece di alzare il box, e la presa sembrava non funzionare.

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/ui/map/presa_foglio.dart';

const double min = 0.30;
const double max = 0.92;

PresaFoglio presa(double dy, double box, double offset) => decidiPresa(
      dy: dy,
      dimensioneBox: box,
      offsetLista: offset,
      boxMin: min,
      boxMax: max,
    );

void main() {
  group('verso l\'alto', () {
    test('alza il box con la lista in cima', () {
      expect(presa(-8, 0.46, 0), PresaFoglio.alzaBox);
    });

    test('alza il box ANCHE con la lista già scorsa (il difetto corretto)', () {
      expect(presa(-8, 0.46, 120), PresaFoglio.alzaBox);
    });

    test('a box tutto aperto scorre la lista', () {
      expect(presa(-8, max, 0), PresaFoglio.scorriLista);
      expect(presa(-8, max, 200), PresaFoglio.scorriLista);
    });
  });

  group('verso il basso', () {
    test('abbassa il box con la lista in cima', () {
      expect(presa(8, 0.46, 0), PresaFoglio.abbassaBox);
    });

    test('con la lista scorsa prima torna in cima scorrendo', () {
      expect(presa(8, 0.46, 120), PresaFoglio.scorriLista);
    });

    test('a box tutto chiuso non scende oltre', () {
      expect(presa(8, min, 0), PresaFoglio.scorriLista);
    });
  });

  test('gesto fermo non muove nulla', () {
    expect(presa(0, 0.46, 0), PresaFoglio.scorriLista);
  });

  test('i limiti tollerano l\'arrotondamento del controller', () {
    // Il controller non atterra mai esattamente su min/max: senza tolleranza il box
    // resterebbe "quasi aperto" e continuerebbe a farsi alzare di un pelo.
    expect(presa(-8, max - 0.0005, 0), PresaFoglio.scorriLista);
    expect(presa(8, min + 0.0005, 0), PresaFoglio.scorriLista);
  });
}
