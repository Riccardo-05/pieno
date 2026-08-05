// Chip alternativa (pag. 7): vetro 50%, raggio 24. Prezzo a destra in Sora 400;
// rame solo se il prezzo è sopra la media di zona.

import 'package:flutter/widgets.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/carburante.dart';
import '../../models/impianto.dart';
import '../../domain/risparmio.dart';
import 'vetro.dart';

class ChipAlternativa extends StatelessWidget {
  const ChipAlternativa({
    super.key,
    required this.impianto,
    required this.carburante,
    required this.media,
  });

  final Impianto impianto;
  final Carburante carburante;
  final double? media;

  @override
  Widget build(BuildContext context) {
    final prezzo = impianto.prezzoDi(carburante)!;
    final rame = sopraLaMedia(impianto, carburante, media);
    return Vetro(
      radius: PienoRadii.chipAlternativa,
      blur: PienoElevations.vetroBlurCampi,
      shadows: PienoElevations.gruppoImpostazioni,
      fill: const Color(0x80FFFFFF), // bianco 50%
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              impianto.nome.isNotEmpty ? impianto.nome : impianto.marchio,
              style: PienoText.voceImpostazione,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            prezzo.valore.toStringAsFixed(3).replaceAll('.', ','),
            style: PienoText.prezzoLista.copyWith(
              color: rame ? PienoColors.rame : PienoColors.inchiostro,
            ),
          ),
        ],
      ),
    );
  }
}
