// Schermata 1 — Accesso e registrazione (pag. 5). Tappa 05.
// L'account non è mai obbligatorio: "Entra senza account" è sempre presente.
// Nessun backend di autenticazione: i pulsanti di accesso sono predisposti ma non
// collegati (la sincronizzazione arriva più avanti). Non si finge un login.

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../components/bottone_primario.dart';
import '../components/dissolvenza.dart';
import '../components/sfondo_aurore.dart';
import '../components/switch_pillola.dart';
import '../components/vetro.dart';

class AccessoScreen extends StatefulWidget {
  const AccessoScreen({super.key});

  // CupertinoPageRoute: transizione iOS con back-swipe dal bordo per tornare indietro.
  static Route<void> rotta() => CupertinoPageRoute(builder: (_) => const AccessoScreen());

  @override
  State<AccessoScreen> createState() => _AccessoScreenState();
}

class _AccessoScreenState extends State<AccessoScreen> {
  bool _registrati = false;
  bool _consenso = false;

  void _nonCollegato(String cosa) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$cosa: in arrivo (sincronizzazione, dopo la Tappa 05)')),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SfondoAurore(
        // bottom: false — con la safe area inferiore attiva la scheda dei campi finisce
        // sopra l'indicatore di sistema e appare tagliata. Lo spazio torna come padding
        // dentro lo scorrevole, e l'ultimo tratto sfuma invece di troncarsi.
        child: SafeArea(
          bottom: false,
          child: Dissolvenza(
            basso: MediaQuery.of(context).padding.bottom + 12,
            child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                PienoSpacing.margineScheda,
                PienoSpacing.margineScheda,
                PienoSpacing.margineScheda,
                PienoSpacing.margineScheda + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: PienoColors.inchiostro),
                  ),
                ),
                _marchio(),
                const SizedBox(height: 22),
                SwitchPillola(
                  opzioni: const ['Accedi', 'Registrati'],
                  indiceSelezionato: _registrati ? 1 : 0,
                  onCambia: (i) => setState(() => _registrati = i == 1),
                ),
                const SizedBox(height: 16),
                _schedaCampi(),
                const SizedBox(height: 16),
                BottonePrimario(
                  testo: _registrati ? 'Crea account' : 'Entra',
                  onTap: () => _nonCollegato(_registrati ? 'Registrazione' : 'Accesso'),
                ),
                const SizedBox(height: 20),
                _accessiEsterni(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Entra senza account',
                      style: PienoText.voceImpostazione.copyWith(color: PienoColors.mentaScura)),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  // 1 — Marchio e promessa.
  Widget _marchio() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icons/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Pieno',
                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 26)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Prezzi dei carburanti in Italia dai dati aperti del Ministero. Trova dove conviene e quanto risparmi.',
            style: PienoText.valoreDettaglio,
          ),
        ],
      );

  // 3/4 — Scheda campi. Con "Registrati": email, password, conferma + consenso privacy.
  Widget _schedaCampi() => Vetro(
        radius: PienoRadii.schedaCampi,
        blur: PienoElevations.vetroBlurCampi,
        shadows: PienoElevations.gruppoImpostazioni,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _Campo(etichetta: 'Email', hint: 'nome@esempio.it'),
            const SizedBox(height: 12),
            const _Campo(etichetta: 'Password', hint: '••••••••', nascosto: true),
            if (_registrati) ...[
              const SizedBox(height: 12),
              const _Campo(etichetta: 'Conferma password', hint: '••••••••', nascosto: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: _consenso,
                    activeColor: Colors.white,
                    activeTrackColor: PienoColors.mentaScuraGrad,
                    onChanged: (v) => setState(() => _consenso = v),
                  ),
                  Expanded(
                    child: Text('Accetto l\'informativa sulla privacy',
                        style: PienoText.valoreDettaglio),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  // 5 — Accessi esterni, alla pari, alti 54.
  Widget _accessiEsterni() => Column(
        children: [
          _BottoneEsterno(
            icona: Icons.apple,
            testo: 'Continua con Apple',
            onTap: () => _nonCollegato('Accesso con Apple'),
          ),
          const SizedBox(height: 10),
          _BottoneEsterno(
            icona: Icons.g_mobiledata,
            testo: 'Continua con Google',
            onTap: () => _nonCollegato('Accesso con Google'),
          ),
        ],
      );
}

class _Campo extends StatelessWidget {
  const _Campo({required this.etichetta, required this.hint, this.nascosto = false});
  final String etichetta;
  final String hint;
  final bool nascosto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etichetta, style: PienoText.occhiello),
        const SizedBox(height: 6),
        SizedBox(
          height: PienoSizes.campoTesto, // 56
          child: TextField(
            obscureText: nascosto,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xCCFFFFFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottoneEsterno extends StatelessWidget {
  const _BottoneEsterno({required this.icona, required this.testo, required this.onTap});
  final IconData icona;
  final String testo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: PienoSizes.accessiEsterni, // 54
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, color: PienoColors.inchiostro),
            const SizedBox(width: 8),
            Text(testo, style: PienoText.voceImpostazione),
          ],
        ),
      ),
    );
  }
}
