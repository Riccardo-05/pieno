// Selettore a tendina del carburante (pag. 7: "la pillola del carburante"), in stile
// vetro. Toccandolo si apre una cascata con i quattro carburanti; la scelta è condivisa
// (carburanteProvider) fra Mappa, Vicino a te e Impostazioni.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/carburante.dart';
import '../../state/app_state.dart';
import 'vetro.dart';

class CarburanteSelettore extends ConsumerStatefulWidget {
  const CarburanteSelettore({super.key});

  @override
  ConsumerState<CarburanteSelettore> createState() => _CarburanteSelettoreState();
}

class _CarburanteSelettoreState extends ConsumerState<CarburanteSelettore> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _chiudi();
    super.dispose();
  }

  void _apriChiudi() {
    HapticFeedback.selectionClick();
    _overlay == null ? _apri() : _chiudi();
  }

  void _apri() {
    final box = context.findRenderObject() as RenderBox;
    final centro = box.localToGlobal(Offset.zero).dx + box.size.width / 2;
    // Allinea il pannello al lato del selettore verso il centro schermo (non esce fuori).
    final destra = centro > MediaQuery.of(context).size.width / 2;
    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Tocco fuori per chiudere.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _chiudi,
              child: const SizedBox(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: destra ? Alignment.bottomRight : Alignment.bottomLeft,
            followerAnchor: destra ? Alignment.topRight : Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Align(
              alignment: destra ? Alignment.topRight : Alignment.topLeft,
              child: SizedBox(width: 190, child: _pannello()),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _chiudi() {
    _overlay?.remove();
    _overlay = null;
  }

  void _scegli(Carburante c) {
    HapticFeedback.lightImpact(); // più percepibile della selectionClick alla scelta
    ref.read(carburanteProvider.notifier).state = c;
    _chiudi();
  }

  Widget _pannello() {
    final attuale = ref.read(carburanteProvider);
    return Material(
      color: Colors.transparent,
      child: Vetro(
        radius: 18,
        blur: PienoElevations.vetroBlurSchede,
        shadows: PienoElevations.schedaPrincipale,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in Carburante.values)
              InkWell(
                onTap: () => _scegli(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.etichetta,
                          style: PienoText.voceImpostazione.copyWith(
                            fontWeight: c == attuale ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (c == attuale)
                        const Icon(Icons.check, size: 18, color: PienoColors.mentaScura),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carburante = ref.watch(carburanteProvider);
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _apriChiudi,
        child: Vetro(
          radius: PienoRadii.pillola,
          blur: PienoElevations.vetroBlurCampi,
          shadows: PienoElevations.pillola,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(carburante.etichetta, style: PienoText.voceImpostazione),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18, color: PienoColors.inchiostro),
            ],
          ),
        ),
      ),
    );
  }
}
