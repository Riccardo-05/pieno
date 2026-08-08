// La dissolvenza dei bordi deve sfumare SOLO dove c'è contenuto fuori campo.
//
// Difetto presidiato: la maschera era incondizionata, quindi a riposo sbiadiva il primo
// elemento della lista. Nelle Impostazioni la card d'accesso sembrava tagliata dalla safe
// area, mentre era la sfumatura che lavorava a vuoto.
//
// Secondo difetto, emerso proprio da questi test: il primo tentativo di correzione
// inseriva e toglieva il `ShaderMask` a seconda dello scorrimento. Cambiando il tipo di
// widget sopra la lista, Flutter ne ricreava il sottoalbero e la posizione di scorrimento
// si azzerava. L'ultimo test tiene chiusa quella porta.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/ui/components/dissolvenza.dart';

void main() {
  group('gradiente della maschera', () {
    test('a riposo in cima: estremo superiore opaco, niente bordo sbiadito', () {
      final g = gradienteDissolvenza(alto: 0, basso: 80, altezza: 600);
      expect(g.colors.first.a, 1.0, reason: 'la testa non deve sfumare');
      expect(g.colors.last.a, 0.0, reason: 'la coda sì: sotto c\'è altro contenuto');
    });

    test('in fondo alla lista: estremo inferiore opaco', () {
      final g = gradienteDissolvenza(alto: 12, basso: 0, altezza: 600);
      expect(g.colors.first.a, 0.0);
      expect(g.colors.last.a, 1.0);
    });

    test('lista tutta dentro la finestra: nessuna sfumatura', () {
      final g = gradienteDissolvenza(alto: 0, basso: 0, altezza: 600);
      expect(dissolvenzaNeutra(g), isTrue);
    });

    test('a metà lista sfumano entrambi gli estremi', () {
      final g = gradienteDissolvenza(alto: 12, basso: 80, altezza: 600);
      expect(g.colors.first.a, 0.0);
      expect(g.colors.last.a, 0.0);
    });

    test('le fermate restano in ordine anche su riquadri più corti delle sfumature', () {
      final g = gradienteDissolvenza(alto: 120, basso: 200, altezza: 100);
      final stops = g.stops!;
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i], greaterThanOrEqualTo(stops[i - 1]));
      }
    });

    test('riquadro di altezza nulla non manda in errore', () {
      expect(dissolvenzaNeutra(gradienteDissolvenza(alto: 12, basso: 80, altezza: 0)),
          isTrue);
    });
  });

  testWidgets('la sfumatura non azzera la posizione di scorrimento', (tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: Dissolvenza(
            alto: 12,
            basso: 80,
            child: ListView.builder(
              controller: c,
              itemCount: 20,
              itemBuilder: (_, i) => SizedBox(height: 100, child: Text('riga $i')),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    c.jumpTo(300);
    await tester.pumpAndSettle();
    // Se la comparsa della sfumatura ricreasse il sottoalbero, qui si leggerebbe 0.
    expect(c.offset, 300);

    c.jumpTo(c.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(c.offset, c.position.maxScrollExtent);
  });
}
