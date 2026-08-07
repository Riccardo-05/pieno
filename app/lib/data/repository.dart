// Repository: scarica il file di provincia dalla CDN e lo tiene in cache locale.
// Offline-first: se la rete manca, usa l'ultimo dato salvato dichiarandone l'età
// ("l'app non mostra mai una schermata vuota", linee-guida/06-architettura.md).
//
// La sorgente è dietro un'interfaccia (baseUrl sostituibile), come da "regola di spesa".
//
// Regola che tiene in piedi la promessa: **si salva solo ciò che si è riusciti a
// leggere**. Uno stato 200 non basta a dire che il corpo sia il nostro file — il
// captive portal di un bar risponde 200 con la sua pagina di login, e prima quella
// finiva sopra il dato buono del giorno prima, che spariva per sempre. E la lettura
// dal disco sta dentro lo stesso riparo: una cache lasciata a metà da un'app uccisa
// mentre scriveva non deve impedire l'avvio, deve solo essere buttata.

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/impianto.dart';
import '../models/manifest.dart';
import 'local_store.dart';

class ProvinceRepository {
  ProvinceRepository({
    required this.baseUrl,
    LocalStore? store,
    http.Client? client,
  })  : _store = store ?? LocalStore(),
        _client = client ?? http.Client();

  /// URL pubblico della build (manifest.json + province/{SIGLA}.json).
  final String baseUrl;
  final LocalStore _store;
  final http.Client _client;

  /// Carica una provincia: prova la rete, ricade sulla cache.
  /// [origineRete] indica se il dato viene dalla rete (true) o dal disco (false).
  Future<(DatiProvincia?, bool origineRete)> caricaProvincia(String sigla) async {
    final dallaRete = await _scarica('province/$sigla.json', DatiProvincia.fromJson);
    if (dallaRete != null) {
      await _store.salvaProvincia(sigla, dallaRete.grezzo);
      return (dallaRete.valore, true);
    }
    return (await _dallaCache(sigla, DatiProvincia.fromJson), false);
  }

  /// Carica il manifest (elenco province + baricentri): rete → cache.
  Future<Manifest?> caricaManifest() async {
    final dallaRete = await _scarica('manifest.json', Manifest.fromJson);
    if (dallaRete != null) {
      await _store.salvaProvincia('_manifest', dallaRete.grezzo);
      return dallaRete.valore;
    }
    return _dallaCache('_manifest', Manifest.fromJson);
  }

  /// Scarica e **legge** una risorsa. Null quando la rete manca, quando lo stato non
  /// è 200 o quando il corpo non è il file che ci aspettiamo: in tutti e tre i casi
  /// chi chiama ripiega sulla cache, che qui non è ancora stata toccata.
  Future<_Scaricato<T>?> _scarica<T>(
      String risorsa, T Function(Map<String, dynamic>) leggi) async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/$risorsa'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      return _Scaricato(leggi(_json(resp.body)), resp.body);
    } catch (_) {
      // Rete assente, stato storto o corpo illeggibile: si prosegue con la cache.
      return null;
    }
  }

  /// Legge dal disco. Se quel che c'è non si lascia leggere lo cancella: tenerlo
  /// significherebbe ripresentare lo stesso errore a ogni avvio.
  Future<T?> _dallaCache<T>(String nome, T Function(Map<String, dynamic>) leggi) async {
    final salvato = await _store.leggiProvincia(nome);
    if (salvato == null) return null;
    try {
      return leggi(_json(salvato));
    } catch (_) {
      await _store.rimuoviProvincia(nome);
      return null;
    }
  }

  Map<String, dynamic> _json(String corpo) => jsonDecode(corpo) as Map<String, dynamic>;

  void dispose() => _client.close();
}

/// Una risorsa letta con successo, insieme al testo esatto da mettere in cache.
class _Scaricato<T> {
  final T valore;
  final String grezzo;
  const _Scaricato(this.valore, this.grezzo);
}
