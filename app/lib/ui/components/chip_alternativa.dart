// Chip alternativa (pag. 7): vetro 50%, raggio 24. Prezzo a destra in Sora 400;
// rame solo se il prezzo è sopra la media di zona.
//
// Toccandolo si seleziona l'impianto: la selezione è condivisa con la Mappa (pag. 3,
// "un solo stato, due rappresentazioni"), che lo troverà già scelto e centrato. Il chip
// selezionato si segnala come la riga selezionata nel foglio della mappa — una superficie
// più densa e il nome in grassetto, mai una linea dura (pag. 2).

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/carburante.dart';
import '../../models/impianto.dart';
import '../../domain/formato.dart';
import '../../domain/risparmio.dart';
import 'vetro.dart';

class ChipAlternativa extends StatelessWidget {
  const ChipAlternativa({
    super.key,
    required this.impianto,
    required this.carburante,
    required this.media,
    this.onTap,
    this.selezionato = false,
  });

  final Impianto impianto;
  final Carburante carburante;
  final double? media;

  /// Tocco sul chip: seleziona l'impianto (selezione condivisa con la Mappa).
  final VoidCallback? onTap;

  /// Questo impianto è quello selezionato, qui o sulla Mappa.
  final bool selezionato;

  @override
  Widget build(BuildContext context) {
    final prezzo = impianto.prezzoDi(carburante)!;
    final rame = sopraLaMedia(impianto, carburante, media);
    final chip = Vetro(
      radius: PienoRadii.chipAlternativa,
      blur: PienoElevations.vetroBlurCampi,
      shadows: PienoElevations.gruppoImpostazioni,
      // Selezionato: stessa velatura d'inchiostro della riga attiva nel foglio mappa,
      // stesa sul vetro pieno invece che sul 50%, così il chip si fa più denso.
      fill: selezionato ? _vetroSelezionato : PienoColors.vetro50,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              impianto.nome.isNotEmpty ? impianto.nome : impianto.marchio,
              style: selezionato
                  ? PienoText.voceImpostazione.copyWith(fontWeight: FontWeight.w700)
                  : PienoText.voceImpostazione,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formattaPrezzo(prezzo.valore),
            style: PienoText.prezzoLista.copyWith(
              color: rame ? PienoColors.rame : PienoColors.inchiostro,
            ),
          ),
        ],
      ),
    );

    // Un'unica etichetta al posto di «nome» + «1,899» letti come glifi separati.
    final nome = impianto.nome.isNotEmpty ? impianto.nome : impianto.marchio;
    final etichetta = '$nome, ${prezzoParlato(prezzo.valore)}'
        '${rame ? ', sopra la media di zona' : ''}';

    if (onTap == null) {
      return Semantics(label: etichetta, excludeSemantics: true, child: chip);
    }
    return Semantics(
      label: etichetta,
      button: true,
      selected: selezionato,
      hint: 'apre questo impianto sulla mappa',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: chip,
      ),
    );
  }
}

/// Velatura d'inchiostro al 10% sul vetro pieno: è la resa opaca della stessa superficie
/// usata per la riga selezionata nel foglio della mappa, così la selezione ha un solo
/// aspetto in tutte e due le viste.
final Color _vetroSelezionato = Color.alphaBlend(
  PienoColors.inchiostro.withValues(alpha: 0.10),
  PienoColors.vetro,
);
