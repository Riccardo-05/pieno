// Il risparmio al netto della deviazione (linee-guida/10-percorsi-e-backend.md, Fase 6).
// I numeri caleranno, e in alcune zone la pastiglia sparirà: è il punto, non un difetto.

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/domain/risparmio.dart';

void main() {
  group('costo della deviazione', () {
    test('il più vicino non paga nulla', () {
      final costo = costoDeviazione(
        kmImpianto: 2.0,
        kmPiuVicino: 2.0,
        consumoLitriPer100km: 7,
        prezzoAlLitro: 1.8,
      );
      expect(costo, 0);
    });

    test('più vicino del più vicino non esiste: mai negativo', () {
      final costo = costoDeviazione(
        kmImpianto: 1.0,
        kmPiuVicino: 2.0,
        consumoLitriPer100km: 7,
        prezzoAlLitro: 1.8,
      );
      expect(costo, 0);
    });

    test('si pagano i km in più, andata e ritorno', () {
      // 5 km in più × 2 (a/r) = 10 km; a 7 l/100 km sono 0,7 l; a 1,80 €/l = 1,26 €.
      final costo = costoDeviazione(
        kmImpianto: 7.0,
        kmPiuVicino: 2.0,
        consumoLitriPer100km: 7,
        prezzoAlLitro: 1.8,
      );
      expect(costo, closeTo(1.26, 0.001));
    });

    test('un impianto lontano non risulta più conveniente di uno vicino quando non lo è', () {
      // Il caso che la Fase 6 esiste per sistemare: tre centesimi meno al litro,
      // ma undici chilometri di strada in più.
      const media = 1.850, capacita = 50;
      const prezzoVicino = 1.849, prezzoLontano = 1.819;

      final lordoLontano = risparmioSulPieno(prezzoLontano, media, litri: capacita);
      final nettoLontano = risparmioSulPieno(
        prezzoLontano,
        media,
        litri: capacita,
        deviazioneEuro: costoDeviazione(
          kmImpianto: 12.5,
          kmPiuVicino: 1.5,
          consumoLitriPer100km: 7,
          prezzoAlLitro: prezzoLontano,
        ),
      );
      final nettoVicino = risparmioSulPieno(prezzoVicino, media, litri: capacita);

      expect(lordoLontano, greaterThan(nettoVicino),
          reason: 'al lordo il lontano sembrava il migliore');
      expect(nettoLontano, lessThan(nettoVicino),
          reason: 'al netto della strada non lo è più');
      expect(risparmioDaMostrare(nettoLontano), isFalse,
          reason: 'sotto i 50 centesimi non si promette niente');
    });

    test('il consumo dichiarato conta: un mezzo che beve paga di più', () {
      double con(double consumo) => costoDeviazione(
            kmImpianto: 10,
            kmPiuVicino: 0,
            consumoLitriPer100km: consumo,
            prezzoAlLitro: 1.8,
          );
      expect(con(12), greaterThan(con(5)));
    });
  });
}
