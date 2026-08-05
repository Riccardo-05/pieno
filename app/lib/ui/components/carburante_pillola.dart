// Pillola del carburante selezionato (pag. 7: "A destra la pillola del carburante").
// Nello scheletro il tocco cicla tra i quattro carburanti; il selettore dedicato
// vive in Impostazioni (Tappa 05).

import 'package:flutter/widgets.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/carburante.dart';
import 'vetro.dart';

class CarburantePillola extends StatelessWidget {
  const CarburantePillola({super.key, required this.carburante, required this.onTap});

  final Carburante carburante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Vetro(
        radius: PienoRadii.pillola,
        blur: PienoElevations.vetroBlurCampi,
        shadows: PienoElevations.pillola,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(carburante.etichetta, style: PienoText.voceImpostazione),
      ),
    );
  }
}
