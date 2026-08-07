// Switch a pillola in vetro con selettore in inchiostro (pag. 3, 5, 7).
// Due sole destinazioni; padding 5 px; transizione 200 ms. Usato da:
// "Mappa / Vicino a te" e "Accedi / Registrati" (stesso componente).

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'vetro.dart';

/// Altezza complessiva della pillola: cella + padding del vetro + il suo bordo da 1 px.
const double kAltezzaSwitchPillola = PienoSizes.targetMinimo + 2;

/// Distacco dello switch flottante dal bordo inferiore, oltre la safe area. È lo stesso
/// in tutte le viste: lo switch non è navigazione (pag. 3) e non deve spostarsi a seconda
/// di ciò che ha sotto.
const double kMargineSwitchFlottante = 16;

/// Spazio da riservare in coda a un contenuto scorrevole perché la sua ultima riga non
/// finisca sotto lo switch. Va sommato alla safe area inferiore.
const double kSpazioSwitchFlottante =
    kAltezzaSwitchPillola + kMargineSwitchFlottante + 12;

class SwitchPillola extends StatelessWidget {
  const SwitchPillola({
    super.key,
    required this.opzioni, // esattamente 2 etichette
    required this.indiceSelezionato,
    required this.onCambia,
  }) : assert(opzioni.length == 2, 'Lo switch ha due sole destinazioni');

  final List<String> opzioni;
  final int indiceSelezionato;
  final ValueChanged<int> onCambia;

  @override
  Widget build(BuildContext context) {
    return Vetro(
      radius: PienoRadii.pillola,
      blur: PienoElevations.vetroBlurCampi,
      shadows: PienoElevations.pillola,
      padding: const EdgeInsets.all(PienoSpacing.paddingPillola),
      child: LayoutBuilder(
        builder: (context, c) {
          final larghezzaCella = c.maxWidth / 2;
          return SizedBox(
            height: PienoSizes.targetMinimo - PienoSpacing.paddingPillola * 2,
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment:
                      indiceSelezionato == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: larghezzaCella,
                    decoration: BoxDecoration(
                      color: PienoColors.inchiostro,
                      borderRadius: BorderRadius.circular(PienoRadii.pillola),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onCambia(i);
                          },
                          child: Center(
                            child: Text(
                              opzioni[i],
                              style: PienoText.voceImpostazione.copyWith(
                                color: i == indiceSelezionato
                                    ? const Color(0xFFFFFFFF)
                                    : PienoColors.inchiostro,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
