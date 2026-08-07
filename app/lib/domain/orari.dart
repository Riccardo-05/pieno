// Valutazione orari di apertura in formato OpenStreetMap `opening_hours`.
// Parser SEMPLIFICATO che copre i casi comuni dei distributori (24/7, fasce per giorni,
// intervalli multipli, "off"/"closed"). Sui casi non gestiti restituisce "sconosciuto":
// meglio non mostrare nulla che mostrare un dato sbagliato (onestà sul dato).

enum StatoApertura { aperto, chiuso, sconosciuto }

class InfoApertura {
  final StatoApertura stato;

  /// Minuti dalla mezzanotte a cui chiude (se aperto), per "aperto · chiude 19:30".
  final int? chiudeMin;

  const InfoApertura(this.stato, [this.chiudeMin]);

  static const sconosciuto = InfoApertura(StatoApertura.sconosciuto);
}

const _giorni = {'Mo': 0, 'Tu': 1, 'We': 2, 'Th': 3, 'Fr': 4, 'Sa': 5, 'Su': 6};

/// Calcola lo stato di apertura ADESSO a partire dalla stringa OSM.
InfoApertura statoApertura(String? orari, [DateTime? adesso]) {
  if (orari == null || orari.trim().isEmpty) return InfoApertura.sconosciuto;
  final s = orari.trim();
  final now = adesso ?? DateTime.now();
  final giornoOggi = now.weekday - 1; // Dart: Mon=1..Sun=7 → 0..6
  final minOra = now.hour * 60 + now.minute;

  if (s == '24/7' || s == '24/7 open') {
    return const InfoApertura(StatoApertura.aperto, 1440);
  }

  final settimana = List.generate(7, (_) => <List<int>>[]);
  var parsatoQualcosa = false;

  try {
    for (final regolaRaw in s.split(';')) {
      final regola = regolaRaw.trim();
      if (regola.isEmpty) continue;
      // Regole con festivi/scolastici/commenti: non gestite, si saltano (onestà).
      if (regola.contains('PH') || regola.contains('SH') || regola.contains('"')) continue;

      final giorni = _giorniDi(regola);
      final target = giorni.isEmpty ? const [0, 1, 2, 3, 4, 5, 6] : giorni;

      if (regola.contains('off') || regola.contains('closed')) {
        for (final g in target) {
          settimana[g] = [];
        }
        parsatoQualcosa = true;
        continue;
      }
      final intervalli = _intervalliDi(regola);
      if (intervalli.isEmpty) continue;
      for (final g in target) {
        settimana[g] = List.of(intervalli);
      }
      parsatoQualcosa = true;
    }
  } catch (_) {
    return InfoApertura.sconosciuto;
  }
  if (!parsatoQualcosa) return InfoApertura.sconosciuto;

  for (final iv in settimana[giornoOggi]) {
    final start = iv[0], end = iv[1];
    final aperto = end >= start
        ? (minOra >= start && minOra < end)
        : (minOra >= start || minOra < end); // oltre la mezzanotte
    if (aperto) return InfoApertura(StatoApertura.aperto, end);
  }
  return const InfoApertura(StatoApertura.chiuso);
}

List<int> _giorniDi(String regola) {
  final giorni = <int>[];
  // La parte "giorni" sta prima del primo orario (una cifra). Se non c'è testo prima, la
  // regola vale tutti i giorni.
  final m = RegExp(r'^\s*([A-Za-z,\-\s]+?)\s*\d').firstMatch(regola);
  final parte = m?.group(1)?.trim() ?? '';
  if (parte.isEmpty) return giorni;
  for (final blocco in parte.split(',')) {
    final b = blocco.trim();
    if (b.contains('-')) {
      final parti = b.split('-');
      final a = _giorni[parti[0].trim()];
      final z = _giorni[parti[1].trim()];
      if (a != null && z != null) {
        var g = a;
        for (var passi = 0; passi < 7; passi++) {
          giorni.add(g);
          if (g == z) break;
          g = (g + 1) % 7;
        }
      }
    } else {
      final g = _giorni[b];
      if (g != null) giorni.add(g);
    }
  }
  return giorni;
}

List<List<int>> _intervalliDi(String regola) {
  final out = <List<int>>[];
  final re = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})');
  for (final m in re.allMatches(regola)) {
    final start = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    var end = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
    if (end == 0) end = 1440; // 24:00 = fine giornata
    out.add([start, end]);
  }
  return out;
}

/// Etichetta breve per l'interfaccia (null se sconosciuto → non si mostra nulla).
String? etichettaApertura(String? orari, [DateTime? adesso]) {
  final info = statoApertura(orari, adesso);
  switch (info.stato) {
    case StatoApertura.aperto:
      final c = info.chiudeMin;
      if (c == null || c >= 1440) return 'Aperto';
      final hh = (c ~/ 60).toString().padLeft(2, '0');
      final mm = (c % 60).toString().padLeft(2, '0');
      return 'Aperto · chiude $hh:$mm';
    case StatoApertura.chiuso:
      return 'Chiuso ora';
    case StatoApertura.sconosciuto:
      return null;
  }
}
