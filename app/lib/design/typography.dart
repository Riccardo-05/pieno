// Stili tipografici (pag. 4). Sora per numeri/prezzi (cifre tabulari), Manrope per il resto.
// tabular-nums attivo su ogni prezzo (linee-guida/02-design-tokens.md).

import 'package:flutter/widgets.dart';
import 'tokens.dart';

const _tabular = [FontFeature.tabularFigures()];

class PienoText {
  PienoText._();

  // Prezzo principale: Sora 300 · 78 px · −0,05 em · tabular. I decimali sono Sora 500
  // (stesso corpo): vedi PriceText che compone intero+decimali.
  static const prezzoPrincipale = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w300,
    fontSize: 78,
    letterSpacing: 78 * -0.05, // −0,05 em
    fontFeatures: _tabular,
    color: PienoColors.inchiostro,
  );
  static const prezzoPrincipaleDecimali = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w500,
    fontSize: 78,
    letterSpacing: 78 * -0.05,
    fontFeatures: _tabular,
    color: PienoColors.inchiostro,
  );

  static const prezzoFoglioMappa = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w300,
    fontSize: 52,
    fontFeatures: _tabular,
    color: PienoColors.inchiostro,
  );

  static const prezzoLista = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w400,
    fontSize: 21,
    letterSpacing: 21 * -0.03,
    fontFeatures: _tabular,
    color: PienoColors.inchiostro,
  );

  static const marcatoreMappa = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w400,
    fontSize: 15,
    fontFeatures: _tabular,
    color: PienoColors.inchiostro,
  );
  static const marcatoreMappaMigliore = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w600,
    fontSize: 17,
    fontFeatures: _tabular,
    color: Color(0xFFFFFFFF),
  );

  static const titoloPagina = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w800,
    fontSize: 27,
    letterSpacing: 27 * -0.03,
    color: PienoColors.inchiostro,
  );

  static const nomeImpianto = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 21,
    letterSpacing: 21 * -0.015,
    color: PienoColors.inchiostro,
  );

  static const voceImpostazione = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w600,
    fontSize: 15.5,
    color: PienoColors.inchiostro,
  );

  static const valoreDettaglio = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w500,
    fontSize: 15,
    color: PienoColors.grafite,
  );

  static const bottonePrimario = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 18.5, // 18–19 px
    color: Color(0xFFFFFFFF),
  );

  // Occhiello/sezione: Manrope 700 · 11–12,5 px · +0,14 em · maiuscolo.
  static const occhiello = TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 11 * 0.14,
    color: PienoColors.grafite,
  );
}
