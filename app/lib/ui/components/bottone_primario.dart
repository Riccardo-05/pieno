// Azione primaria: gradiente menta, alta 66–74 px, occupa tutta la larghezza utile
// (pag. 2, 7). "Una sola azione primaria per schermata". Il testo dice cosa succede
// ("Portami qui", non "Naviga" — pag. 10).

import 'package:flutter/widgets.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

class BottonePrimario extends StatelessWidget {
  const BottonePrimario({
    super.key,
    required this.testo,
    required this.onTap,
    this.altezza = PienoSizes.azionePrimaria, // 74 px (Vicino a te)
    this.radius = PienoRadii.bottonePrimarioMax, // 26 px
  });

  final String testo;
  final VoidCallback onTap;
  final double altezza;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: altezza,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: PienoColors.gradienteMenta,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: PienoElevations.bottonePrimario,
        ),
        child: Text(testo, style: PienoText.bottonePrimario),
      ),
    );
  }
}
