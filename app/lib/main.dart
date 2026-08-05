// Entry point (Roadmap 02 — "Progetto Flutter").
// L'app apre sulla schermata scheletro che mostra dati veri.
// L'interfaccia definitiva (Mappa di avvio, Vicino a te) arriva con le Tappe 03–04.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/tokens.dart';
import 'state/app_state.dart';
import 'ui/screens/home_shell.dart';

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
      home: const HomeShell(),
    );
  }
}
