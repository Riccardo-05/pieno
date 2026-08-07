// Scheda principale (pag. 7): vetro bianco 72%, raggio 36, margine laterale 18.
// Contiene sempre e solo: nome, via, distanza, prezzo, risparmio, azione.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/orari.dart';
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
    // «in linea d'aria» non è pedanteria: la distanza è calcolata sulle coordinate, non
    // sulle strade, quindi diverge dai km che mostrerà il navigatore un istante dopo. Il
    // valore stradale arriverà solo con un servizio di percorsi (Fase 5).
    final dist = distanzaKm == null
        ? null
        : 'a ${distanzaKm!.toStringAsFixed(1).replaceAll('.', ',')} km in linea d\'aria';

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
          _BadgeApertura(orari: impianto.orari, servito: !prezzo.selfService),
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

// Riga di stato sotto l'indirizzo: apertura (da orari OSM) e modalità di erogazione.
//
// L'apertura non si mostra se l'orario manca o non è interpretabile (onestà sul dato).
// «Servito» compare solo quando il prezzo mostrato NON è self: succede dove l'impianto non
// ha un prezzo self per quel carburante — quasi sempre per GPL e metano, e in circa 900
// impianti per benzina e gasolio. Chi legge deve sapere che quel numero include il
// servizio, altrimenti il confronto con gli altri è tra cose diverse.
class _BadgeApertura extends StatelessWidget {
  const _BadgeApertura({required this.orari, this.servito = false});
  final String? orari;
  final bool servito;

  @override
  Widget build(BuildContext context) {
    final info = statoApertura(orari);
    final testo = etichettaApertura(orari);
    if (testo == null && !servito) return const SizedBox.shrink();
    final aperto = info.stato == StatoApertura.aperto;
    final colore = aperto ? PienoColors.mentaScura : PienoColors.rame;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (testo != null) ...[
            Icon(aperto ? Icons.schedule : Icons.schedule_outlined,
                size: 15, color: colore),
            const SizedBox(width: 5),
            Text(testo, style: PienoText.valoreDettaglio.copyWith(color: colore)),
          ],
          if (testo != null && servito)
            Text(' · ', style: PienoText.valoreDettaglio),
          if (servito)
            Text('Servito', style: PienoText.valoreDettaglio),
        ],
      ),
    );
  }
}
