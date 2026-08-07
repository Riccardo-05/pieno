// Distanze su strada dal servizio percorsi (linee-guida/10-percorsi-e-backend.md, Fase 4).
//
// Il servizio sta su una macchina di casa **spenta dalle 02:00 alle 08:00**: sei ore su
// ventiquattro in cui non risponde. Quindi qui dentro non c'è nulla che dia per scontato
// che risponda — c'è un tetto di tempo, un ripiego sulla linea d'aria e la dichiarazione
// di quale dei due si sta mostrando. Esattamente come si fa già col dato salvato quando
// manca la rete: mai un numero senza dire da dove viene.

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/geo.dart';
import '../models/impianto.dart';
import 'location_service.dart';

/// Da dove viene la distanza mostrata. È il campo che permette all'app di
/// dirlo invece di far finta di niente.
enum OrigineDistanza {
  /// Calcolata sul grafo stradale dal servizio percorsi.
  strada,

  /// In linea d'aria: il servizio non ha risposto (di notte è spento).
  stima,
}

/// Distanza verso un impianto, con la sua provenienza.
class DistanzaImpianto {
  final double km;

  /// Tempo di percorrenza, solo quando la distanza è reale.
  final Duration? tempo;
  final OrigineDistanza origine;

  /// Vero quando la stima è stata corretta col fattore stradale dell'impianto
  /// (Fase 5): non è più la linea d'aria, e non va chiamata così.
  final bool corretta;

  const DistanzaImpianto({
    required this.km,
    this.tempo,
    required this.origine,
    this.corretta = false,
  });

  bool get reale => origine == OrigineDistanza.strada;
}

/// Il contratto: l'app parla a questo, non a OSRM e nemmeno all'HTTP.
/// Sostituire il servizio domani non tocca né le schermate né lo stato.
abstract class ServizioPercorsi {
  /// Distanze su strada dalla posizione agli impianti indicati, per id.
  /// Restituisce null quando il servizio non è disponibile: chi chiama ripiega.
  Future<Map<String, DistanzaImpianto>?> distanze(Posizione da, List<Impianto> verso);

  void dispose();
}

/// Client HTTP del servizio percorsi.
class PercorsiHttp implements ServizioPercorsi {
  /// Tetto di tempo: oltre questo si ripiega. Due secondi sono già tanti per
  /// una schermata che deve mostrare il primo prezzo utile in meno di un secondo.
  static const Duration tettoTempo = Duration(seconds: 2);

  /// Dopo un buco non si riprova subito. Di notte il servizio è spento per sei
  /// ore: bussare ogni volta scalderebbe la batteria senza cambiare nulla.
  static const Duration pausaDopoIlBuco = Duration(minutes: 10);

  /// Finché non ti sposti di questo, la risposta di prima va ancora bene.
  static const double sogliaSpostamentoKm = 0.3;

  /// Quante destinazioni per richiesta (il servizio ne accetta 100).
  static const int maxPerRichiesta = 100;

  /// Quante distanze si tengono da parte. Una provincia grande ha ~1300 impianti e
  /// l'utente ne guarda una frazione: oltre questo si stanno conservando risposte per
  /// posti dove non tornerà. Senza tetto la mappa cresceva per tutta la sessione, e
  /// l'unica cosa che la svuotava era spostarsi di trecento metri.
  static const int maxVociInCache = 2000;

  final String baseUrl;
  final http.Client _client;

  Posizione? _origineInCache;

  /// Distanze note, dalla più vecchia alla più recente: una `Map` in Dart conserva
  /// l'ordine d'inserimento, ed è quello che serve per sapere chi sfrattare.
  final Map<String, DistanzaImpianto> _cache = {};

  /// Fino a quando non vale la pena riprovare. Se è stato il servizio a dirlo, con
  /// `Retry-After`, si usa il suo numero; altrimenti la pausa lunga.
  DateTime? _nonPrimaDi;

  /// Quante distanze sono in memoria. Serve a poterlo verificare in un test.
  int get vociInCache => _cache.length;

