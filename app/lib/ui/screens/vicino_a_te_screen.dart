// Schermata 3 — Vicino a te (pag. 7). Roadmap 03.
// Riga di contesto, scheda del più conveniente con risparmio, tre alternative,
// «Portami qui», stati "senza risultati" e "senza connessione".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/location_service.dart';
import '../../data/navigator_launcher.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/geo.dart';
import '../../domain/risparmio.dart';
import '../../models/carburante.dart';
import '../../models/impianto.dart';
import '../../state/app_state.dart';
import '../components/carburante_pillola.dart';
import '../components/chip_alternativa.dart';
import '../components/ordinamento_shortcut.dart';
import '../components/pulsante_tondo.dart';
import '../../models/navigatore.dart';
import '../../models/segnalazione.dart';
import '../components/scheda_impianto.dart';
import '../components/sfondo_aurore.dart';
import 'impostazioni_screen.dart';
import 'segnala_sheet.dart';

class VicinoATeScreen extends ConsumerWidget {
  const VicinoATeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carburante = ref.watch(carburanteProvider);
    final async = ref.watch(datiProvinciaProvider);
    final pos = ref.watch(posizioneProvider).valueOrNull;
    final elenco = ref.watch(elencoProvider);
    final capacita = ref.watch(capacitaLitriProvider);
    final nav = ref.watch(navigatoreProvider);

    return Scaffold(
      body: SfondoAurore(
        child: SafeArea(
          child: Padding(
            // Margini 22 px (schermata a scheda).
            padding: const EdgeInsets.fromLTRB(
                PienoSpacing.margineScheda, PienoSpacing.margineScheda,
                PienoSpacing.margineScheda, 0),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _statoSenzaConnessione(),
              data: (esito) => _contenuto(context, ref, esito, carburante, pos, elenco, capacita, nav),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenuto(BuildContext context, WidgetRef ref, EsitoDati esito,
      Carburante carburante, Posizione? pos, List<Impianto> elenco, int capacita, Navigatore nav) {
    final dati = esito.dati;
    if (dati == null) return _statoSenzaConnessione();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rigaContesto(context, ref, dati, esito.origineRete, carburante),
        const SizedBox(height: 12),
        const Align(alignment: Alignment.centerLeft, child: OrdinamentoShortcut()),
        const SizedBox(height: 12),
        if (!esito.origineRete) _bannerOffline(dati),
        Expanded(
          child: elenco.isEmpty
              ? _statoSenzaRisultati(carburante)
              : _elenco(context, ref, elenco, carburante, pos, nav, capacita),
        ),
      ],
    );
  }

  // Riga di contesto: luogo e data a sinistra; pillola carburante + impostazioni a destra.
  Widget _rigaContesto(BuildContext context, WidgetRef ref, DatiProvincia dati,
      bool rete, Carburante carburante) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provincia ${dati.provincia}', style: PienoText.titoloPagina),
              Text(_etaTesto(dati), style: PienoText.valoreDettaglio),
            ],
          ),
        ),
        CarburantePillola(
          carburante: carburante,
          onTap: () {
            final valori = Carburante.values;
            final prossimo = valori[(carburante.index + 1) % valori.length];
            ref.read(carburanteProvider.notifier).state = prossimo;
          },
        ),
        const SizedBox(width: 10),
        PulsanteTondo(
          diametro: PienoSizes.pulsanteTondoElenco,
          icona: const Icon(Icons.tune, size: 20, color: PienoColors.inchiostro),
          onTap: () => Navigator.of(context).push(ImpostazioniScreen.rotta()),
        ),
      ],
    );
  }

  Widget _elenco(BuildContext context, WidgetRef ref, List<Impianto> ordinati, Carburante c,
      Posizione? pos, Navigatore nav, int capacita) {
    final media = mediaZona(ordinati, c);
    final migliore = ordinati.first;
    final prezzoMigliore = migliore.prezzoDi(c)!.valore;
    final risparmio =
        media == null ? 0.0 : risparmioSulPieno(prezzoMigliore, media, litri: capacita);

    // Massimo tre alternative sotto la scheda principale (regola da non violare).
    final alternative = ordinati.skip(1).take(3).toList();

    return ListView(
      children: [
        SchedaImpianto(
          impianto: migliore,
          carburante: c,
          risparmioEuro: risparmio,
          distanzaKm: _dist(migliore, pos),
          onPortamiQui: () {
            _segnaRientro(ref, migliore, prezzoMigliore);
            _portamiQui(context, migliore, nav);
          },
          onSegnala: () => mostraSegnala(context, migliore, prezzoMigliore),
        ),
        if (alternative.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('ALTERNATIVE', style: PienoText.occhiello),
          const SizedBox(height: 10),
          for (final a in alternative) ...[
            ChipAlternativa(impianto: a, carburante: c, media: media),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 90), // spazio per lo switch flottante
      ],
    );
  }

  double? _dist(Impianto i, Posizione? pos) {
    if (pos == null || i.lat == null || i.lon == null) return null;
    return distanzaKm(pos.lat, pos.lon, i.lat!, i.lon!);
  }

  // Prepara il "ritorno dopo il rifornimento": al prossimo avvio chiederà conferma.
  void _segnaRientro(WidgetRef ref, Impianto i, double prezzo) {
    ref.read(rientroProvider.notifier).state = Rientro(
      impiantoId: i.id,
      nome: i.nome,
      prezzoMostrato: prezzo,
      quando: DateTime.now(),
    );
  }

  Future<void> _portamiQui(BuildContext context, Impianto i, Navigatore nav) async {
    if (i.lat == null || i.lon == null) return;
    final ok = await portamiQui(i.lat!, i.lon!, navigatore: nav);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il navigatore.')),
      );
    }
  }

  String _etaTesto(DatiProvincia dati) {
    final eta = dati.eta;
    if (eta == null) return 'età del dato sconosciuta';
    if (eta.inHours < 24) return 'aggiornato oggi';
    return 'dato di ${eta.inDays} giorni fa';
  }

  Widget _bannerOffline(DatiProvincia dati) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Senza connessione: ultimo dato salvato · ${_etaTesto(dati)}',
            style: PienoText.valoreDettaglio.copyWith(color: PienoColors.rame)),
      );

  Widget _statoSenzaRisultati(Carburante c) => Center(
        child: Text(
            'Nessun impianto con ${c.etichetta} entro il raggio.\nAllarga il raggio o cambia carburante nelle impostazioni.',
            textAlign: TextAlign.center, style: PienoText.valoreDettaglio),
      );

  Widget _statoSenzaConnessione() => Center(
        child: Text('Senza connessione e nessun dato salvato.\nRiprova quando sei online.',
            textAlign: TextAlign.center, style: PienoText.valoreDettaglio),
      );
}
