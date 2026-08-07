// Design token come costanti (Roadmap 02: "token di design come costanti").
// FONTE UNICA: linee-guida/design-tokens.json e pag. 4 del documento di progetto.
// I valori numerici sono riportati esatti. Non modificare qui senza aggiornare i token.

import 'package:flutter/widgets.dart';

/// Colori della palette (pag. 4).
class PienoColors {
  PienoColors._();

  static const inchiostro = Color(0xFF0E1620); // testo principale, filtro attivo, voce selezionata
  static const grafite = Color(0xFF77848F); // testo secondario, valori impostazioni
  static const mentaChiara = Color(0xFF00C2A6); // inizio gradiente azione primaria
  static const mentaScuraGrad = Color(0xFF00887E); // fine gradiente azione primaria
  static const mentaScura = Color(0xFF00806F); // testo risparmio e azioni testuali
  static const mentaVelo = Color(0x1A00B39A); // rgba(0,179,154,.10) sfondo pastiglia risparmio
  static const rame = Color(0xFFC0603A); // solo prezzi sopra la media di zona
  static const bluPosizione = Color(0xFF2F6BFF); // solo il puntino "sono qui"
  static const fondo = Color(0xFFEDF2F3); // fondo schermate
  static const fondoMappa = Color(0xFFE7EDEE); // fondo mappa / terra

  // Vetro: bianco 72%, bordo bianco 85%.
  static const vetro = Color(0xB8FFFFFF); // 0.72 * 255 ≈ 184 = 0xB8
  static const vetroBordo = Color(0xD9FFFFFF); // 0.85 * 255 ≈ 217 = 0xD9
  static const vetro50 = Color(0x80FFFFFF); // bianco 50%, riempimento chip alternativa

  // Superficie dei fogli / pannelli inferiori (bottom sheet, foglio mappa).
  static const foglio = Color(0xFFF7FAFB);

  // Aurore di fondo (mai visibili come forme).
  static const auroraMenta = Color(0x4D00B39A); // rgba(0,179,154,.30)
  static const auroraLavanda = Color(0x3D7A96FF); // rgba(122,150,255,.24)

  // Colori stile mappa (pag. 6).
  static const mappaTerra = Color(0xFFE7EDEE);
  static const mappaIsolati = Color(0xFFDFE7E8);
  static const mappaVerde = Color(0xFFD6E7DF);
  static const mappaAcqua = Color(0xFFD3E4EA);
  static const mappaStrade = Color(0xFFFFFFFF);

  /// Gradiente menta a 135°: azione primaria, marcatore migliore, interruttori attivi.
  static const gradienteMenta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight, // ≈ 135°
    colors: [mentaChiara, mentaScuraGrad],
  );
}

/// Raggi degli angoli (pag. 4).
class PienoRadii {
  PienoRadii._();

  static const double schedaPrincipale = 36;
  static const double schedaCampi = 32;
  static const double gruppoImpostazioni = 22;
  static const double bottonePrimarioMin = 22;
  static const double bottonePrimarioMax = 26;
  static const double campoTesto = 20;
  static const double chipAlternativa = 24;
  static const double pillola = 999;
}

/// Ombre e sfocatura vetro (pag. 4).
class PienoElevations {
  PienoElevations._();

  static const List<BoxShadow> schedaPrincipale = [
    BoxShadow(color: Color(0x1A0E2026), blurRadius: 50, offset: Offset(0, 20)), // 0 20 50 rgba(14,32,38,.10)
  ];
  static const List<BoxShadow> gruppoImpostazioni = [
    BoxShadow(color: Color(0x120E2026), blurRadius: 26, offset: Offset(0, 10)), // 0 10 26 rgba(14,32,38,.07)
  ];
  static const List<BoxShadow> bottonePrimario = [
    BoxShadow(color: Color(0x52009682), blurRadius: 30, offset: Offset(0, 14)), // 0 14 30 rgba(0,150,130,.32)
  ];
  static const List<BoxShadow> pillola = [
    BoxShadow(color: Color(0x1A0E2026), blurRadius: 22, offset: Offset(0, 8)), // 0 8 22 rgba(14,32,38,.10)
  ];

  static const double vetroBlurCampi = 14;
  static const double vetroBlurSchede = 26;
  static const double auroraBlur = 70;
}

/// Spaziature e misure dei componenti (pag. 4–8).
class PienoSpacing {
  PienoSpacing._();

  static const double frameW = 390;
  static const double frameH = 812;
  static const double margineLaterale = 18; // standard
  static const double margineScheda = 22; // schermate a scheda
  static const double paddingPillola = 5;
  static const double gapRicercaFiltro = 9;
  static const double offsetRicercaAlto = 52;
  static const double switchFlottanteDalBasso = 30;
  static const double divisoriRientro = 16;
}

/// Misure minime e altezze (pag. 2–8).
class PienoSizes {
  PienoSizes._();

  static const double targetMinimo = 50; // nessun elemento toccabile sotto i 50 px
  static const double azionePrimaria = 74; // Vicino a te
  static const double azionePrimariaMin = 66;
  static const double bottoneFoglioMappa = 70;
  static const double campoTesto = 56;
  static const double accessiEsterni = 54;
  static const double barraRicerca = 48;
  static const double pulsanteTondoElenco = 40;
  static const double pulsanteTondoMappa = 52;
  static const double rigaImpostazione = 50;
  static const double testataAccount = 78;
  static const double avatarAccount = 46;
  static const Size interruttore = Size(48, 29);
  static const double marcatoreAlone = 96;
}