  PercorsiHttp({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Il servizio è configurato? Senza dominio (Fase 3 non ancora chiusa) l'app
  /// non prova nemmeno, e resta sulla stima dichiarata.
  bool get configurato => baseUrl.isNotEmpty;

  @override
  Future<Map<String, DistanzaImpianto>?> distanze(Posizione da, List<Impianto> verso) async {
    if (!configurato) return null;

    final destinazioni = verso.where((i) => i.lat != null && i.lon != null).toList();
    if (destinazioni.isEmpty) return null;

    // 1. Ci si è spostati abbastanza da rifare le domande?
    final origine = _origineInCache;
    if (origine != null &&
        distanzaKm(origine.lat, origine.lon, da.lat, da.lon) > sogliaSpostamentoKm) {
      _cache.clear();
      _origineInCache = null;
    }

    final mancanti = destinazioni.where((i) => !_cache.containsKey(i.id)).toList();
    if (mancanti.isEmpty) return _daCache(destinazioni);

    // 2. Se il servizio ha appena taciuto, non lo si stuzzica di nuovo.
    final attesa = _nonPrimaDi;
    if (attesa != null && DateTime.now().isBefore(attesa)) {
      return _daCache(destinazioni);
    }

    // 3. Si chiede solo quello che manca, a blocchi.
    try {
      for (var inizio = 0; inizio < mancanti.length; inizio += maxPerRichiesta) {
        await _chiediBlocco(
          da,
          mancanti.sublist(inizio, math.min(inizio + maxPerRichiesta, mancanti.length)),
        );
      }
    } on _Rallenta catch (e) {
      // Il servizio non è rotto: sta dicendo quando ripassare. Ignorarlo e stare
      // zitti dieci minuti significherebbe rinunciare alle distanze vere per un
      // limite che magari scade fra tre secondi.
      _nonPrimaDi = DateTime.now().add(e.fra);
      return _daCache(destinazioni);
    } on Object {
      // Qualunque altro inciampo — servizio spento, rete assente, risposta storta —
      // porta allo stesso posto: si ripiega e lo si dice.
      _nonPrimaDi = DateTime.now().add(pausaDopoIlBuco);
      return _daCache(destinazioni);
    }

    _nonPrimaDi = null;
    _origineInCache = da;
    return _daCache(destinazioni);
  }

  /// Quel che si sa, per gli impianti chiesti. Null quando non si sa niente:
  /// così chi chiama passa alla stima senza distinguere i casi.
  Map<String, DistanzaImpianto>? _daCache(List<Impianto> destinazioni) {
    final esito = {
      for (final i in destinazioni)
        if (_cache.containsKey(i.id)) i.id: _cache[i.id]!,
    };
    return esito.isEmpty ? null : esito;
  }

  Future<void> _chiediBlocco(Posizione da, List<Impianto> blocco) async {
    final risposta = await _client
        .post(
          Uri.parse('$baseUrl/v1/distanze'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'origine': {'lat': da.lat, 'lon': da.lon},
            'destinazioni': [
              for (final i in blocco) {'lat': i.lat, 'lon': i.lon},
            ],
          }),
        )
        .timeout(tettoTempo);

    if (risposta.statusCode == 429) {
      throw _Rallenta(_quantoAspettare(risposta.headers['retry-after']));
    }
    if (risposta.statusCode != 200) {
      throw StateError('il servizio percorsi ha risposto ${risposta.statusCode}');
    }

    final corpo = jsonDecode(risposta.body) as Map<String, dynamic>;
    final lista = (corpo['distanze'] as List?) ?? const [];
    if (lista.length != blocco.length) {
      throw StateError('il servizio percorsi ha risposto con un numero di distanze diverso');
    }

    for (var k = 0; k < blocco.length; k++) {
      final voce = lista[k] as Map<String, dynamic>;
      if (voce['raggiungibile'] != true) continue; // resta alla stima, dichiarata
      _ricorda(
        blocco[k].id,
        DistanzaImpianto(
          km: (voce['metri'] as num).toDouble() / 1000,
          tempo: Duration(seconds: (voce['secondi'] as num).round()),
          origine: OrigineDistanza.strada,
        ),
      );
    }
  }

  /// Tiene una distanza, buttando la più vecchia quando lo spazio è finito.
  void _ricorda(String id, DistanzaImpianto distanza) {
    _cache.remove(id); // rientra in coda: è la più fresca
    _cache[id] = distanza;
    while (_cache.length > maxVociInCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Quanto aspettare secondo il servizio. Un valore assurdo o illeggibile vale come
  /// nessun valore: si torna alla pausa lunga, che è il ripiego prudente.
  Duration _quantoAspettare(String? retryAfter) {
    final secondi = int.tryParse((retryAfter ?? '').trim());
    if (secondi == null || secondi < 0 || secondi > pausaDopoIlBuco.inSeconds) {
      return pausaDopoIlBuco;
    }
    return Duration(seconds: secondi);
  }

  @override
  void dispose() => _client.close();
}

/// «Non sono rotto, sto solo chiedendo di rallentare»: il 429 del servizio, con il
/// tempo che lui stesso indica. Distinguerlo da un guasto è ciò che permette di
/// riprovare fra tre secondi invece che fra dieci minuti.
class _Rallenta implements Exception {
  final Duration fra;
  const _Rallenta(this.fra);
}

/// Stima della distanza quando il servizio non c'è: linea d'aria **corretta col
/// fattore stradale** dell'impianto, quando la Fase 5 l'ha misurato.
///
/// Resta una stima e viene dichiarata tale — ma con il fattore è una stima molto
/// meno sbagliata: sulla statale vale poco, di là dal fiume raddoppia i km, che è
/// esattamente quello che fa la strada vera.
DistanzaImpianto stimaInLineaDAria(Posizione da, Impianto i) {
  final aria = distanzaKm(da.lat, da.lon, i.lat!, i.lon!);
  final fattore = i.fattoreStradale;
  return DistanzaImpianto(
    km: fattore == null ? aria : aria * fattore,
    origine: OrigineDistanza.stima,
    corretta: fattore != null,
  );
}
