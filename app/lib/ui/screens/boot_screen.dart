// Schermata scheletro (Roadmap 02 — "senza interfaccia definitiva").
// Esito atteso della tappa: "l'app apre e mostra dati veri".
// Mostra: carburante selezionato, elenco impianti ordinati per prezzo, età del dato,
// e la sorgente (rete/cache). L'interfaccia definitiva arriva con le Tappe 03–04.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/carburante.dart';
import '../../models/impianto.dart';
import '../../state/app_state.dart';
import '../components/sfondo_aurore.dart';
import '../components/switch_pillola.dart';
import '../components/vetro.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carburante = ref.watch(carburanteProvider);
    final async = ref.watch(datiProvinciaProvider);

    return Scaffold(
      body: SfondoAurore(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PienoSpacing.margineScheda),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PIENO — SCHELETRO', style: PienoText.occhiello),
                const SizedBox(height: 6),
                Text('Vicino a te', style: PienoText.titoloPagina),
                const SizedBox(height: 14),
                _selettoreCarburante(ref, carburante),
                const SizedBox(height: 14),
                Expanded(
                  child: async.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Errore: $e')),
                    data: (esito) => _contenuto(esito, carburante),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selettoreCarburante(WidgetRef ref, Carburante attuale) {
    // Nello scheletro alterniamo i due carburanti più comuni; il selettore a 4 vie
    // arriva con le impostazioni (Tappa 05).
    final coppie = [Carburante.benzina, Carburante.gasolio];
    final idx = coppie.indexOf(attuale).clamp(0, 1);
    return SwitchPillola(
      opzioni: coppie.map((c) => c.etichetta).toList(),
      indiceSelezionato: idx,
      onCambia: (i) => ref.read(carburanteProvider.notifier).state = coppie[i],
    );
  }

  Widget _contenuto(EsitoDati esito, Carburante carburante) {
    final dati = esito.dati;
    if (dati == null) {
      return const Center(
        child: Text('Nessun dato disponibile.\nControlla la configurazione della sorgente.',
            textAlign: TextAlign.center),
      );
    }
    final impianti = ordinaPerPrezzo(dati.impianti, carburante);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rigaContesto(dati, esito.origineRete),
        const SizedBox(height: 10),
        Expanded(
          child: impianti.isEmpty
              ? const Center(child: Text('Nessun impianto con questo carburante.'))
              : ListView.separated(
                  itemCount: impianti.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _riga(impianti[i], carburante),
                ),
        ),
      ],
    );
  }

  // Onestà sul dato: luogo, provincia, età e sorgente sempre visibili (pag. 2, 7).
  Widget _rigaContesto(DatiProvincia dati, bool rete) {
    final eta = dati.eta;
    final etaTxt = eta == null
        ? 'età sconosciuta'
        : eta.inHours < 24
            ? 'aggiornato oggi'
            : 'dato di ${eta.inDays} giorni fa';
    final fonte = rete ? 'rete' : 'cache locale';
    return Text('Provincia ${dati.provincia} · $etaTxt · $fonte',
        style: PienoText.valoreDettaglio);
  }

  Widget _riga(Impianto imp, Carburante carburante) {
    final prezzo = imp.prezzoDi(carburante)!;
    return Vetro(
      radius: PienoRadii.gruppoImpostazioni,
      blur: PienoElevations.vetroBlurCampi,
      shadows: PienoElevations.gruppoImpostazioni,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(imp.nome, style: PienoText.nomeImpianto, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${imp.indirizzo} · ${imp.comune}', style: PienoText.valoreDettaglio,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Nello scheletro usiamo lo stile "prezzo in lista" via PrezzoText ridotto:
          // qui riusiamo il compositore mostrando il valore a tre decimali.
          Text(
            prezzo.valore.toStringAsFixed(3).replaceAll('.', ','),
            style: PienoText.prezzoLista,
          ),
        ],
      ),
    );
  }
}
