// Il servizio percorsi sta su una macchina spenta sei ore su ventiquattro.
// Questi test verificano che l'app se lo ricordi: tetto di tempo, ripiego
// dichiarato, niente domande inutili. (linee-guida/10-percorsi-e-backend.md, Fase 4)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pieno/data/location_service.dart';
import 'package:pieno/data/percorsi_repository.dart';
import 'package:pieno/models/impianto.dart';

Impianto impianto(String id, double lat, double lon) => Impianto(
      id: id,
      nome: 'Impianto $id',
      indirizzo: '',
      comune: '',
      marchio: '',
      lat: lat,
      lon: lon,
      prezzi: const {},
    );

const origine = Posizione(45.4641, 9.1901);

String rispostaPer(int quante) => jsonEncode({
      'distanze': [
        for (var i = 0; i < quante; i++)
          {'metri': 1000 * (i + 1), 'secondi': 60 * (i + 1), 'raggiungibile': true},
      ],
      'daCache': 0,
      'dalMotore': quante,
    });

/// Un guasto di rete qualunque: quello che succede quando la macchina è spenta.
class GuastoDiRete implements Exception {
  const GuastoDiRete();
}

void main() {
  group('servizio percorsi', () {
    test('senza URL configurato non prova nemmeno', () async {
      var chiamate = 0;
      final servizio = PercorsiHttp(
        baseUrl: '',
        client: MockClient((_) async {
          chiamate++;
          return http.Response(rispostaPer(1), 200);
        }),
      );

      expect(servizio.configurato, isFalse);
      expect(await servizio.distanze(origine, [impianto('a', 45.47, 9.22)]), isNull);
      expect(chiamate, 0, reason: 'senza dominio non si bussa a nessuna porta');
    });

    test('le distanze del servizio sono dichiarate come stradali', () async {
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async => http.Response(rispostaPer(1), 200)),
      );

      final esito = await servizio.distanze(origine, [impianto('a', 45.47, 9.22)]);

      expect(esito!['a']!.km, 1.0);
      expect(esito['a']!.tempo, const Duration(seconds: 60));
      expect(esito['a']!.origine, OrigineDistanza.strada);
      expect(esito['a']!.reale, isTrue);
    });

    test('oltre il tetto di due secondi si ripiega', () async {
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 3));
          return http.Response(rispostaPer(1), 200);
        }),
      );

      expect(await servizio.distanze(origine, [impianto('a', 45.47, 9.22)]), isNull);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('servizio spento: nessuna distanza, nessuna eccezione', () async {
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async => throw const GuastoDiRete()),
      );

      expect(await servizio.distanze(origine, [impianto('a', 45.47, 9.22)]), isNull);
    });

    test('fermi sul posto, non si richiede nulla', () async {
      var chiamate = 0;
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async {
          chiamate++;
          return http.Response(rispostaPer(1), 200);
        }),
      );
      final impianti = [impianto('a', 45.47, 9.22)];

      await servizio.distanze(origine, impianti);
      // Spostamento di una cinquantina di metri: sotto la soglia.
      await servizio.distanze(const Posizione(45.4645, 9.1903), impianti);

      expect(chiamate, 1, reason: 'la cache sul telefono deve reggere i piccoli spostamenti');
    });

    test('spostandosi di qualche centinaio di metri si richiede', () async {
      var chiamate = 0;
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async {
          chiamate++;
          return http.Response(rispostaPer(1), 200);
        }),
      );
      final impianti = [impianto('a', 45.47, 9.22)];

      await servizio.distanze(origine, impianti);
      // ~1 km più a nord: le distanze di prima non valgono più.
      await servizio.distanze(const Posizione(45.4731, 9.1901), impianti);

      expect(chiamate, 2);
    });

    test('dopo un buco non si insiste', () async {
      var chiamate = 0;
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async {
          chiamate++;
          throw const GuastoDiRete();
        }),
      );
      final impianti = [impianto('a', 45.47, 9.22)];

      for (var i = 0; i < 5; i++) {
        await servizio.distanze(origine, impianti);
      }

      expect(chiamate, 1, reason: 'di notte è spento per sei ore: bussare non serve');
    });

    test('si chiede solo quello che manca', () async {
      final chieste = <int>[];
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((richiesta) async {
          final corpo = jsonDecode(richiesta.body) as Map<String, dynamic>;
          final quante = (corpo['destinazioni'] as List).length;
          chieste.add(quante);
          return http.Response(rispostaPer(quante), 200);
        }),
      );

      await servizio.distanze(origine, [impianto('a', 45.47, 9.22)]);
      await servizio.distanze(origine, [
        impianto('a', 45.47, 9.22),
        impianto('b', 45.48, 9.23),
      ]);

      expect(chieste, [1, 1], reason: 'la seconda volta manca solo «b»');
    });

    test('una destinazione irraggiungibile non finisce fra le stradali', () async {
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'distanze': [
                  {'metri': 0, 'secondi': 0, 'raggiungibile': false},
                ],
                'daCache': 0,
                'dalMotore': 1,
              }),
              200,
            )),
      );

      expect(await servizio.distanze(origine, [impianto('a', 45.47, 9.22)]), isNull);
    });

    test('risposta di lunghezza sbagliata: si ripiega invece di disallineare', () async {
      final servizio = PercorsiHttp(
        baseUrl: 'http://prova',
        client: MockClient((_) async => http.Response(rispostaPer(1), 200)),
      );

      final esito = await servizio.distanze(origine, [
        impianto('a', 45.47, 9.22),
        impianto('b', 45.48, 9.23),
      ]);

      expect(esito, isNull, reason: 'meglio nessuna distanza che la distanza sbagliata');
    });
  });

  group('ripiego', () {
    test("la linea d'aria si dichiara stima", () {
      final d = stimaInLineaDAria(origine, impianto('a', 45.4731, 9.1901));

      expect(d.origine, OrigineDistanza.stima);
      expect(d.reale, isFalse);
      expect(d.tempo, isNull, reason: 'senza strade non si può promettere un tempo');
      expect(d.km, closeTo(1.0, 0.1));
    });
  });
}
