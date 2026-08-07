// Entry point (Roadmap 02 — "Progetto Flutter").
// L'app apre sulla schermata scheletro che mostra dati veri.
// L'interfaccia definitiva (Mappa di avvio, Vicino a te) arriva con le Tappe 03–04.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/tokens.dart';
import 'state/app_state.dart';
import 'ui/screens/caricamento_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/spiegazione_posizione.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const PienoApp(),
    ),
  );
}

class PienoApp extends StatelessWidget {
  const PienoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pieno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: PienoColors.fondo,
        fontFamily: 'Manrope',
        colorScheme: ColorScheme.fromSeed(
          seedColor: PienoColors.mentaChiara,
          surface: PienoColors.fondo,
        ),
        useMaterial3: true,
      ),
      home: const AvvioGate(),
    );
  }
}

/// Mostra la schermata di caricamento mentre l'app prepara posizione e dati, poi passa
/// all'app con una dissolvenza (easeInOut).
///
/// L'attesa minima e il lavoro corrono **in parallelo**: prima erano in fila, quindi
/// l'avvio costava l'attesa *più* il caricamento. L'obiettivo dichiarato è «< 1 s dal
/// tocco sull'icona al primo prezzo utile» (06-architettura.md): il minimo qui sotto è il
/// tempo in cui si vede l'animazione, non un ritardo aggiunto al resto.
class AvvioGate extends ConsumerStatefulWidget {
  const AvvioGate({super.key});

  @override
  ConsumerState<AvvioGate> createState() => _AvvioGateState();
}

class _AvvioGateState extends ConsumerState<AvvioGate> {
  /// Quanto si vede almeno la schermata di caricamento. Non allunga l'avvio: corre
  /// insieme al lavoro, quindi conta solo se il lavoro finisce prima.
  static const _minimoVisibile = Duration(milliseconds: 1500);

  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    ref.read(manifestProvider); // scalda subito l'elenco province
    WidgetsBinding.instance.addPostFrameCallback((_) => _avvia());
  }

  /// Sequenza d'avvio: permessi → posizione e dati reali → app, con l'animazione visibile
  /// per almeno [_minimoVisibile] — cronometro fatto partire subito, non dopo.
  Future<void> _avvia() async {
    final minimo = Future<void>.delayed(_minimoVisibile);

    // 1) Permessi: spiegazione dentro l'app e poi, se accetta, dialogo di sistema.
    //    Va prima dei dati, perché è il consenso a decidere la provincia da scaricare.
    if (ref.read(consensoPosizioneProvider) == null) {
      await mostraSpiegazionePosizione(context);
      if (!mounted) return;
    }

    // 2) Prepara i dati REALI mentre si vede ancora il caricamento.
    if (ref.read(consensoPosizioneProvider) == true) {
      // attende il fix di posizione (→ provincia giusta), con tetto di tempo.
      try {
        await ref.read(posizioneProvider.future).timeout(const Duration(seconds: 6));
      } catch (_) {/* niente posizione: si prosegue con la provincia di default */}
      if (!mounted) return;
    }
    try {
      await ref.read(datiProvinciaProvider.future).timeout(const Duration(seconds: 8));
    } catch (_) {/* offline/errore: l'app mostrerà lo stato adeguato */}
    if (!mounted) return;

    // 3) Pronto, ma non prima che l'animazione si sia vista: se il lavoro è finito in
    //    300 ms, qui si aspetta il resto del minimo; se ha impiegato di più, non si
    //    aspetta niente.
    await minimo;
    if (!mounted) return;
    setState(() => _pronto = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _pronto ? const HomeShell() : const CaricamentoScreen(),
    );
  }
}
