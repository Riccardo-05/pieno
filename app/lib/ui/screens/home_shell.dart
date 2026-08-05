// Shell con lo switch flottante Mappa / Vicino a te (pag. 3 e pag. 7).
// Lo switch non è navigazione: le due viste condividono lo stesso stato (carburante,
// provincia, posizione). Passare dall'una all'altra non ricarica nulla.
// Staccato 30 px dal bordo inferiore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../components/switch_pillola.dart';
import 'mappa_screen.dart';
import 'vicino_a_te_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vista = ref.watch(vistaProvider);

    // IndexedStack tiene VIVE entrambe le viste: passare da una all'altra non ricarica
    // nulla (pag. 3) ed evita di distruggere/ricreare la mappa a ogni switch.
    final indice = vista == Vista.mappa ? 0 : 1;
    return Stack(
      children: [
        Positioned.fill(
          child: IndexedStack(
            index: indice,
            children: const [MappaScreen(), VicinoATeScreen()],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 30, // staccato 30 px dal bordo inferiore
          child: Center(
            child: SizedBox(
              width: 260,
              child: Material(
                type: MaterialType.transparency,
                child: SwitchPillola(
                  opzioni: const ['Mappa', 'Vicino a te'],
                  indiceSelezionato: vista == Vista.mappa ? 0 : 1,
                  onCambia: (i) => ref.read(vistaProvider.notifier).state =
                      i == 0 ? Vista.mappa : Vista.vicino,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
