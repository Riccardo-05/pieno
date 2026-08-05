// Superficie in vetro: bianco 72% + background blur + bordo interno bianco 85%.
// (pag. 4 e pag. 10). Blur 14 px per i campi, 26 px per le schede.

import 'dart:ui';
import 'package:flutter/widgets.dart';
import '../../design/tokens.dart';

class Vetro extends StatelessWidget {
  const Vetro({
    super.key,
    required this.child,
    this.radius = PienoRadii.schedaPrincipale,
    this.blur = PienoElevations.vetroBlurSchede,
    this.shadows = PienoElevations.schedaPrincipale,
    this.padding = EdgeInsets.zero,
    this.fill = PienoColors.vetro,
  });

  final Widget child;
  final double radius;
  final double blur;
  final List<BoxShadow> shadows;
  final EdgeInsets padding;

  /// Riempimento del vetro. Default bianco 72%; i chip alternativa usano bianco 50%.
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: r,
              border: Border.all(color: PienoColors.vetroBordo, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
