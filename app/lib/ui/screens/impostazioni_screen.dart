// Schermata 4 — Impostazioni (pag. 8). Tappa 05.
// Schermata sovrapposta: si apre dai pulsanti impostazioni e si chiude tornando dove si era.
// Cinque gruppi in vetro (raggio 22), righe alte 50, occhiello in grafite.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/carburante.dart';
import '../../models/navigatore.dart';
import '../../state/app_state.dart';
import '../components/ordinamento_shortcut.dart';
import '../components/sfondo_aurore.dart';
import '../components/vetro.dart';
import 'accesso_screen.dart';
import 'segnala_sheet.dart';

class ImpostazioniScreen extends ConsumerWidget {
  const ImpostazioniScreen({super.key});

  static Route<void> rotta() =>
      MaterialPageRoute(builder: (_) => const ImpostazioniScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SfondoAurore(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PienoSpacing.margineScheda),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _intestazione(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 30),
                    children: [
                      _testataAccount(context),
                      _gruppoRifornimento(ref),
                      _gruppoRicerca(ref),
                      _gruppoNavigazione(context, ref),
                      _gruppoDati(context, ref),
                      const SizedBox(height: 10),
                      Text(
                        'Dati: Ministero delle Imprese e del Made in Italy — IODL 2.0.\n© OpenStreetMap contributors.',
                        style: PienoText.valoreDettaglio,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intestazione(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text('Impostazioni', style: PienoText.titoloPagina)),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: PienoColors.inchiostro),
            ),
          ],
        ),
      );

  // 1 — Testata account. Senza account: "Accedi per sincronizzare" (porta alla Schermata 1).
  Widget _testataAccount(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Vetro(
          radius: PienoRadii.gruppoImpostazioni,
          blur: PienoElevations.vetroBlurCampi,
          shadows: PienoElevations.gruppoImpostazioni,
          child: _Riga(
            altezza: PienoSizes.testataAccount,
            avatar: Container(
              width: PienoSizes.avatarAccount,
              height: PienoSizes.avatarAccount,
              decoration: const BoxDecoration(
                gradient: PienoColors.gradienteMenta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, color: Colors.white),
            ),
            titolo: 'Accedi per sincronizzare',
            sottotitolo: 'Preferiti e impostazioni su tutti i dispositivi',
            onTap: () => Navigator.of(context).push(AccessoScreen.rotta()),
          ),
        ),
      );

  // 2 — Rifornimento: carburante, capacità serbatoio (modalità = da definire).
  Widget _gruppoRifornimento(WidgetRef ref) {
    final carburante = ref.watch(carburanteProvider);
    final capacita = ref.watch(capacitaLitriProvider);
    return _Gruppo(
      titolo: 'RIFORNIMENTO',
      figli: [
        _Riga(
          titolo: 'Carburante',
          trailing: _SceltaChip<Carburante>(
            valori: Carburante.values,
            selezionato: carburante,
            etichetta: (c) => c.etichetta,
            onScelta: (c) => ref.read(carburanteProvider.notifier).state = c,
          ),
        ),
        _RigaSlider(
          titolo: 'Capacità serbatoio',
          valore: capacita.toDouble(),
          min: 30, max: 90, divisioni: 12,
          formato: (v) => '${v.round()} l',
          onChange: (v) => ref.read(capacitaLitriProvider.notifier).state = v.round(),
        ),
      ],
    );
  }

  // 3 — Ricerca: raggio, ordinamento, escludi dati più vecchi di.
  Widget _gruppoRicerca(WidgetRef ref) {
    final raggio = ref.watch(raggioKmProvider);
    final eta = ref.watch(etaMassimaGiorniProvider);
    return _Gruppo(
      titolo: 'RICERCA',
      figli: [
        _RigaSlider(
          titolo: 'Raggio',
          valore: raggio,
          min: 2, max: 30, divisioni: 28,
          formato: (v) => '${v.round()} km',
          onChange: (v) => ref.read(raggioKmProvider.notifier).state = v,
        ),
        const _Riga(
          titolo: 'Ordinamento',
          trailing: OrdinamentoShortcut(),
        ),
        _Riga(
          titolo: 'Escludi dati più vecchi di',
          trailing: _SceltaChip<int>(
            valori: const [2, 7, 30],
            selezionato: eta,
            etichetta: (g) => '$g giorni',
            onScelta: (g) => ref.read(etaMassimaGiorniProvider.notifier).state = g,
          ),
        ),
      ],
    );
  }

  // 4 — Mappa e navigazione: "Apri con", avvisi sul percorso.
  Widget _gruppoNavigazione(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigatoreProvider);
    final avvisi = ref.watch(avvisiPercorsoProvider);
    return _Gruppo(
      titolo: 'MAPPA E NAVIGAZIONE',
      figli: [
        _Riga(
          titolo: 'Apri con',
          valore: nav.etichetta,
          onTap: () => _scegliNavigatore(context, ref, nav),
        ),
        _Riga(
          titolo: 'Avvisi sul percorso',
          trailing: Switch(
            value: avvisi,
            activeColor: Colors.white,
            activeTrackColor: PienoColors.mentaScuraGrad,
            onChanged: (v) => ref.read(avvisiPercorsoProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  // 5 — Dati: segnala un prezzo errato, qualità dei dati, fonte.
  Widget _gruppoDati(BuildContext context, WidgetRef ref) => _Gruppo(
        titolo: 'DATI',
        figli: [
          _Riga(
            titolo: 'Segnala un prezzo errato',
            coloreTitolo: PienoColors.mentaScura,
            onTap: () {
              final elenco = ref.read(elencoProvider);
              final carburante = ref.read(carburanteProvider);
              if (elenco.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Apri un impianto per segnalarne il prezzo.')),
                );
                return;
              }
              final imp = elenco.first;
              mostraSegnala(context, imp, imp.prezzoDi(carburante)!.valore);
            },
          ),
          const _Riga(titolo: 'Fonte dei dati', valore: 'MIMIT · IODL 2.0'),
        ],
      );

  Future<void> _scegliNavigatore(BuildContext context, WidgetRef ref, Navigatore attuale) async {
    final scelto = await showModalBottomSheet<Navigatore>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in Navigatore.values)
              ListTile(
                title: Text(n.etichetta),
                trailing: n == attuale
                    ? const Icon(Icons.check, color: PienoColors.mentaScura)
                    : null,
                onTap: () => Navigator.of(context).pop(n),
              ),
          ],
        ),
      ),
    );
    if (scelto != null) ref.read(navigatoreProvider.notifier).state = scelto;
  }
}

