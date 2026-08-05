// Smoke test di un componente del design system, senza rete.
// (Sostituisce il test-contatore di default generato da `flutter create`.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/ui/components/bottone_primario.dart';

void main() {
  testWidgets('BottonePrimario mostra il testo e risponde al tocco', (tester) async {
    var premuto = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BottonePrimario(testo: 'Portami qui', onTap: () => premuto = true),
        ),
      ),
    );

    expect(find.text('Portami qui'), findsOneWidget);
    await tester.tap(find.text('Portami qui'));
    expect(premuto, isTrue);
  });
}
