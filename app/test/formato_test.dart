// La data del dato, come la legge chi apre le Impostazioni.
//
// Difetto che questi test chiudono: da quando la pipeline scrive `dato_del` con
// l'offset (`2026-08-07T00:00:00+02:00`), Dart restituisce un DateTime **in UTC**.
// Stampandone i componenti così com'erano usciva «06/08/2026, ore 22:00» — lo stesso
// identico istante, raccontato nel fuso sbagliato. L'utente leggeva la data di ieri su
// dati di oggi: il contrario di quello che la correzione sul fuso voleva ottenere.
//
// I test qui sotto **non si ancorano a un fuso**: sarebbe lo stesso errore appena
// corretto nella pipeline, dove i test passavano in Italia e cadevano sul runner in
// UTC. Si verifica la regola, che vale ovunque: la data si mostra nel fuso di chi
// guarda, mai in quello in cui è arrivata.

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/domain/formato.dart';

String due(int n) => n.toString().padLeft(2, '0');

String atteso(DateTime quando) {
  final l = quando.toLocal();
  return '${due(l.day)}/${due(l.month)}/${l.year}, ore ${due(l.hour)}:${due(l.minute)}';
}

void main() {
  group('data e ora del dato', () {
    test('una data con offset si mostra nel fuso di chi guarda', () {
      final quando = DateTime.parse('2026-08-07T00:00:00+02:00');

      expect(quando.isUtc, isTrue, reason: 'è così che Dart restituisce una data con offset');
      expect(formattaDataOra(quando), atteso(quando));
    });

    test('due scritture dello stesso istante si leggono uguali', () {
      // `2026-08-07T00:00:00+02:00` e `2026-08-06T22:00:00Z` sono lo stesso momento.
      expect(
        formattaDataOra(DateTime.parse('2026-08-07T00:00:00+02:00')),
        formattaDataOra(DateTime.parse('2026-08-06T22:00:00Z')),
      );
    });

    test('una data già locale si formatta senza spostarsi', () {
      final quando = DateTime(2026, 8, 7, 8, 30);

      expect(formattaDataOra(quando), '07/08/2026, ore 08:30');
    });

    test('giorno, mese e ora hanno sempre due cifre', () {
      expect(formattaDataOra(DateTime(2026, 3, 5, 9, 7)), '05/03/2026, ore 09:07');
    });
  });
}
