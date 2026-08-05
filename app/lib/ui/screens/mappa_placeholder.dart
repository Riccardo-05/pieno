// Segnaposto della Mappa (Schermata 2). La schermata definitiva arriva con la Tappa 04.

import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../components/sfondo_aurore.dart';

class MappaPlaceholder extends StatelessWidget {
  const MappaPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SfondoAurore(
        fondo: PienoColors.fondoMappa,
        child: Center(
          child: Text('Mappa — in arrivo (Tappa 04)', style: PienoText.valoreDettaglio),
        ),
      ),
    );
  }
}
