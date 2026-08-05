// Spiegazione della posizione, PRIMA del dialogo di sistema (pag. 13, "permessi
// graduali"; Roadmap 02: "Permessi di posizione con la spiegazione prima del dialogo").
//
// Perché esiste: il dialogo di sistema si può accettare una volta sola. Se arriva senza
// contesto, chi non capisce perché serve dice di no — e da lì non si torna indietro se
// non dalle impostazioni del telefono. Qui si dice cosa succede e cosa NON succede,
// e solo dopo, se l'utente accetta, si apre il dialogo vero.
//
// «Non ora» non è un vicolo cieco: l'app funziona lo stesso, senza distanze, e la
// posizione resta attivabile dalle Impostazioni.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/app_state.dart';
import '../components/bottone_primario.dart';

/// Mostra la spiegazione e registra la scelta in [consensoPosizioneProvider].
/// Da chiamare solo quando il consenso non è ancora stato chiesto (valore null).
Future<void> mostraSpiegazionePosizione(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SpiegazionePosizione(),
  );
}

class _SpiegazionePosizione extends ConsumerWidget {
  const _SpiegazionePosizione();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void rispondi(bool consente) {
      ref.read(consensoPosizioneProvider.notifier).state = consente;
      Navigator.of(context).pop();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(PienoRadii.schedaPrincipale)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                gradient: PienoColors.gradienteMenta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.near_me_outlined, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            const Text('Dove sei, per dirti dove conviene', style: PienoText.titoloPagina),
            const SizedBox(height: 12),
            const Text(
              'Con la tua posizione Pieno calcola la distanza dai distributori e '
              'apre già sulla tua zona.',
              style: PienoText.valoreDettaglio,
            ),
            const SizedBox(height: 16),
            const _Punto(
              icona: Icons.phone_iphone,
              testo: 'Un solo rilevamento, all\'apertura. Resta sul telefono: '
                  'non viene inviato a nessun server.',
            ),
            const SizedBox(height: 10),
            const _Punto(
              icona: Icons.block_outlined,
              testo: 'Nessun tracciamento, nessuna pubblicità, nessun account richiesto.',
            ),
            const SizedBox(height: 10),
            const _Punto(
              icona: Icons.check_circle_outline,
              testo: 'Se preferisci di no, l\'app funziona lo stesso: vedrai i prezzi '
                  'senza le distanze.',
            ),
            const SizedBox(height: 22),
            BottonePrimario(
              testo: 'Usa la mia posizione',
              onTap: () => rispondi(true),
              altezza: PienoSizes.azionePrimariaMin,
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => rispondi(false),
                child: Text(
                  'Non ora',
                  style: PienoText.voceImpostazione.copyWith(color: PienoColors.grafite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icona, required this.testo});
  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icona, size: 18, color: PienoColors.mentaScura),
        const SizedBox(width: 10),
        Expanded(child: Text(testo, style: PienoText.valoreDettaglio)),
      ],
    );
  }
}
