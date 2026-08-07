// La classifica e il costo della deviazione: le due cose che decidono quale impianto
// l'utente vede per primo, e quanto gli si promette di risparmiare.
//
// Il difetto che questi test chiudono: la classifica si faceva col righello (linea
// d'aria) mentre la scheda mostrava i chilometri di strada. Due metri diversi per
// scegliere e per raccontare.

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/data/location_service.dart';
import 'package:pieno/domain/risparmio.dart';
import 'package:pieno/models/carburante.dart';
import 'package:pieno/models/impianto.dart';
import 'package:pieno/state/app_state.dart';

Impianto impianto(String id, {required double lat, required double lon, double? benzina}) =>
    Impianto(
      id: id,
      nome: 'Impianto $id',
      indirizzo: '',
      comune: '',
      marchio: '',
      lat: lat,
      lon: lon,
      prezzi: {
        if (benzina != null)
          Carburante.benzina: Prezzo(
            carburante: Carburante.benzina,
            valore: benzina,
            selfService: true,
            comunicatoIl: null,
          ),
      },
    );

const origine = Posizione(45.4641, 9.1901);

void main() {
  group('ordinamento per distanza', () {
    // «aria» è a ~1 km in linea d'aria ma di là dal fiume: 14 km di strada.
    // «strada» è a ~3 km in linea d'aria e 4 km di strada.
    final vicinoInAria = impianto('aria', lat: 45.4731, lon: 9.1901, benzina: 1.9);
    final vicinoInStrada = impianto('strada', lat: 45.4911, lon: 9.1901, benzina: 1.8);
    final elenco = [vicinoInAria, vicinoInStrada];

    test('senza distanze reali si ordina col righello, come prima', () {
      final ordinati = ordina(elenco, Carburante.benzina, Ordinamento.distanza, origine);

      expect(ordinati.map((i) => i.id), ['aria', 'strada']);
    });

    test('con le distanze su strada vince chi è davvero più vicino di strada', () {
      final ordinati = ordina(
        elenco,
        Carburante.benzina,
        Ordinamento.distanza,
        origine,
        kmPerId: const {'aria': 14.0, 'strada': 4.0},
      );

      expect(ordinati.map((i) => i.id), ['strada', 'aria'],
          reason: 'la classifica deve usare lo stesso metro della scheda');
    });

    test('anche il bilanciato usa i chilometri di strada', () {
      final ordinati = ordina(
        elenco,
        Carburante.benzina,
        Ordinamento.bilanciato,
        origine,
        kmPerId: const {'aria': 14.0, 'strada': 4.0},
      );

      // «strada» costa meno ed è più vicino di strada: vince su entrambi i fronti.
      expect(ordinati.first.id, 'strada');
    });

    test('un impianto senza distanza nota ricade sul righello, non sparisce', () {
      final ordinati = ordina(
        elenco,
        Carburante.benzina,
        Ordinamento.distanza,
        origine,
        kmPerId: const {'strada': 4.0},
      );

      expect(ordinati.length, 2);
      expect(ordinati.first.id, 'aria', reason: "~1 km d'aria è il solo numero che si ha");
    });

    test("l'ordinamento per prezzo non guarda le distanze", () {
      final ordinati = ordina(
        elenco,
        Carburante.benzina,
        Ordinamento.prezzo,
        origine,
        kmPerId: const {'aria': 14.0, 'strada': 4.0},
      );

      expect(ordinati.map((i) => i.id), ['strada', 'aria']);
    });
  });

  group("costo della deviazione sull'elenco", () {
    final a = impianto('a', lat: 45.47, lon: 9.19, benzina: 1.8);
    final b = impianto('b', lat: 45.48, lon: 9.19, benzina: 1.8);
    final c = impianto('c', lat: 45.49, lon: 9.19, benzina: 1.8);

    test('il riferimento è il più vicino di tutti, anche se la sua è una stima', () {
      // «a» è il più vicino ma il servizio non ha risposto per lui: se lo si ignora,
      // il riferimento diventa «b» a 10 km e «c» sembra deviare 5 km invece di 13.
      final costi = costiDiDeviazione(
        elenco: [a, b, c],
        distanze: const {
          'a': (km: 2.0, reale: false),
          'b': (km: 10.0, reale: true),
          'c': (km: 15.0, reale: true),
        },
        carburante: Carburante.benzina,
        consumoLitriPer100km: 7,
      );

      // 13 km in più × 2 (a/r) × 7/100 l × 1,80 €/l = 3,276 €
      expect(costi['c'], closeTo(3.276, 0.001));
      expect(costi['b'], closeTo(2.016, 0.001));
    });

    test('senza nessuna distanza reale non si inventa nulla', () {
      final costi = costiDiDeviazione(
        elenco: [a, b],
        distanze: const {
          'a': (km: 2.0, reale: false),
          'b': (km: 10.0, reale: false),
        },
        carburante: Carburante.benzina,
        consumoLitriPer100km: 7,
      );

      expect(costi, isEmpty,
          reason: 'col solo righello la deviazione sarebbe finta precisione');
    });

    test('chi è il più vicino non paga', () {
      final costi = costiDiDeviazione(
        elenco: [a, b],
        distanze: const {
          'a': (km: 2.0, reale: true),
          'b': (km: 10.0, reale: true),
        },
        carburante: Carburante.benzina,
        consumoLitriPer100km: 7,
      );

      expect(costi['a'], 0);
    });

    test('a chi resta alla stima non si addebita una deviazione misurata a metà', () {
      final costi = costiDiDeviazione(
        elenco: [a, b],
        distanze: const {
          'a': (km: 2.0, reale: true),
          'b': (km: 10.0, reale: false),
        },
        carburante: Carburante.benzina,
        consumoLitriPer100km: 7,
      );

      expect(costi.containsKey('b'), isFalse);
      expect(costi['a'], 0);
    });
  });
}
