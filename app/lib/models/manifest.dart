// Manifest dei dati pubblici (data-pipeline -> manifest.json). Elenca le province con
// il loro baricentro, così l'app sceglie la provincia più vicina alla posizione utente.

import '../domain/geo.dart';

/// Rettangolo che contiene tutti gli impianti di una provincia.
///
/// Non è il confine amministrativo: è una cosa più utile e più onesta, cioè fin dove
/// arrivano davvero i dati che abbiamo per quella sigla.
class Riquadro {
  final double latMin, latMax, lonMin, lonMax;

  const Riquadro({
    required this.latMin,
    required this.latMax,
    required this.lonMin,
    required this.lonMax,
  });

  static Riquadro? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final latMin = (j['latMin'] as num?)?.toDouble();
    final latMax = (j['latMax'] as num?)?.toDouble();
    final lonMin = (j['lonMin'] as num?)?.toDouble();
    final lonMax = (j['lonMax'] as num?)?.toDouble();
    if (latMin == null || latMax == null || lonMin == null || lonMax == null) return null;
    return Riquadro(latMin: latMin, latMax: latMax, lonMin: lonMin, lonMax: lonMax);
  }

  bool contiene(double lat, double lon) =>
      lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax;
}

class VoceProvincia {
  final String sigla;
  final int impianti;
  final double? lat;
  final double? lon;

  /// Estensione della provincia. Null sui manifest salvati prima che esistesse.
  final Riquadro? riquadro;

  const VoceProvincia({
    required this.sigla,
    required this.impianti,
    required this.lat,
    required this.lon,
    this.riquadro,
  });

  factory VoceProvincia.fromJson(Map<String, dynamic> j) {
    final centro = j['centro'] as Map<String, dynamic>?;
    return VoceProvincia(
      sigla: j['sigla'] as String,
      impianti: (j['impianti'] as num?)?.toInt() ?? 0,
      lat: (centro?['lat'] as num?)?.toDouble(),
      lon: (centro?['lon'] as num?)?.toDouble(),
      riquadro: Riquadro.fromJson(j['riquadro'] as Map<String, dynamic>?),
    );
  }
}

class Manifest {
  final String versione;
  final List<VoceProvincia> province;

  const Manifest({required this.versione, required this.province});

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        versione: j['versione'] as String? ?? '',
        province: ((j['province'] as List?) ?? [])
            .map((e) => VoceProvincia.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Sigla della provincia a cui appartiene (lat, lon), o null se il manifest non ha
  /// coordinate.
  ///
  /// Prima vince chi **contiene** il punto nel proprio riquadro; solo se nessuno lo
  /// contiene (o se i riquadri non ci sono, sui manifest vecchi) si ripiega sul
  /// baricentro più vicino.
  ///
  /// L'ordine conta, ed è tutto il punto: il baricentro da solo manda chi sta a Monza
  /// su Milano, perché il baricentro milanese è più vicino di quello brianzolo. Chi ci
  /// finisce vede un elenco di impianti tutti lontani e non ha modo di capire perché.
  /// Fra due riquadri che si sovrappongono decide il baricentro, che a quel punto è un
  /// criterio ragionevole: siamo già dentro la zona giusta.
  String? provinciaPiuVicina(double lat, double lon) {
    final contenitori = [
      for (final p in province)
        if (p.lat != null && p.lon != null && (p.riquadro?.contiene(lat, lon) ?? false)) p,
    ];
    final candidate = contenitori.isNotEmpty
        ? contenitori
        : [
            for (final p in province)
              if (p.lat != null && p.lon != null) p,
          ];

    String? migliore;
    double minDist = double.infinity;
    for (final p in candidate) {
      final d = distanzaKm(lat, lon, p.lat!, p.lon!);
      if (d < minDist) {
        minDist = d;
        migliore = p.sigla;
      }
    }
    return migliore;
  }
}
