// Foglio "Segnala un prezzo errato" (pag. 8, Tappa 06). Raccoglie il prezzo visto e
// una nota; salva localmente. È un'azione, non un valore (testo in menta scura).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/formato.dart';
import '../../models/impianto.dart';
import '../../models/segnalazione.dart';
import '../../state/app_state.dart';
import '../components/bottone_primario.dart';

Future<void> mostraSegnala(BuildContext context, Impianto imp, double prezzoMostrato) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SegnalaForm(impianto: imp, prezzoMostrato: prezzoMostrato),
  );
}

class _SegnalaForm extends ConsumerStatefulWidget {
  const _SegnalaForm({required this.impianto, required this.prezzoMostrato});
  final Impianto impianto;
  final double prezzoMostrato;

  @override
  ConsumerState<_SegnalaForm> createState() => _SegnalaFormState();
}

class _SegnalaFormState extends ConsumerState<_SegnalaForm> {
  final _prezzo = TextEditingController();
  final _nota = TextEditingController();

  @override
  void dispose() {
    _prezzo.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _invia() {
    final visto = double.tryParse(_prezzo.text.trim().replaceAll(',', '.'));
    aggiungiSegnalazione(
      ref,
      Segnalazione(
        impiantoId: widget.impianto.id,
        nome: widget.impianto.nome,
        prezzoMostrato: widget.prezzoMostrato,
        prezzoVisto: visto,
        nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
        quando: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grazie: segnalazione salvata sul dispositivo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PienoColors.foglio,
          borderRadius: BorderRadius.vertical(top: Radius.circular(PienoRadii.schedaPrincipale)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SEGNALA UN PREZZO ERRATO', style: PienoText.occhiello),
            const SizedBox(height: 8),
            Text(widget.impianto.nome, style: PienoText.nomeImpianto),
            Text(
              'Prezzo mostrato: ${formattaPrezzo(widget.prezzoMostrato)} €/l',
              style: PienoText.valoreDettaglio,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prezzo,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: _dec('Prezzo visto (€/l)', 'es. 1,879'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nota,
              decoration: _dec('Nota (facoltativa)', 'es. cartello diverso dall\'app'),
            ),
            const SizedBox(height: 18),
            BottonePrimario(testo: 'Invia segnalazione', onTap: _invia, altezza: 56),
            const SizedBox(height: 8),
            Text(
              'La segnalazione resta sul dispositivo e verrà inviata quando il servizio dati sarà attivo.',
              style: PienoText.valoreDettaglio,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xCCFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
