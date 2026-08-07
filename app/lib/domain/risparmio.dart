// Calcolo del più conveniente e del risparmio "sul pieno" (pag. 2, 7 e
// linee-guida/05-dati-e-qualita.md).
//
// - Base dichiarata: 50 litri ("sul pieno").
// - Confronto con la MEDIA DELLA ZONA (mai la media regionale).
// - Sotto 0,50 € il risparmio sparisce (non si mostrano cifre irrilevanti).
// - "al netto della deviazione": la formula è in costoDeviazione(), e vive di distanze
//   SU STRADA (linee-guida/10-percorsi-e-backend.md, Fase 6). Con la sola linea d'aria
//   il numero sarebbe una finta precisione: chi è di là dal fiume paga il doppio dei km
//   che il righello suggerisce.

import '../models/carburante.dart';
import '../models/impianto.dart';

class RisparmioConfig {
  RisparmioConfig._();
  static const int baseLitri = 50;
  static const double sogliaMinimaEuro = 0.50;

  /// Consumo medio di ripiego, in litri per 100 km. È la voce «Consumo medio»
  /// delle Impostazioni: chi non la tocca ha comunque un numero onesto.
  static const double consumoPredefinito = 7.0;
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

/// Costo della deviazione per raggiungere un impianto invece del più vicino.
///
/// Chi è già il più vicino non paga nulla; gli altri pagano i **chilometri in
/// più, andata e ritorno**, al consumo dichiarato dall'utente e al prezzo che
/// pagherebbero alla pompa — il carburante bruciato per andarci è lo stesso che
/// stanno andando a comprare.
///
/// I chilometri devono essere **su strada**: è tutto il senso della Fase 6.
/// Con la linea d'aria si sottostima sistematicamente chi sta di là da un fiume,
/// da una ferrovia o da un'uscita di tangenziale.
double costoDeviazione({
  required double kmImpianto,
  required double kmPiuVicino,
  required double consumoLitriPer100km,
  required double prezzoAlLitro,
}) {
  final inPiu = kmImpianto - kmPiuVicino;
  if (inPiu <= 0) return 0; // è lui il più vicino: non deve niente a nessuno
  return inPiu * 2 * consumoLitriPer100km / 100 * prezzoAlLitro;
}

/// True se il risparmio va mostrato (>= soglia minima).
bool risparmioDaMostrare(double risparmio) => risparmio >= RisparmioConfig.sogliaMinimaEuro;

/// Un impianto è "sopra la media di zona" per quel carburante (colore rame).
bool sopraLaMedia(Impianto i, Carburante c, double? media) {
  final p = i.prezzoDi(c);
  return media != null && p != null && p.valore > media;
}
