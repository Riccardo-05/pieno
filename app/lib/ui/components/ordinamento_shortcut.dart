// Shortcut dell'ordinamento (Prezzo · Bilanciato · Distanza), in stile pillola in vetro
// con selettore inchiostro. Riusato su Mappa, Vicino a te e nelle Impostazioni.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../state/app_state.dart';
import 'vetro.dart';

class OrdinamentoShortcut extends ConsumerWidget {
  const OrdinamentoShortcut({super.key});

  static const _icone = <Ordinamento, IconData>{
    Ordinamento.prezzo: Icons.euro_symbol,
    Ordinamento.bilanciato: Icons.balance,
    Ordinamento.distanza: Icons.near_me,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ord = ref.watch(ordinamentoProvider);
    return Vetro(
      radius: PienoRadii.pillola,
      blur: PienoElevations.vetroBlurCampi,
      shadows: PienoElevations.pillola,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in Ordinamento.values)
            Tooltip(
              message: o.etichetta,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(ordinamentoProvider.notifier).state = o;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: o == ord ? PienoColors.inchiostro : Colors.transparent,
                    borderRadius: BorderRadius.circular(PienoRadii.pillola),
                  ),
                  child: Icon(
                    _icone[o],
                    size: 18,
                    color: o == ord ? Colors.white : PienoColors.inchiostro,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
