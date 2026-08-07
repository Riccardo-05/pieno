// Schermata 4 — Impostazioni (pag. 8). Tappa 05.
// Schermata sovrapposta: si apre dai pulsanti impostazioni e si chiude tornando dove si era.
// Cinque gruppi in vetro (raggio 22), righe alte 50, occhiello in grafite.

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_store.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../models/navigatore.dart';
import '../../state/app_state.dart';
import '../components/carburante_selettore.dart';
import '../components/dissolvenza.dart';
import '../components/ordinamento_shortcut.dart';
import '../components/sfondo_aurore.dart';
import '../components/vetro.dart';
import 'accesso_screen.dart';
import 'segnala_sheet.dart';

class ImpostazioniScreen extends ConsumerWidget {
  const ImpostazioniScreen({super.key});

  // CupertinoPageRoute: transizione iOS con back-swipe dal bordo per tornare indietro.
  static Route<void> rotta() =>
      CupertinoPageRoute(builder: (_) => const ImpostazioniScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SfondoAurore(
        // bottom: false — con la safe area inferiore attiva il riquadro scorrevole finisce
        // sopra l'indicatore di sistema, e l'ultimo gruppo risulta tagliato invece di
        // scorrere fino al bordo. Lo spazio va restituito come padding DENTRO la lista:
        // così il contenuto arriva in fondo allo schermo e a riposo resta comunque sopra
        // l'indicatore.
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PienoSpacing.margineScheda),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _intestazione(context),
                Expanded(
                  // Sfuma ai due bordi invece di tagliare: in testa i gruppi scivolano
                  // sotto il titolo, in coda sotto l'indicatore di sistema.
                  child: Dissolvenza(
                    alto: 12,
                    basso: MediaQuery.of(context).padding.bottom + 12,
                    child: ListView(
                    padding: EdgeInsets.only(
                        bottom: 30 + MediaQuery.of(context).padding.bottom),
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
    final capacita = ref.watch(capacitaLitriProvider);
    return _Gruppo(
      titolo: 'RIFORNIMENTO',
      figli: [
        const _Riga(
          titolo: 'Carburante',
          trailing: CarburanteSelettore(),
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

  // 5 — Dati: segnalazione, fonte, ultimo aggiornamento, permessi, dati locali (pag. 8).
  Widget _gruppoDati(BuildContext context, WidgetRef ref) {
    final carburante = ref.watch(carburanteProvider);
    final elenco = ref.watch(elencoProvider);
    final selId = ref.watch(selezionatoProvider);
    // Quale impianto si segnala: quello selezionato; in mancanza, il primo dell'elenco
    // (il più conveniente, quello mostrato in cima). Il nome è scritto nella riga, così
    // non si segnala mai un impianto a caso senza saperlo.
    final imp = elenco.isEmpty
        ? null
        : elenco.firstWhere((i) => i.id == selId, orElse: () => elenco.first);

    return _Gruppo(
      titolo: 'DATI',
      figli: [
        _Riga(
          titolo: 'Segnala un prezzo errato',
          sottotitolo: imp == null
              ? null
              : (imp.nome.isNotEmpty ? imp.nome : imp.marchio),
          coloreTitolo: PienoColors.mentaScura,
          onTap: () {
            if (imp == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Apri un impianto per segnalarne il prezzo.')),
              );
              return;
            }
            mostraSegnala(context, imp, imp.prezzoDi(carburante)!.valore);
          },
        ),
        const _Riga(titolo: 'Fonte dei dati', valore: 'MIMIT · IODL 2.0'),
        _Riga(titolo: 'Ultimo aggiornamento', valore: _ultimoAggiornamento(ref)),
        const _RigaPosizione(),
        _Riga(
          titolo: 'Cancella i dati salvati',
          coloreTitolo: PienoColors.rame,
          onTap: () => _cancellaDatiLocali(context, ref),
        ),
      ],
    );
  }

  /// Data del file ministeriale attualmente in uso. "Onestà sul dato": l'età è sempre
  /// dichiarata, anche qui, non solo nella riga di contesto di Vicino a te.
  String _ultimoAggiornamento(WidgetRef ref) {
    final quando = ref.watch(datiProvinciaProvider).valueOrNull?.dati?.datoDel;
    if (quando == null) return 'non disponibile';
    String due(int n) => n.toString().padLeft(2, '0');
    return '${due(quando.day)}/${due(quando.month)}/${quando.year}'
        ', ore ${due(quando.hour)}:${due(quando.minute)}';
  }

  /// Cancella zone salvate, preferenze, segnalazioni e valutazioni: quanto promesso
  /// dall'informativa privacy, senza dover disinstallare l'app.
  Future<void> _cancellaDatiLocali(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancellare i dati salvati?'),
        content: Text(
          'Vengono rimossi dal telefono le zone scaricate, le preferenze, le '
          'segnalazioni in attesa e le tue valutazioni. I prezzi si riscaricano da soli.',
          style: PienoText.valoreDettaglio,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancella', style: TextStyle(color: PienoColors.rame)),
          ),
        ],
      ),
    );
    if (conferma != true) return;

    await LocalStore().svuota();
    await ref.read(prefsProvider).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dati cancellati. Riavvia l\'app per ripartire da zero.')),
    );
  }

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

/// Riga «Posizione»: mostra lo stato del consenso e permette di cambiare idea.
/// Chi ha risposto «Non ora» alla spiegazione deve poter riattivare la posizione da
/// qui, senza reinstallare l'app; chi l'ha concessa deve poterla revocare.
class _RigaPosizione extends ConsumerWidget {
  const _RigaPosizione();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consenso = ref.watch(consensoPosizioneProvider);
    return _Riga(
      titolo: 'Posizione',
      sottotitolo: consenso == true
          ? 'Un solo rilevamento, solo sul telefono'
          : 'Senza posizione non vedi le distanze',
      trailing: Switch(
        value: consenso == true,
        activeColor: Colors.white,
        activeTrackColor: PienoColors.mentaScuraGrad,
        onChanged: (v) => ref.read(consensoPosizioneProvider.notifier).state = v,
      ),
    );
  }
}

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

class _RigaSlider extends StatefulWidget {
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
  State<_RigaSlider> createState() => _RigaSliderState();
}

class _RigaSliderState extends State<_RigaSlider> {
  // Valore mostrato durante il trascinamento: il provider viene aggiornato solo a
  // fine gesto (onChangeEnd), così filtra+ordina non gira a ogni tick (fluidità, L3).
  double? _trascinamento;

  @override
  Widget build(BuildContext context) {
    final v = (_trascinamento ?? widget.valore).clamp(widget.min, widget.max);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(widget.titolo, style: PienoText.voceImpostazione)),
          Expanded(
            flex: 5,
            child: Slider(
              value: v,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisioni,
              activeColor: PienoColors.mentaScura,
              label: widget.formato(v),
              onChanged: (nuovo) => setState(() => _trascinamento = nuovo),
              onChangeEnd: (nuovo) {
                setState(() => _trascinamento = null);
                widget.onChange(nuovo);
              },
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(widget.formato(v),
                textAlign: TextAlign.right, style: PienoText.valoreDettaglio),
          ),
        ],
      ),
    );
  }
}
