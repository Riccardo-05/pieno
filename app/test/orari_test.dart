// Il parser di `opening_hours`: quello che decide se sulla scheda compare
// «Aperto», «Chiuso ora» o niente. Sbagliare qui è peggio che tacere, quindi i
// casi non gestiti devono finire su «sconosciuto» e non su «chiuso».

import 'package:flutter_test/flutter_test.dart';
import 'package:pieno/domain/orari.dart';

// Lunedì 10 agosto 2026, ore 10:00. Domenica 9 agosto 2026, ore 10:00.
final lunediMattina = DateTime(2026, 8, 10, 10, 0);
final lunediNotte = DateTime(2026, 8, 10, 23, 30);
final domenicaMattina = DateTime(2026, 8, 9, 10, 0);

void main() {
  group('giorni chiusi dichiarati a parole', () {
    test('«Su off» chiude la domenica, non tutta la settimana', () {
      const orario = 'Mo-Sa 07:00-20:00; Su off';

      expect(statoApertura(orario, lunediMattina).stato, StatoApertura.aperto);
      expect(statoApertura(orario, domenicaMattina).stato, StatoApertura.chiuso);
    });

    test('«Su closed» si comporta come «Su off»', () {
      const orario = 'Mo-Fr 06:00-22:00; Su closed';

      expect(statoApertura(orario, lunediMattina).stato, StatoApertura.aperto);
      expect(statoApertura(orario, domenicaMattina).stato, StatoApertura.chiuso);
    });

    test('un giorno singolo chiuso non tocca gli altri', () {
      const orario = 'Mo-Su 07:00-20:00; We off';

      expect(statoApertura(orario, lunediMattina).stato, StatoApertura.aperto);
      expect(statoApertura(orario, DateTime(2026, 8, 12, 10, 0)).stato,
          StatoApertura.chiuso);
    });
  });

  group('casi già coperti, che devono restare tali', () {
    test('24/7 è sempre aperto', () {
      expect(statoApertura('24/7', lunediNotte).stato, StatoApertura.aperto);
    });

    test('fasce diverse per gruppi di giorni', () {
      const orario = 'Mo-Fr 06:00-22:00; Sa,Su 08:00-20:00';

      expect(statoApertura(orario, lunediMattina).stato, StatoApertura.aperto);
      expect(statoApertura(orario, domenicaMattina).stato, StatoApertura.aperto);
      expect(statoApertura(orario, lunediNotte).stato, StatoApertura.chiuso);
    });

    test('orario assente: sconosciuto, non chiuso', () {
      expect(statoApertura(null, lunediMattina).stato, StatoApertura.sconosciuto);
      expect(statoApertura('   ', lunediMattina).stato, StatoApertura.sconosciuto);
      expect(etichettaApertura(null, lunediMattina), isNull);
    });

    test('forme non gestite restano sconosciute invece di inventare', () {
      expect(statoApertura('sunrise-sunset', lunediMattina).stato,
          StatoApertura.sconosciuto);
    });

    test("l'etichetta dice a che ora chiude", () {
      expect(etichettaApertura('Mo-Sa 07:00-20:00; Su off', lunediMattina),
          'Aperto · chiude 20:00');
    });
  });
}
