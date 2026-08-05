// Stato condiviso (Riverpod). "Un solo stato, due rappresentazioni" (pag. 3):
// Mappa e Vicino a te leggono da qui. Per lo scheletro (Tappa 02) contiene il minimo:
// carburante selezionato, provincia corrente, dati caricati.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/location_service.dart';
import '../data/repository.dart';
import '../domain/geo.dart';
import '../models/carburante.dart';
import '../models/impianto.dart';
import '../models/manifest.dart';
import '../models/navigatore.dart';
import '../models/segnalazione.dart';

/// URL pubblico della build dati. DA CONFIGURARE con l'hosting scelto (Tappa 01).
/// In sviluppo si può puntare a un server locale che serve build/public/.
const String kBaseUrlDati = 'https://riccardo-05.github.io/pieno';

final repositoryProvider = Provider<ProvinceRepository>((ref) {
  final repo = ProvinceRepository(baseUrl: kBaseUrlDati);
  ref.onDispose(repo.dispose);
  return repo;
});

/// SharedPreferences, iniettato in main() (persistenza delle impostazioni, Tappa 05).
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider va sovrascritto in main()'),
);

/// Carburante selezionato, condiviso tra le due viste. Persistito. Default: benzina.
final carburanteProvider = StateProvider<Carburante>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setString('carburante', next.chiave));
  return Carburante.values.firstWhere(
    (c) => c.chiave == prefs.getString('carburante'),
    orElse: () => Carburante.benzina,
  );
});

/// Manifest dei dati pubblici (province + baricentri). Rete → cache.
final manifestProvider = FutureProvider<Manifest?>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.caricaManifest();
});

/// Provincia di ripiego quando non c'è né override né posizione né manifest.
const String kProvinciaDefault = 'MI';

/// Override manuale della provincia (null = automatica dalla posizione).
final provinciaSceltaProvider = StateProvider<String?>((ref) => null);

/// Provincia EFFETTIVA: override manuale se impostato; altrimenti quella col
/// baricentro più vicino alla posizione (Tappa 04); altrimenti il default.
final provinciaProvider = Provider<String>((ref) {
  final scelta = ref.watch(provinciaSceltaProvider);
  if (scelta != null) return scelta;
  final pos = ref.watch(posizioneProvider).valueOrNull;
  final manifest = ref.watch(manifestProvider).valueOrNull;
  if (pos != null && manifest != null) {
    final sigla = manifest.provinciaPiuVicina(pos.lat, pos.lon);
    if (sigla != null) return sigla;
  }
  return kProvinciaDefault;
});

/// Esito del caricamento: i dati + se provengono dalla rete o dalla cache.
class EsitoDati {
  final DatiProvincia? dati;
  final bool origineRete;
  const EsitoDati(this.dati, this.origineRete);
}

final datiProvinciaProvider = FutureProvider<EsitoDati>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final sigla = ref.watch(provinciaProvider);
  final (dati, rete) = await repo.caricaProvincia(sigla);
  return EsitoDati(dati, rete);
});

/// Impianti ordinati per prezzo del carburante selezionato (base per "Vicino a te").
List<Impianto> ordinaPerPrezzo(List<Impianto> impianti, Carburante c) {
  final conPrezzo = impianti.where((i) => i.prezzoDi(c) != null).toList();
  conPrezzo.sort((a, b) => a.prezzoDi(c)!.valore.compareTo(b.prezzoDi(c)!.valore));
  return conPrezzo;
}

// ---- Impostazioni (Tappa 05), persistite su SharedPreferences. ----

/// Navigatore esterno per «Portami qui» (Impostazioni → Mappa e navigazione).
final navigatoreProvider = StateProvider<Navigatore>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setString('navigatore', next.name));
  return Navigatore.values.firstWhere(
    (n) => n.name == prefs.getString('navigatore'),
    orElse: () => Navigatore.sistema,
  );
});

/// Ordinamento dell'elenco (Impostazioni → Ricerca). Tre criteri:
/// prezzo (vince il più economico), bilanciato (media normalizzata prezzo+distanza),
/// distanza (vince il più vicino).
enum Ordinamento { prezzo, bilanciato, distanza }

extension OrdinamentoX on Ordinamento {
  String get etichetta => switch (this) {
        Ordinamento.prezzo => 'Prezzo',
        Ordinamento.bilanciato => 'Bilanciato',
        Ordinamento.distanza => 'Distanza',
      };
}

