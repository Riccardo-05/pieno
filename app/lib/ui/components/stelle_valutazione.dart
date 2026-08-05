// Valutazione a stelle (Tappa 08). "Prima esterne e poi interne": se esiste una
// valutazione esterna la si mostra (sola lettura); altrimenti si mostra quella interna
// dell'utente, toccabile per votare. Le esterne richiedono un'API (da collegare).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/app_state.dart';

class StelleValutazione extends ConsumerWidget {
  const StelleValutazione({
    super.key,
    required this.impiantoId,
    this.valutazioneEsterna, // media 0–5 da fonte esterna; null se non disponibile
    this.dimensione = 20,
  });

  final String impiantoId;
  final double? valutazioneEsterna;
  final double dimensione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Priorità alle esterne quando ci saranno; per ora sono sempre null.
    if (valutazioneEsterna != null) {
      return _StelleFisse(voto: valutazioneEsterna!, dimensione: dimensione, etichetta: 'Valutazioni');
    }
    final voto = ref.watch(valutazioniProvider)[impiantoId] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => valuta(ref, impiantoId, i == voto ? 0 : i), // ritoccando la stessa, azzera
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                i <= voto ? Icons.star_rounded : Icons.star_outline_rounded,
                size: dimensione,
                color: i <= voto ? PienoColors.mentaScura : PienoColors.grafite,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(voto == 0 ? 'La tua valutazione' : 'La tua valutazione',
            style: PienoText.valoreDettaglio),
      ],
    );
  }
}

class _StelleFisse extends StatelessWidget {
  const _StelleFisse({required this.voto, required this.dimensione, required this.etichetta});
  final double voto;
  final double dimensione;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            voto >= i
                ? Icons.star_rounded
                : (voto >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: dimensione,
            color: PienoColors.mentaScura,
          ),
        const SizedBox(width: 6),
        Text('${voto.toStringAsFixed(1)} · $etichetta', style: PienoText.valoreDettaglio),
      ],
    );
  }
}
