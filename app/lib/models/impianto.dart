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

  const Impianto({
    required this.id,
    required this.nome,
    required this.indirizzo,
    required this.comune,
    required this.marchio,
    required this.lat,
    required this.lon,
    required this.prezzi,
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

  const DatiProvincia({
    required this.versione,
    required this.datoDel,
    required this.provincia,
    required this.attribuzione,
    required this.impianti,
  });

  factory DatiProvincia.fromJson(Map<String, dynamic> j) => DatiProvincia(
        versione: j['versione'] as String? ?? '',
        datoDel: j['dato_del'] != null ? DateTime.tryParse(j['dato_del'] as String) : null,
        provincia: j['provincia'] as String? ?? '',
        attribuzione: j['attribuzione'] as String? ?? '',
        impianti: ((j['impianti'] as List?) ?? [])
            .map((e) => Impianto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Età del dato: sempre disponibile e mostrata (principio "onestà sul dato").
  Duration? get eta => datoDel == null ? null : DateTime.now().difference(datoDel!);
}
