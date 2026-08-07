// Dissolvenza ai bordi di un contenuto scorrevole.
//
// Serve dove il contenuto passa sotto qualcosa di fisso — lo switch flottante, la maniglia
// del foglio, il bordo dello schermo — e senza di essa verrebbe tranciato di netto.
//
// Sfuma il CONTENUTO verso la trasparenza (maschera in `dstIn`), non stende un velo del
// colore di fondo: sotto le schermate c'è lo sfondo con le due aurore, e un velo pieno le
// spegnerebbe. Così lo sfondo resta quello che è e a sparire è solo ciò che scorre.
//
// Le altezze sono in pixel logici e vanno fatte combaciare con l'ingombro dell'elemento
// fisso, così il contenuto svanisce esattamente nella fascia che quell'elemento occupa.

import 'package:flutter/widgets.dart';

const Color _tieni = Color(0xFF000000); // opaco nella maschera = pixel conservato
const Color _togli = Color(0x00000000); // trasparente = pixel cancellato

class Dissolvenza extends StatelessWidget {
  const Dissolvenza({
    super.key,
    required this.child,
    this.alto = 0,
    this.basso = 0,
  });

  final Widget child;

  /// Altezza della sfumatura in testa (0 = bordo netto).
  final double alto;

  /// Altezza della sfumatura in coda (0 = bordo netto).
  final double basso;

  @override
  Widget build(BuildContext context) {
    if (alto <= 0 && basso <= 0) return child;
    return ShaderMask(
      shaderCallback: _maschera,
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  Shader _maschera(Rect rect) {
    final h = rect.height;
    if (h <= 0) {
      return const LinearGradient(colors: [_tieni, _tieni]).createShader(rect);
    }
    // Le fermate devono restare in ordine anche su riquadri più corti delle sfumature.
    final inizio = (alto / h).clamp(0.0, 1.0);
    final fine = (1 - basso / h).clamp(inizio, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [alto > 0 ? _togli : _tieni, _tieni, _tieni, basso > 0 ? _togli : _tieni],
      stops: [0, inizio, fine, 1],
    ).createShader(rect);
  }
}
