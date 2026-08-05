// Posizione: "un solo GPS fix per aprire, precisione bilanciata" (pag. 13).
// Permessi graduali: la spiegazione va mostrata PRIMA del dialogo di sistema
// (Roadmap 02: "Permessi di posizione con la spiegazione prima del dialogo").
// Senza permesso l'app funziona lo stesso chiedendo una città (pag. 13) — gestito a monte.

import 'package:geolocator/geolocator.dart';

class Posizione {
  final double lat;
  final double lon;
  const Posizione(this.lat, this.lon);
}

class LocationService {
  /// Da chiamare SOLO dopo che l'utente ha visto la schermata di spiegazione
  /// e ha scelto di procedere. Ritorna null se il permesso è negato.
  Future<Posizione?> fixIniziale() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permesso = await Geolocator.checkPermission();
    if (permesso == LocationPermission.denied) {
      permesso = await Geolocator.requestPermission(); // dialogo di sistema
    }
    if (permesso == LocationPermission.denied ||
        permesso == LocationPermission.deniedForever) {
      return null;
    }

    final p = await Geolocator.getCurrentPosition(
      // precisione "bilanciata", non massima (costa secondi e batteria).
      desiredAccuracy: LocationAccuracy.medium,
    );
    return Posizione(p.latitude, p.longitude);
  }
}