// ---- Widget di supporto ----------------------------------------------------------

class _Gruppo extends StatelessWidget {
  const _Gruppo({required this.titolo, required this.figli});
  final String titolo;
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(titolo, style: PienoText.occhiello),
          ),
          Vetro(
            radius: PienoRadii.gruppoImpostazioni,
            blur: PienoElevations.vetroBlurCampi,
            shadows: PienoElevations.gruppoImpostazioni,
            child: Column(
              children: [
                for (var i = 0; i < figli.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: PienoSpacing.divisoriRientro),
                      child: Divider(height: 1, color: Color(0x14000000)),
                    ),
                  figli[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({
    required this.titolo,
    this.sottotitolo,
    this.valore,
    this.trailing,
    this.onTap,
    this.avatar,
    this.altezza = PienoSizes.rigaImpostazione,
    this.coloreTitolo = PienoColors.inchiostro,
  });

  final String titolo;
  final String? sottotitolo;
  final String? valore;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? avatar;
  final double altezza;
  final Color coloreTitolo;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: altezza),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (avatar != null) ...[avatar!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(titolo, style: PienoText.voceImpostazione.copyWith(color: coloreTitolo)),
                  if (sottotitolo != null)
                    Text(sottotitolo!, style: PienoText.valoreDettaglio),
                ],
              ),
            ),
            if (valore != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(valore!, style: PienoText.valoreDettaglio),
              ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null && valore != null)
              const Icon(Icons.chevron_right, color: PienoColors.grafite),
          ],
        ),
      ),
    );
  }
}

class _SceltaChip<T> extends StatelessWidget {
  const _SceltaChip({
    required this.valori,
    required this.selezionato,
    required this.etichetta,
    required this.onScelta,
  });

  final List<T> valori;
  final T selezionato;
  final String Function(T) etichetta;
  final ValueChanged<T> onScelta;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final v in valori)
          GestureDetector(
            onTap: () => onScelta(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: v == selezionato ? PienoColors.inchiostro : const Color(0x11000000),
                borderRadius: BorderRadius.circular(PienoRadii.pillola),
              ),
              child: Text(
                etichetta(v),
                style: PienoText.valoreDettaglio.copyWith(
                  color: v == selezionato ? Colors.white : PienoColors.inchiostro,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RigaSlider extends StatelessWidget {
  const _RigaSlider({
    required this.titolo,
    required this.valore,
    required this.min,
    required this.max,
    required this.divisioni,
    required this.formato,
    required this.onChange,
  });

  final String titolo;
  final double valore;
  final double min;
  final double max;
  final int divisioni;
  final String Function(double) formato;
  final ValueChanged<double> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(titolo, style: PienoText.voceImpostazione)),
          Expanded(
            flex: 5,
            child: Slider(
              value: valore.clamp(min, max),
              min: min,
              max: max,
              divisions: divisioni,
              activeColor: PienoColors.mentaScura,
              label: formato(valore),
              onChanged: onChange,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(formato(valore),
                textAlign: TextAlign.right, style: PienoText.valoreDettaglio),
          ),
        ],
      ),
    );
  }
}
