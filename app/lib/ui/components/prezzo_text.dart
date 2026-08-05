// Prezzo composito: interi in peso 300, decimali in 500 (stesso corpo) — pag. 4, 7.
// "Prezzi sempre a tre decimali, virgola decimale, unità «€/l» separata" (pag. 10).

import 'package:flutter/widgets.dart';
import '../../design/typography.dart';

class PrezzoText extends StatelessWidget {
  const PrezzoText(this.valore, {super.key, this.mostraUnita = true});

  final double valore;
  final bool mostraUnita;

  @override
  Widget build(BuildContext context) {
    final s = valore.toStringAsFixed(3); // tre decimali
    final parti = s.split('.');
    final interi = parti[0];
    final decimali = parti.length > 1 ? parti[1] : '000';
    return Text.rich(
      TextSpan(
        style: PienoText.prezzoPrincipale,
        children: [
          TextSpan(text: interi),
          const TextSpan(text: ','), // virgola decimale
          TextSpan(text: decimali, style: PienoText.prezzoPrincipaleDecimali),
          if (mostraUnita)
            TextSpan(
              text: ' €/l',
              style: PienoText.valoreDettaglio, // unità separata, più piccola
            ),
        ],
      ),
    );
  }
}
