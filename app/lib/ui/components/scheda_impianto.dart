// Scheda principale (pag. 7): vetro bianco 72%, raggio 36, margine laterale 18.
// Contiene sempre e solo: nome, via, distanza, prezzo, risparmio, azione.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/carburante.dart';
import '../../models/impianto.dart';
import 'bottone_primario.dart';
import 'pastiglia_risparmio.dart';
import 'prezzo_text.dart';
import 'stelle_valutazione.dart';
import 'vetro.dart';

class SchedaImpianto extends StatelessWidget {
  const SchedaImpianto({
    super.key,
    required this.impianto,
    required this.carburante,
    required this.risparmioEuro,
    required this.distanzaKm,
    required this.onPortamiQui,
    this.onSegnala,
    this.altezzaAzione = PienoSizes.azionePrimaria,
  });

  final Impianto impianto;
  final Carburante carburante;
  final double risparmioEuro;
  final double? distanzaKm;
  final VoidCallback onPortamiQui;
  final VoidCallback? onSegnala;
  final double altezzaAzione;

  @override
  Widget build(BuildContext context) {
    final prezzo = impianto.prezzoDi(carburante)!;
    final via = [impianto.indirizzo, impianto.comune].where((s) => s.isNotEmpty).join(' · ');
    final dist = distanzaKm == null
        ? null
        : 'a ${distanzaKm!.toStringAsFixed(1).replaceAll('.', ',')} km';

    return Vetro(
      radius: PienoRadii.schedaPrincipale,
      blur: PienoElevations.vetroBlurSchede,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(impianto.nome.isNotEmpty ? impianto.nome : impianto.marchio,
              style: PienoText.nomeImpianto, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(via, style: PienoText.valoreDettaglio, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (dist != null) ...[
            const SizedBox(height: 2),
            Text(dist, style: PienoText.valoreDettaglio),
          ],
          const SizedBox(height: 8),
          StelleValutazione(impiantoId: impianto.id),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, child: PrezzoText(prezzo.valore)),
          const SizedBox(height: 10),
          PastigliaRisparmio(risparmioEuro: risparmioEuro),
          const SizedBox(height: 16),
          BottonePrimario(testo: 'Portami qui', onTap: onPortamiQui, altezza: altezzaAzione),
          if (onSegnala != null)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onSegnala,
                child: Text('Segnala un prezzo errato',
                    style: PienoText.valoreDettaglio.copyWith(color: PienoColors.mentaScura)),
              ),
            ),
        ],
      ),
    );
  }
}
