// Manifest dei dati pubblici (data-pipeline -> manifest.json). Elenca le province con
// il loro baricentro, così l'app sceglie la provincia più vicina alla posizione utente.

import '../domain/geo.dart';

class VoceProvincia {
  final String sigla;
  final int impianti;
  final double? lat;
  final double? lon;

  const VoceProvincia({
    required this.sigla,
    required this.impianti,
    required this.lat,
    required this.lon,
  });

  factory VoceProvincia.fromJson(Map<String, dynamic> j) {
    final centro = j['centro'] as Map<String, dynamic>?;
    return VoceProvincia(
      sigla: j['sigla'] as String,
      impianti: (j['impianti'] as num?)?.toInt() ?? 0,
      lat: (centro?['lat'] as num?)?.toDouble(),
      lon: (centro?['lon'] as num?)?.toDouble(),
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

  /// Sigla della provincia col baricentro più vicino a (lat, lon), o null se assenti.
  String? provinciaPiuVicina(double lat, double lon) {
    String? migliore;
    double minDist = double.infinity;
    for (final p in province) {
      if (p.lat == null || p.lon == null) continue;
      final d = distanzaKm(lat, lon, p.lat!, p.lon!);
      if (d < minDist) {
        minDist = d;
        migliore = p.sigla;
      }
    }
    return migliore;
  }
}
