// Modello lato app, speculare al record compatto prodotto dalla pipeline
// (data-pipeline/pieno_pipeline/build.py -> _record). Chiavi corte: id, n, v, c, m, lat, lon, p.

import 'carburante.dart';

class Prezzo {
  final Carburante carburante;
  final double valore; // €/l, tre decimali
  final bool selfService;
  final DateTime? comunicatoIl;

  const Prezzo({
    required this.carburante,
    required this.valore,
    required this.selfService,
    required this.comunicatoIl,
  });

  factory Prezzo.fromJson(String chiave, Map<String, dynamic> j) => Prezzo(
        carburante: Carburante.daChiave(chiave),
        valore: (j['v'] as num).toDouble(),
        selfService: j['s'] as bool? ?? false,
        comunicatoIl: j['t'] != null ? DateTime.tryParse(j['t'] as String) : null,
      );
}

class Impianto {
  final String id;
  final String nome;
  final String indirizzo;
  final String comune;
  final String marchio;
  final double? lat;
  final double? lon;
  final Map<Carburante, Prezzo> prezzi;

  /// Orari di apertura (formato OpenStreetMap `opening_hours`), se disponibili. Null quando
  /// OSM non li ha per questo impianto. I prezzi mostrati sono sempre e solo self.
  final String? orari;

  /// Rapporto fra strada e linea d'aria attorno a questo impianto: 1,18 per quello
  /// sulla statale, 2,40 per quello di là dal fiume. Lo precalcola il servizio
  /// percorsi una volta al mese (linee-guida/10-percorsi-e-backend.md, Fase 5).
  ///
  /// È il **paracadute** per quando il server è spento: con questo la stima resta
  /// molto più vicina al vero della linea d'aria pura. Null dove la misura non è
  /// riuscita, e sui file salvati prima che il campo esistesse.
  final double? fattoreStradale;

  const Impianto({
    required this.id,
    required this.nome,
    required this.indirizzo,
    required this.comune,
    required this.marchio,
    required this.lat,
    required this.lon,
    required this.prezzi,
    this.orari,
    this.fattoreStradale,
  });

  factory Impianto.fromJson(Map<String, dynamic> j) {
    final prezziJson = (j['p'] as Map<String, dynamic>? ?? {});
    final prezzi = <Carburante, Prezzo>{};
    prezziJson.forEach((chiave, valore) {
      prezzi[Carburante.daChiave(chiave)] =
          Prezzo.fromJson(chiave, valore as Map<String, dynamic>);
    });
    return Impianto(
      id: j['id'] as String,
      nome: j['n'] as String? ?? '',
      indirizzo: j['v'] as String? ?? '',
      comune: j['c'] as String? ?? '',
      marchio: j['m'] as String? ?? '',
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      prezzi: prezzi,
      orari: j['oh'] as String?,
      fattoreStradale: (j['fs'] as num?)?.toDouble(),
    );
  }

  Prezzo? prezzoDi(Carburante c) => prezzi[c];
}

/// File di una provincia + metadati (versione, data del dato, attribuzione).
class DatiProvincia {
  final String versione;
  final DateTime? datoDel;
  final String provincia;
  final String attribuzione;
  final List<Impianto> impianti;

  /// Prezzo medio della provincia per carburante, calcolato dalla pipeline. È il termine
  /// di paragone del risparmio: essendo provinciale non cambia quando l'utente muove il
  /// raggio di ricerca. Vuoto sui file salvati prima che il campo esistesse.
  final Map<Carburante, double> medie;

  const DatiProvincia({
    required this.versione,
    required this.datoDel,
    required this.provincia,
    required this.attribuzione,
    required this.impianti,
    this.medie = const {},
  });

  factory DatiProvincia.fromJson(Map<String, dynamic> j) => DatiProvincia(
        versione: j['versione'] as String? ?? '',
        datoDel: j['dato_del'] != null ? DateTime.tryParse(j['dato_del'] as String) : null,
        provincia: j['provincia'] as String? ?? '',
        attribuzione: j['attribuzione'] as String? ?? '',
        medie: ((j['medie'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(Carburante.daChiave(k as String), (v as num).toDouble()),
        ),
        impianti: ((j['impianti'] as List?) ?? [])
            .map((e) => Impianto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Età del dato: sempre disponibile e mostrata (principio "onestà sul dato").
  Duration? get eta => datoDel == null ? null : DateTime.now().difference(datoDel!);
}
