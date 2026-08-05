// Sfondo con le due aurore sfocate (pag. 4): menta Ø 420 in alto a destra,
// lavanda Ø 380 in basso a sinistra, blur 70. Mai visibili come forme.

import 'dart:ui';
import 'package:flutter/widgets.dart';
import '../../design/tokens.dart';

class SfondoAurore extends StatelessWidget {
  const SfondoAurore({super.key, required this.child, this.fondo = PienoColors.fondo});

  final Widget child;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondo,
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _aurora(420, PienoColors.auroraMenta),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: _aurora(380, PienoColors.auroraLavanda),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _aurora(double d, Color c) => ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: PienoElevations.auroraBlur,
          sigmaY: PienoElevations.auroraBlur,
        ),
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      );
}