final ordinamentoProvider = StateProvider<Ordinamento>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setString('ordinamento', next.name));
  return Ordinamento.values.firstWhere(
    (o) => o.name == prefs.getString('ordinamento'),
    orElse: () => Ordinamento.prezzo,
  );
});

/// Raggio di ricerca in km (Impostazioni → Ricerca).
final raggioKmProvider = StateProvider<double>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setDouble('raggio', next));
  return prefs.getDouble('raggio') ?? 10;
});

/// Capacità del serbatoio in litri: base del «risparmio sul pieno» (Impostazioni → Rifornimento).
final capacitaLitriProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setInt('capacita', next));
  return prefs.getInt('capacita') ?? 50;
});

/// "Escludi dati più vecchi di" in giorni (Impostazioni → Ricerca).
final etaMassimaGiorniProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setInt('etaMassima', next));
  return prefs.getInt('etaMassima') ?? 30;
});

/// Avvisi sul percorso (Impostazioni → Mappa e navigazione).
final avvisiPercorsoProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setBool('avvisiPercorso', next));
  return prefs.getBool('avvisiPercorso') ?? false;
});

/// Ordina secondo il criterio scelto. Prezzo: crescente. Distanza: dal più vicino
/// (serve la posizione). Bilanciato: media delle due grandezze normalizzate 0–1 nella
/// zona (0 = migliore), così prezzo e distanza pesano allo stesso modo.
/// Senza posizione, distanza e bilanciato ricadono sul prezzo.
List<Impianto> ordina(List<Impianto> impianti, Carburante c, Ordinamento ord, Posizione? pos) {
  final lista = impianti.where((i) => i.prezzoDi(c) != null).toList();
  if (lista.isEmpty) return lista;

  double prezzo(Impianto i) => i.prezzoDi(c)!.valore;
  double dist(Impianto i) => (pos == null || i.lat == null || i.lon == null)
      ? double.infinity
      : distanzaKm(pos.lat, pos.lon, i.lat!, i.lon!);

  if (ord == Ordinamento.prezzo || pos == null) {
    lista.sort((a, b) => prezzo(a).compareTo(prezzo(b)));
    return lista;
  }
  if (ord == Ordinamento.distanza) {
    lista.sort((a, b) => dist(a).compareTo(dist(b)));
    return lista;
  }

  // Bilanciato: normalizza prezzo e distanza sull'intervallo della zona.
  final prezzi = lista.map(prezzo).toList();
  final dist2 = lista.map(dist).where((d) => d.isFinite).toList();
  final minP = prezzi.reduce(min), maxP = prezzi.reduce(max);
  final minD = dist2.isEmpty ? 0.0 : dist2.reduce(min);
  final maxD = dist2.isEmpty ? 0.0 : dist2.reduce(max);
  double norma(double v, double mn, double mx) => mx > mn ? (v - mn) / (mx - mn) : 0.0;
  double punteggio(Impianto i) {
    final d = dist(i);
    final nd = d.isFinite ? norma(d, minD, maxD) : 1.0;
    return (norma(prezzo(i), minP, maxP) + nd) / 2;
  }

  lista.sort((a, b) => punteggio(a).compareTo(punteggio(b)));
  return lista;
}

/// Filtra gli impianti: devono avere il carburante scelto; il dato non più vecchio
/// della soglia (escludi età); e — se richiesto e c'è la posizione — entro il raggio.
List<Impianto> filtra(
  List<Impianto> impianti,
  Carburante c, {
  Posizione? pos,
  double? raggioKm,
  int? etaMaxGiorni,
}) {
  final ora = DateTime.now();
  return impianti.where((i) {
    final p = i.prezzoDi(c);
    if (p == null) return false;
    if (etaMaxGiorni != null) {
      final t = p.comunicatoIl;
      if (t == null || ora.difference(t).inDays > etaMaxGiorni) return false;
    }
    if (raggioKm != null && pos != null && i.lat != null && i.lon != null) {
      if (distanzaKm(pos.lat, pos.lon, i.lat!, i.lon!) > raggioKm) return false;
    }
    return true;
  }).toList();
}

