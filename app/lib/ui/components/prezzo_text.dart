// Prezzo composito: interi in peso 300, decimali in 500 (stesso corpo) — pag. 4, 7.
// "Prezzi sempre a tre decimali, virgola decimale, unità «€/l» separata" (pag. 10):
// l'unità è affiancata, più piccola e allineata alla base del numero.

import 'package:flutter/widgets.dart';
import '../../design/typography.dart';
import '../../design/tokens.dart';
import '../../domain/formato.dart';

class PrezzoText extends StatelessWidget {
  const PrezzoText(this.valore, {super.key, this.mostraUnita = true});

  final double valore;
  final bool mostraUnita;

  @override
  Widget build(BuildContext context) {
    final parti = valore.toStringAsFixed(3).split('.'); // tre decimali
    final interi = parti[0];
    final decimali = parti.length > 1 ? parti[1] : '000';
    // Il numero è composto da pezzi con pesi diversi e l'unità è un widget a parte: letto
    // così a voce diventa una sequenza di glifi. Un'unica etichetta lo sostituisce.
    return Semantics(
      label: prezzoParlato(valore),
      excludeSemantics: true,
      child: _numero(interi, decimali),
    );
  }

  Widget _numero(String interi, String decimali) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text.rich(
          TextSpan(
            style: PienoText.prezzoPrincipale,
            children: [
              TextSpan(text: interi),
              const TextSpan(text: ','), // virgola decimale
              TextSpan(text: decimali, style: PienoText.prezzoPrincipaleDecimali),
            ],
          ),
        ),
        if (mostraUnita)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 12),
            child: Text(
              '€/l',
              style: PienoText.valoreDettaglio.copyWith(color: PienoColors.grafite),
            ),
          ),
      ],
    );
  }
}
