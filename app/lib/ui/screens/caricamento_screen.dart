// Schermata di caricamento (splash), mostrata a ogni avvio e durante la preparazione
// (permessi, posizione, dati) fino a quando l'app è pronta. Immagine del marchio + nome
// centrati; barra di avanzamento CONTINUA (segmento che scorre) così è sempre chiaro che
// si sta caricando, anche nella transizione dopo il consenso. Dissolvenza gestita da AvvioGate.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';

const _immagine = 'assets/icons/caricamento/caricamento.png';

class CaricamentoScreen extends StatelessWidget {
  const CaricamentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Logo + nome centrati come gruppo unico nello spazio disponibile.
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOut,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
                      ),
                      child: SizedBox(
                        height: h * 0.34,
                        child: Image.asset(
                          _immagine,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('Pieno', style: PienoText.titoloPagina.copyWith(fontSize: 30)),
                    const SizedBox(height: 4),
                    Text('Prezzi carburanti · Italia', style: PienoText.valoreDettaglio),
                  ],
                ),
              ),
            ),
            const _BarraContinua(),
            const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }
}

/// Barra di caricamento indeterminata: un segmento menta scorre in loop (easeInOut).
class _BarraContinua extends StatefulWidget {
  const _BarraContinua();

  @override
  State<_BarraContinua> createState() => _BarraContinuaState();
}

class _BarraContinuaState extends State<_BarraContinua> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const w = 190.0, segW = 74.0;
    return SizedBox(
      width: w,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: ColoredBox(
          color: PienoColors.grafite.withValues(alpha: 0.18),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(_c.value);
              final x = -segW + (w + segW) * t;
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: 0,
                    bottom: 0,
                    width: segW,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: PienoColors.gradienteMenta,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
