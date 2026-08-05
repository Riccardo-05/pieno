// Pastiglia risparmio (pag. 7): menta al 10%, testo menta scura. Dichiara sempre la
// base ("sul pieno" = 50 litri). Sotto 0,50 € sparisce (non mostra cifre irrilevanti).

import 'package:flutter/widgets.dart';
import '../../design/tokens.dart';
import '../../domain/risparmio.dart';

class PastigliaRisparmio extends StatelessWidget {
  const PastigliaRisparmio({super.key, required this.risparmioEuro});

  final double risparmioEuro;

  @override
  Widget build(BuildContext context) {
    if (!risparmioDaMostrare(risparmioEuro)) return const SizedBox.shrink();
    final testo = 'Risparmi ${risparmioEuro.toStringAsFixed(2).replaceAll('.', ',')} € sul pieno';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: PienoColors.mentaVelo,
        borderRadius: BorderRadius.circular(PienoRadii.pillola),
      ),
      child: Text(
        testo,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: PienoColors.mentaScura,
        ),
      ),
    );
  }
}
