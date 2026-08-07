// Pulsante tondo in vetro: 40 px (elenco) o 52 px (mappa) — pag. 3, 6.

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../design/tokens.dart';
import 'vetro.dart';

class PulsanteTondo extends StatelessWidget {
  const PulsanteTondo({
    super.key,
    required this.icona,
    required this.onTap,
    this.diametro = PienoSizes.pulsanteTondoMappa,
  });

  final Widget icona;
  final VoidCallback onTap;
  final double diametro;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: diametro,
        height: diametro,
        child: Vetro(
          radius: diametro / 2,
          blur: PienoElevations.vetroBlurCampi,
          shadows: PienoElevations.pillola,
          child: Center(child: icona),
        ),
      ),
    );
  }
}
