// Azione primaria: gradiente menta, alta 66–74 px, occupa tutta la larghezza utile
// (pag. 2, 7). "Una sola azione primaria per schermata". Il testo dice cosa succede
// ("Portami qui", non "Naviga" — pag. 10).
//
// Ha un feedback di pressione immediato (scala + leggera opacità) così il tocco si
// "sente" subito, anche prima che parta l'azione (es. il dialogo di sistema).

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

class BottonePrimario extends StatefulWidget {
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
  State<BottonePrimario> createState() => _BottonePrimarioState();
}

class _BottonePrimarioState extends State<BottonePrimario> {
  bool _premuto = false;

  void _premi(bool v) {
    if (_premuto != v) setState(() => _premuto = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _premi(true),
      onTapCancel: () => _premi(false),
      onTapUp: (_) => _premi(false),
      onTap: () {
        HapticFeedback.mediumImpact(); // azione primaria: feedback deciso
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _premuto ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _premuto ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: widget.altezza,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: PienoColors.gradienteMenta,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: PienoElevations.bottonePrimario,
            ),
            child: Text(widget.testo, style: PienoText.bottonePrimario),
          ),
        ),
      ),
    );
  }
}