/// Elenco per "Vicino a te" e per il foglio della Mappa: filtrato (carburante, età,
/// raggio) e ordinato secondo il criterio scelto. Un'unica fonte per tutte le viste.
final elencoProvider = Provider<List<Impianto>>((ref) {
  final dati = ref.watch(datiProvinciaProvider).valueOrNull?.dati;
  if (dati == null) return const [];
  final c = ref.watch(carburanteProvider);
  final pos = ref.watch(posizioneProvider).valueOrNull;
  final ord = ref.watch(ordinamentoProvider);
  final raggio = ref.watch(raggioKmProvider);
  final eta = ref.watch(etaMassimaGiorniProvider);
  final filtrati = filtra(dati.impianti, c, pos: pos, raggioKm: raggio, etaMaxGiorni: eta);
  return ordina(filtrati, c, ord, pos);
});

/// Marcatori della mappa: filtrati per carburante ed età (attendibilità), ma NON per
/// raggio — sulla mappa si naviga tutta la provincia. Il raggio vale per l'elenco.
final marcatoriProvider = Provider<List<Impianto>>((ref) {
  final dati = ref.watch(datiProvinciaProvider).valueOrNull?.dati;
  if (dati == null) return const [];
  final c = ref.watch(carburanteProvider);
  final eta = ref.watch(etaMassimaGiorniProvider);
  return filtra(dati.impianti, c, etaMaxGiorni: eta);
});

/// Le due viste che condividono lo stesso stato (pag. 3). Avvio previsto: Mappa,
/// ma finché la Mappa è un segnaposto (Tappa 04) l'avvio resta su Vicino a te.
enum Vista { mappa, vicino }

final vistaProvider = StateProvider<Vista>((ref) => Vista.mappa);

/// Impianto selezionato, condiviso tra Mappa ed elenco (pag. 3, 13): toccare un
/// marcatore apre il foglio; tornando all'elenco resta lo stesso impianto. null = nessuno.
final selezionatoProvider = StateProvider<String?>((ref) => null);

/// True quando il foglio della mappa è alzato: lo switch flottante sfuma (pag. 6).
final foglioEspansoProvider = StateProvider<bool>((ref) => false);

/// Posizione dell'utente per calcolare le distanze. Un solo fix, precisione bilanciata.
/// Se il permesso è negato resta null e le distanze non vengono mostrate.
final posizioneProvider = FutureProvider<Posizione?>((ref) async {
  try {
    return await LocationService().fixIniziale();
  } catch (_) {
    return null;
  }
});

// ---- Fiducia (Tappa 06). Segnalazioni e ritorno, persistiti localmente. ----

/// Coda locale delle segnalazioni di prezzo errato (inviate al backend quando esisterà).
final segnalazioniProvider = StateProvider<List<Segnalazione>>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) =>
      prefs.setStringList('segnalazioni', next.map((s) => jsonEncode(s.toJson())).toList()));
  final raw = prefs.getStringList('segnalazioni') ?? const [];
  return raw
      .map((s) => Segnalazione.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();
});

void aggiungiSegnalazione(WidgetRef ref, Segnalazione s) {
  ref.read(segnalazioniProvider.notifier).update((l) => [...l, s]);
}

/// Valutazioni a stelle INTERNE dell'utente, per impianto (1–5), salvate localmente.
/// Le valutazioni ESTERNE (Google ecc.) richiedono un'API: verranno mostrate per prime
/// quando ci saranno; per ora esiste solo la valutazione interna. Vedi StelleValutazione.
final valutazioniProvider = StateProvider<Map<String, int>>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setString('valutazioni', jsonEncode(next)));
  final raw = prefs.getString('valutazioni');
  if (raw == null) return <String, int>{};
  return (jsonDecode(raw) as Map)
      .map((k, v) => MapEntry(k as String, (v as num).toInt()));
});

void valuta(WidgetRef ref, String impiantoId, int stelle) {
  ref.read(valutazioniProvider.notifier).update((m) {
    final n = Map<String, int>.from(m);
    if (stelle <= 0) {
      n.remove(impiantoId);
    } else {
      n[impiantoId] = stelle;
    }
    return n;
  });
}

/// Rifornimento in sospeso (impostato da «Portami qui», chiesto al ritorno).
final rientroProvider = StateProvider<Rientro?>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) {
    if (next == null) {
      prefs.remove('rientro');
    } else {
      prefs.setString('rientro', jsonEncode(next.toJson()));
    }
  });
  final raw = prefs.getString('rientro');
  return raw == null ? null : Rientro.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
