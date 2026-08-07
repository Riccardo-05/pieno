// Attribuzione della mappa. Le tile di OpenFreeMap derivano da OpenStreetMap: la
// licenza ODbL richiede che il credito sia visibile dove la mappa è mostrata, non
// solo dentro le impostazioni.

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';

class AttribuzioneMappa extends StatelessWidget {
  const AttribuzioneMappa({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PienoColors.vetro,
        borderRadius: BorderRadius.circular(PienoRadii.pillola),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '© OpenStreetMap contributors',
          style: PienoText.valoreDettaglio.copyWith(fontSize: 10),
        ),
      ),
    );
  }
}
