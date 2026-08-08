// Dissolvenza ai bordi di un contenuto scorrevole.
//
// Serve dove il contenuto passa sotto qualcosa di fisso — lo switch flottante, la maniglia
// del foglio, il bordo dello schermo — e senza di essa verrebbe tranciato di netto.
//
// Sfuma il CONTENUTO verso la trasparenza (maschera in `dstIn`), non stende un velo del
// colore di fondo: sotto le schermate c'è lo sfondo con le due aurore, e un velo pieno le
// spegnerebbe. Così lo sfondo resta quello che è e a sparire è solo ciò che scorre.
//
// **Sfuma solo dove c'è davvero qualcosa da nascondere.** [alto] e [basso] sono il massimo,
// non una costante: la sfumatura cresce col contenuto fuori campo da quel lato e vale zero
// quando non ce n'è. Una maschera incondizionata sbiadisce il primo elemento della lista a
// riposo — la card d'accesso delle Impostazioni sembrava tagliata dalla safe area, mentre
// era la maschera che lavorava a vuoto.
//
// A cambiare è il GRADIENTE, mai la struttura: il `ShaderMask` resta sempre al suo posto e
// diventa tutto opaco quando non c'è niente da sfumare. Inserirlo e toglierlo a seconda
// dello scorrimento cambierebbe il tipo di widget sopra la lista, e Flutter butterebbe
// l'intero sottoalbero ricreandolo: la lista perderebbe la posizione ogni volta che la
// sfumatura compare, oscillando. Era il primo tentativo, e i test l'hanno colto.
//
// Le altezze sono in pixel logici e vanno fatte combaciare con l'ingombro dell'elemento
// fisso, così il contenuto svanisce esattamente nella fascia che quell'elemento occupa.

import 'package:flutter/widgets.dart';

const Color _tieni = Color(0xFF000000); // opaco nella maschera = pixel conservato
const Color _togli = Color(0x00000000); // trasparente = pixel cancellato

class Dissolvenza extends StatefulWidget {
  const Dissolvenza({
    super.key,
    required this.child,
    this.alto = 0,
    this.basso = 0,
  });

  final Widget child;

  /// Altezza **massima** della sfumatura in testa. Vale 0 finché la lista è in cima.
  final double alto;

  /// Altezza **massima** della sfumatura in coda. Vale 0 quando la lista è in fondo.
  final double basso;

  @override
  State<Dissolvenza> createState() => _DissolvenzaState();
}

class _DissolvenzaState extends State<Dissolvenza> {
  // Quanto sfumare adesso, in pixel. In un notifier e non nello State: lo scorrimento
  // emette notifiche a ogni frame, e ricostruire tutta la lista a ogni frame sarebbe un
  // prezzo assurdo per un gradiente. Così si ridisegna solo la maschera.
  final _alto = ValueNotifier<double>(0);
  late final _basso = ValueNotifier<double>(widget.basso);

  @override
  void dispose() {
    _alto.dispose();
    _basso.dispose();
    super.dispose();
  }

  // `extentBefore`/`extentAfter` sono i pixel di contenuto fuori campo sopra e sotto: sono
  // esattamente «quanto c'è da nascondere». Sotto la soglia massima la sfumatura si
  // accorcia da sé, così primo e ultimo elemento non sbiadiscono quando non serve.
  bool _aggiorna(ScrollMetrics m) {
    if (m.axis != Axis.vertical) return false;
    _alto.value = m.extentBefore.clamp(0.0, widget.alto);
    _basso.value = m.extentAfter.clamp(0.0, widget.basso);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alto <= 0 && widget.basso <= 0) return widget.child;
    // Due ascoltatori: ScrollNotification durante il gesto, ScrollMetricsNotification
    // quando cambiano le misure senza che nessuno scorra — contenuto che cresce, foglio
    // che si alza, tastiera che compare. Senza il secondo, una lista più corta della
    // finestra resterebbe con la sfumatura iniziale addosso per sempre.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _aggiorna(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _aggiorna(n.metrics),
        child: ValueListenableBuilder<double>(
          valueListenable: _alto,
          builder: (context, alto, _) => ValueListenableBuilder<double>(
            valueListenable: _basso,
            builder: (context, basso, _) => ShaderMask(
              shaderCallback: (rect) =>
                  gradienteDissolvenza(alto: alto, basso: basso, altezza: rect.height)
                      .createShader(rect),
              blendMode: BlendMode.dstIn,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradiente della maschera: opaco dove il contenuto si conserva, trasparente dove svanisce.
/// Funzione pura, così il comportamento si verifica senza far scorrere niente.
///
/// Con [alto] o [basso] a zero l'estremo corrispondente resta **opaco**: nessuna sfumatura,
/// nessun bordo sbiadito. È il caso di riposo, quello che si vede aprendo le Impostazioni.
LinearGradient gradienteDissolvenza({
  required double alto,
  required double basso,
  required double altezza,
}) {
  if (altezza <= 0) {
    return const LinearGradient(colors: [_tieni, _tieni]);
  }
  // Le fermate devono restare in ordine anche su riquadri più corti delle sfumature.
  final inizio = (alto / altezza).clamp(0.0, 1.0);
  final fine = (1 - basso / altezza).clamp(inizio, 1.0);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [alto > 0 ? _togli : _tieni, _tieni, _tieni, basso > 0 ? _togli : _tieni],
    stops: [0, inizio, fine, 1],
  );
}

/// Vero se questo gradiente non cancella nulla: serve ai test e alla lettura del codice.
bool dissolvenzaNeutra(LinearGradient g) =>
    g.colors.every((c) => c.a == 1.0);
