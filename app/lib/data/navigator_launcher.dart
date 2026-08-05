// «Portami qui»: apre il navigatore scelto in Impostazioni con le coordinate
// dell'impianto (pag. 8, 9). Il bottone dice cosa succede: "Portami qui", non "Naviga".

import 'package:url_launcher/url_launcher.dart';

import '../models/navigatore.dart';

Future<bool> portamiQui(double lat, double lon,
    {Navigatore navigatore = Navigatore.sistema}) async {
  final uri = switch (navigatore) {
    Navigatore.apple => Uri.parse('https://maps.apple.com/?daddr=$lat,$lon&dirflg=d'),
    Navigatore.waze => Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes'),
    // "google" e "sistema": URL universale di Google Maps; il sistema lo apre col
    // navigatore predefinito o nel browser. Il ripiego naturale è questo.
    _ => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon'),
  };
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
