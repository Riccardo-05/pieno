// Distanza geografica (Haversine), in km. Speculare a data-pipeline/pieno_pipeline/geo.py.

import 'dart:math' as math;

double distanzaKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0; // raggio terrestre in km
  double rad(double g) => g * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}
