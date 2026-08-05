// Repository: scarica il file di provincia dalla CDN e lo tiene in cache locale.
// Offline-first: se la rete manca, usa l'ultimo dato salvato dichiarandone l'età
// ("l'app non mostra mai una schermata vuota", linee-guida/06-architettura.md).
//
// La sorgente è dietro un'interfaccia (baseUrl sostituibile), come da "regola di spesa".

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/impianto.dart';
import 'local_store.dart';

class ProvinceRepository {
  ProvinceRepository({
    required this.baseUrl,
    LocalStore? store,
    http.Client? client,
  })  : _store = store ?? LocalStore(),
        _client = client ?? http.Client();

  /// URL pubblico della build (manifest.json + province/{SIGLA}.json).
  /// DA CONFIGURARE quando l'hosting è scelto (GitHub Pages / Cloudflare Pages).
  final String baseUrl;
  final LocalStore _store;
  final http.Client _client;

  /// Carica una provincia: prova la rete, ricade sulla cache.
  /// [origineRete] indica se il dato viene dalla rete (true) o dal disco (false).
  Future<(DatiProvincia?, bool origineRete)> caricaProvincia(String sigla) async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/province/$sigla.json'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        await _store.salvaProvincia(sigla, resp.body);
        return (_parse(resp.body), true);
      }
    } catch (_) {
      // rete assente o errore: si prosegue con la cache
    }
    final salvato = await _store.leggiProvincia(sigla);
    if (salvato != null) return (_parse(salvato), false);
    return (null, false);
  }

  DatiProvincia _parse(String body) =>
      DatiProvincia.fromJson(jsonDecode(body) as Map<String, dynamic>);

  void dispose() => _client.close();
}
