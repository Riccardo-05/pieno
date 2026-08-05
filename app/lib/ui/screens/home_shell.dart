// Shell con lo switch flottante Mappa / Vicino a te (pag. 3 e pag. 7).
// Lo switch non è navigazione: le due viste condividono lo stesso stato (carburante,
// provincia, posizione). Passare dall'una all'altra non ricarica nulla.
//
// Gestisce anche il "ritorno dopo il rifornimento" (Tappa 06): se c'è un rifornimento
// in sospeso, all'avvio chiede se il pieno è stato fatto e se il prezzo corrispondeva.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/typography.dart';
import '../../models/segnalazione.dart';
import '../../state/app_state.dart';
import '../components/switch_pillola.dart';
import 'mappa_screen.dart';
import 'vicino_a_te_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // All'avvio (= dopo l'eventuale tragitto): se c'è un rifornimento in sospeso, chiedi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = ref.read(rientroProvider);
      if (r != null) _chiediRientro(r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vista = ref.watch(vistaProvider);
    final nascondiSwitch = vista == Vista.mappa && ref.watch(foglioEspansoProvider);

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
          bottom: 30,
          child: IgnorePointer(
            ignoring: nascondiSwitch,
            child: AnimatedOpacity(
              opacity: nascondiSwitch ? 0 : 1,
              duration: const Duration(milliseconds: 200),
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
          ),
        ),
      ],
    );
  }

  Future<void> _chiediRientro(Rientro r) async {
    if (!mounted) return;
    final prezzo = r.prezzoMostrato.toStringAsFixed(3).replaceAll('.', ',');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Com\'è andato il pieno?'),
        content: Text(
          'Hai fatto rifornimento da ${r.nome}?\nIl prezzo mostrato era $prezzo €/l: corrispondeva?',
          style: PienoText.valoreDettaglio,
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(rientroProvider.notifier).state = null; // più tardi
              Navigator.of(ctx).pop();
            },
            child: const Text('Più tardi'),
          ),
          TextButton(
            onPressed: () {
              // Prezzo diverso: registra una segnalazione al ritorno.
              aggiungiSegnalazione(
                ref,
                Segnalazione(
                  impiantoId: r.impiantoId,
                  nome: r.nome,
                  prezzoMostrato: r.prezzoMostrato,
                  prezzoVisto: null,
                  nota: 'Segnalato al ritorno: prezzo diverso',
                  quando: DateTime.now(),
                ),
              );
              ref.read(rientroProvider.notifier).state = null;
              Navigator.of(ctx).pop();
            },
            child: const Text('No, diverso'),
          ),
          TextButton(
            onPressed: () {
              ref.read(rientroProvider.notifier).state = null;
              Navigator.of(ctx).pop();
            },
            child: const Text('Sì, giusto'),
          ),
        ],
      ),
    );
  }
}
