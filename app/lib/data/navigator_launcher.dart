// «Portami qui»: apre il navigatore di sistema con le coordinate dell'impianto
// (Roadmap 03 — "«Portami qui» verso il navigatore di sistema").
//
// Fase 1 (pag. 9): si passano le coordinate a un'app esterna. Qui usiamo un URL
// universale di mappe, che il sistema apre col navigatore predefinito. La scelta
// esplicita Apple/Google/Waze vive in Impostazioni e arriva con la Tappa 05.
// Il bottone dice cosa succede: "Portami qui", non "Naviga" (pag. 10).

import 'package:url_launcher/url_launcher.dart';

Future<bool> portamiQui(double lat, double lon) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
  );
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
