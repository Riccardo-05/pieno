// Calcolo del più conveniente e del risparmio "sul pieno" (pag. 2, 7 e
// linee-guida/05-dati-e-qualita.md).
//
// - Base dichiarata: 50 litri ("sul pieno").
// - Confronto con la MEDIA DELLA ZONA (mai la media regionale).
// - Sotto 0,50 € il risparmio sparisce (non si mostrano cifre irrilevanti).
// - "al netto della deviazione": il PDF cita la deviazione ma non ne dà la formula
//   -> il costo di deviazione è DA DEFINIRE; per ora il risparmio è lordo.

import '../models/carburante.dart';
import '../models/impianto.dart';

class RisparmioConfig {
  RisparmioConfig._();
  static const int baseLitri = 50;
  static const double sogliaMinimaEuro = 0.50;
}

/// Media di zona del carburante indicato tra gli impianti passati (null se nessun prezzo).
double? mediaZona(List<Impianto> impianti, Carburante c) {
  final valori = <double>[
    for (final i in impianti)
      if (i.prezzoDi(c) != null) i.prezzoDi(c)!.valore,
  ];
  if (valori.isEmpty) return null;
  return valori.reduce((a, b) => a + b) / valori.length;
}

/// Risparmio lordo sul pieno rispetto alla media di zona (può essere negativo).
/// deviazioneEuro: costo della deviazione da sottrarre (DA DEFINIRE, default 0).
double risparmioSulPieno(double prezzo, double media,
    {int litri = RisparmioConfig.baseLitri, double deviazioneEuro = 0}) {
  return (media - prezzo) * litri - deviazioneEuro;
}

/// True se il risparmio va mostrato (>= soglia minima).
bool risparmioDaMostrare(double risparmio) => risparmio >= RisparmioConfig.sogliaMinimaEuro;

/// Un impianto è "sopra la media di zona" per quel carburante (colore rame).
bool sopraLaMedia(Impianto i, Carburante c, double? media) {
  final p = i.prezzoDi(c);
  return media != null && p != null && p.valore > media;
}
