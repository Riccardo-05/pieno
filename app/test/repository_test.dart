// Il ripiego offline-first, messo alla prova con le risposte storte che la rete dà
// davvero: il captive portal del bar che risponde 200 con la sua pagina di login, e la
// cache lasciata a metà da un'app uccisa mentre scriveva.
//
// La promessa del README è una sola: «Se il file del giorno è rotto, l'app continua a
// servire quello buono del giorno prima». Questi test la tengono onesta.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pieno/data/local_store.dart';
import 'package:pieno/data/repository.dart';

const _provinciaBuona = '{"versione":"1","provincia":"MI","impianti":[]}';
const _manifestBuono = '{"versione":"1","province":[{"sigla":"MI","impianti":3}]}';

/// La pagina che restituisce un captive portal: stato 200, corpo che non è JSON.
const _paginaDiLogin = '<html><body>Accedi alla rete</body></html>';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cartella;

  setUp(() {
    cartella = Directory.systemTemp.createTempSync('pieno_repo_test');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cartella.path,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (cartella.existsSync()) cartella.deleteSync(recursive: true);
  });

  /// Un repository che risponde sempre con [corpo], che il test può cambiare.
  ProvinceRepository repoChe(String Function() corpo, {int stato = 200}) =>
      ProvinceRepository(
        baseUrl: 'https://prova',
        client: MockClient((_) async => http.Response(corpo(), stato)),
      );

  group('provincia', () {
    test('una risposta 200 che non è JSON non tocca il dato buono di ieri', () async {
      var corpo = _provinciaBuona;
      final repo = repoChe(() => corpo);

      final ieri = await repo.caricaProvincia('MI');
      expect(ieri.$1, isNotNull);
      expect(ieri.$2, isTrue);

      corpo = _paginaDiLogin;
      final oggi = await repo.caricaProvincia('MI');

      expect(oggi.$1, isNotNull, reason: 'resta il dato buono del giorno prima');
      expect(oggi.$1!.provincia, 'MI');
      expect(oggi.$2, isFalse, reason: "e l'app deve sapere che non viene dalla rete");
    });

    test("una cache illeggibile non fa esplodere l'avvio", () async {
      await LocalStore().salvaProvincia('MI', 'roba a metà {');
      final repo = repoChe(() => _paginaDiLogin);

      final esito = await repo.caricaProvincia('MI');

      expect(esito.$1, isNull, reason: 'niente dati, ma nessuna eccezione');
      expect(esito.$2, isFalse);
    });

    test('la cache illeggibile viene buttata, non riletta ogni volta', () async {
      await LocalStore().salvaProvincia('MI', 'roba a metà {');
      final repo = repoChe(() => _paginaDiLogin);

      await repo.caricaProvincia('MI');

      expect(await LocalStore().haProvincia('MI'), isFalse);
    });

    test('un 500 lascia in piedi il dato salvato', () async {
      await LocalStore().salvaProvincia('MI', _provinciaBuona);
      final repo = repoChe(() => 'errore del server', stato: 500);

      final esito = await repo.caricaProvincia('MI');

      expect(esito.$1, isNotNull);
      expect(esito.$2, isFalse);
    });
  });

  group('impronta del manifest', () {
    String improntaDi(String testo) => sha256.convert(utf8.encode(testo)).toString();

    test('se la copia locale è già quella dichiarata, la rete non si tocca', () async {
      await LocalStore().salvaProvincia('MI', _provinciaBuona);
      var chiamate = 0;
      final repo = ProvinceRepository(
        baseUrl: 'https://prova',
        client: MockClient((_) async {
          chiamate++;
          return http.Response(_provinciaBuona, 200);
        }),
      );

      final esito = await repo.caricaProvincia('MI', impronta: improntaDi(_provinciaBuona));

      expect(chiamate, 0, reason: 'scaricare 1300 impianti identici è lavoro sprecato');
      expect(esito.$1, isNotNull);
      expect(esito.$2, isTrue, reason: 'il dato corrisponde al manifest: è corrente');
    });

    test('se la copia locale è vecchia si scarica', () async {
      await LocalStore().salvaProvincia('MI', '{"versione":"0","provincia":"MI","impianti":[]}');
      var chiamate = 0;
      final repo = ProvinceRepository(
        baseUrl: 'https://prova',
        client: MockClient((_) async {
          chiamate++;
          return http.Response(_provinciaBuona, 200);
        }),
      );

      final esito = await repo.caricaProvincia('MI', impronta: improntaDi(_provinciaBuona));

      expect(chiamate, 1);
      expect(esito.$2, isTrue);
    });

    test('un file che non corrisponde alla sua impronta non viene creduto', () async {
      await LocalStore().salvaProvincia('MI', _provinciaBuona);
      // Il server risponde 200 con un file troncato che resta JSON valido.
      const troncato = '{"versione":"1","provincia":"MI","impianti":[]}  ';
      final repo = ProvinceRepository(
        baseUrl: 'https://prova',
        client: MockClient((_) async => http.Response(troncato, 200)),
      );

      final esito = await repo.caricaProvincia('MI', impronta: improntaDi('altro contenuto'));

      expect(esito.$1, isNotNull, reason: 'resta la copia buona');
      expect(esito.$2, isFalse, reason: 'e si dichiara che non è quella corrente');
      expect(await LocalStore().leggiProvincia('MI'), _provinciaBuona,
          reason: 'il file storto non deve finire sul disco');
    });

    test('senza impronta ci si comporta come prima', () async {
      var chiamate = 0;
      final repo = ProvinceRepository(
        baseUrl: 'https://prova',
        client: MockClient((_) async {
          chiamate++;
          return http.Response(_provinciaBuona, 200);
        }),
      );

      final esito = await repo.caricaProvincia('MI');

      expect(chiamate, 1);
      expect(esito.$2, isTrue);
    });
  });

  group('manifest', () {
    test('una risposta 200 che non è JSON non tocca il manifest di ieri', () async {
      var corpo = _manifestBuono;
      final repo = repoChe(() => corpo);

      expect(await repo.caricaManifest(), isNotNull);

      corpo = _paginaDiLogin;
      final oggi = await repo.caricaManifest();

      expect(oggi, isNotNull, reason: 'resta il manifest buono del giorno prima');
      expect(oggi!.province.single.sigla, 'MI');
    });

    test("un manifest salvato illeggibile non fa esplodere l'avvio", () async {
      await LocalStore().salvaProvincia('_manifest', 'roba a metà {');
      final repo = repoChe(() => _paginaDiLogin);

      expect(await repo.caricaManifest(), isNull);
    });
  });
}
