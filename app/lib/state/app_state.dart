// Stato condiviso (Riverpod). "Un solo stato, due rappresentazioni" (pag. 3):
// Mappa e Vicino a te leggono da qui. Contiene carburante, provincia e dati caricati,
// le impostazioni persistite (ricerca, rifornimento, navigatore), la selezione condivisa
// fra le due viste e la coda locale di segnalazioni/valutazioni.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/location_service.dart';
import '../data/percorsi_repository.dart';
import '../data/repository.dart';
import '../domain/geo.dart';
import '../domain/risparmio.dart';
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

/// Consumo medio dell'auto in litri per 100 km (Impostazioni → Rifornimento).
/// È l'unico dato che serve per dire quanto costa andare più lontano.
final consumoProvider = StateProvider<double>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) => prefs.setDouble('consumo', next));
  return prefs.getDouble('consumo') ?? RisparmioConfig.consumoPredefinito;
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

/// Filtra gli impianti: devono avere il carburante scelto e — se richiesto e c'è la
/// posizione — stare entro il raggio.
///
/// Nessun filtro per età: la soglia sui listini abbandonati la applica la pipeline
/// (regola R5), quindi qui non arrivano proprio. Rifarla nell'app significava tarare due
/// volte la stessa decisione, con l'aggravante che la manopola nelle impostazioni poteva
/// stringere più della fonte e far sparire impianti perfettamente validi.
List<Impianto> filtra(
  List<Impianto> impianti,
  Carburante c, {
  Posizione? pos,
  double? raggioKm,
}) {
  return impianti.where((i) {
    final p = i.prezzoDi(c);
    if (p == null) return false;
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
  final filtrati = filtra(dati.impianti, c, pos: pos, raggioKm: raggio);
  return ordina(filtrati, c, ord, pos);
});

/// Media di riferimento del carburante scelto: quella **provinciale**, calcolata dalla
/// pipeline e servita nel file di provincia. È il termine di paragone del «risparmi X €
/// sul pieno» (config della pipeline: `risparmio.confronto: provincia`).
///
/// Perché non la media dell'elenco: l'elenco è filtrato per raggio ed età, quindi
/// allargando il raggio la media si spostava e il risparmio dichiarato cambiava a parità
/// di prezzo — un numero che si muove senza che si muova il mondo.
///
/// Ripiego sulla media dell'elenco solo per i file salvati prima che il campo esistesse.
final mediaRiferimentoProvider = Provider<double?>((ref) {
  final dati = ref.watch(datiProvinciaProvider).valueOrNull?.dati;
  final c = ref.watch(carburanteProvider);
  final provinciale = dati?.medie[c];
  if (provinciale != null) return provinciale;
  return mediaZona(ref.watch(elencoProvider), c);
});

/// Marcatori della mappa: filtrati per carburante ma NON per raggio — sulla mappa si
/// naviga tutta la provincia. Il raggio vale per l'elenco.
final marcatoriProvider = Provider<List<Impianto>>((ref) {
  final dati = ref.watch(datiProvinciaProvider).valueOrNull?.dati;
  if (dati == null) return const [];
  final c = ref.watch(carburanteProvider);
  return filtra(dati.impianti, c);
});

/// Le due viste che condividono lo stesso stato (pag. 3). L'avvio è sulla Mappa.
enum Vista { mappa, vicino }

final vistaProvider = StateProvider<Vista>((ref) => Vista.mappa);

/// Impianto selezionato, condiviso tra Mappa ed elenco (pag. 3, 13): toccare un
/// marcatore apre il foglio; tornando all'elenco resta lo stesso impianto. null = nessuno.
final selezionatoProvider = StateProvider<String?>((ref) => null);

/// Altezza corrente del foglio prezzi della mappa, come frazione dello schermo (0–1).
/// I comandi e lo switch flottante si posizionano SOPRA il foglio seguendo questo valore
/// (pag. 6: "lo switch resta sopra il foglio; se il foglio sale, scompare in dissolvenza").
/// Altezza di riposo del foglio, come frazione dello schermo: quella con cui la
/// Mappa si apre. Sta qui e non nella schermata perché è **la stessa misura** da
/// cui dipendono tre cose: l'altezza iniziale del foglio, la posizione dei
/// comandi flottanti che gli stanno appena sopra, e il calcolo del centro
/// visibile della mappa.
///
/// Quando era scritta due volte le due copie sono divergute (0,52 nel foglio,
/// 0,46 qui): all'avvio i comandi si posizionavano 6 punti percentuali più in
/// basso del bordo del foglio — una cinquantina di pixel — e ci finivano dentro
/// fino al primo trascinamento, che era l'unica cosa capace di riallinearli.
const double kFoglioMedio = 0.52;

final foglioExtentProvider = StateProvider<double>((ref) => kFoglioMedio);

/// Consenso dell'utente a usare la posizione, chiesto DENTRO l'app prima del dialogo
/// di sistema ("permessi graduali", pag. 13): null = mai chiesto, true = ha accettato,
/// false = ha detto di no. Persistito, così la spiegazione non si ripropone ogni volta.
final consensoPosizioneProvider = StateProvider<bool?>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) {
    if (next == null) {
      prefs.remove('consensoPosizione');
    } else {
      prefs.setBool('consensoPosizione', next);
    }
  });
  return prefs.getBool('consensoPosizione');
});

/// Posizione dell'utente per calcolare le distanze. Un solo fix, precisione bilanciata.
/// Il dialogo di sistema NON viene mai aperto prima che l'utente abbia visto la
/// spiegazione e abbia scelto di procedere. Senza consenso (o senza permesso) resta
/// null: l'app funziona lo stesso, solo senza distanze.
final posizioneProvider = FutureProvider<Posizione?>((ref) async {
  if (ref.watch(consensoPosizioneProvider) != true) return null;
  try {
    return await LocationService().fixIniziale();
  } catch (_) {
    return null;
  }
});

// ---- Distanze su strada (linee-guida/10-percorsi-e-backend.md, Fase 4). ----

/// URL del servizio percorsi.
///
/// Il valore predefinito è quello di produzione, non un segnaposto: una build
/// senza `--dart-define` deve funzionare, altrimenti basta dimenticare un flag
/// per pubblicare un'app che non chiede mai le distanze reali — e nessuno se ne
/// accorge, perché il ripiego sulla stima è silenzioso e legittimo.
///
/// Si scavalca per le prove, senza toccare il codice:
///   flutter run --dart-define=PIENO_PERCORSI=http://10.0.2.2:8080
/// Passando una stringa vuota l'app non contatta nulla e resta sulla stima.
const String kBaseUrlPercorsi = String.fromEnvironment(
  'PIENO_PERCORSI',
  defaultValue: 'https://percorsi.pienocarburanti.com',
);

final percorsiProvider = Provider<ServizioPercorsi>((ref) {
  final servizio = PercorsiHttp(baseUrl: kBaseUrlPercorsi);
  ref.onDispose(servizio.dispose);
  return servizio;
});

/// Distanze verso gli impianti dell'elenco: **su strada** quando il servizio
/// risponde, **in linea d'aria** quando no — e in entrambi i casi ognuna porta
/// scritto da dove viene, perché l'app lo possa dire invece di far finta.
///
/// Il servizio ha un tetto di due secondi e sta su una macchina spenta dalle
/// 02:00 alle 08:00: il ripiego non è un caso d'eccezione, è un quarto delle
/// giornate. Per questo non c'è nessun percorso in cui la schermata aspetti.
final distanzeProvider = FutureProvider<Map<String, DistanzaImpianto>>((ref) async {
  final pos = ref.watch(posizioneProvider).valueOrNull;
  if (pos == null) return const {};

  final elenco = ref.watch(elencoProvider);
  final suStrada = await ref.watch(percorsiProvider).distanze(pos, elenco) ?? const {};

  return {
    for (final i in elenco)
      if (i.lat != null && i.lon != null)
        i.id: suStrada[i.id] ?? stimaInLineaDAria(pos, i),
  };
});

/// Costo della deviazione per ogni impianto dell'elenco, in euro
/// (linee-guida/10-percorsi-e-backend.md, Fase 6).
///
/// Si paga rispetto **al più vicino**: chi è già il più vicino non deve niente,
/// gli altri pagano i chilometri in più andata e ritorno. Il risparmio mostrato
/// diventa netto, e in alcune zone la pastiglia sparirà — non è un peggioramento,
/// è l'app che smette di promettere risparmi che non esistono.
///
/// Finché le distanze sono stime in linea d'aria la deviazione resta a zero: un
/// numero calcolato col righello sarebbe una finta precisione, e il risparmio
/// lordo dichiarato è più onesto di un netto inventato.
final deviazioneProvider = Provider<Map<String, double>>((ref) {
  final distanze = ref.watch(distanzeProvider).valueOrNull;
  if (distanze == null || distanze.isEmpty) return const {};

  final suStrada = {
    for (final voce in distanze.entries)
      if (voce.value.reale) voce.key: voce.value.km,
  };
  if (suStrada.isEmpty) return const {};

  final piuVicino = suStrada.values.reduce(min);
  final consumo = ref.watch(consumoProvider);
  final carburante = ref.watch(carburanteProvider);
  final elenco = ref.watch(elencoProvider);

  return {
    for (final i in elenco)
      if (suStrada.containsKey(i.id) && i.prezzoDi(carburante) != null)
        i.id: costoDeviazione(
          kmImpianto: suStrada[i.id]!,
          kmPiuVicino: piuVicino,
          consumoLitriPer100km: consumo,
          prezzoAlLitro: i.prezzoDi(carburante)!.valore,
        ),
  };
});

// ---- Fiducia (Tappa 06). Segnalazioni e ritorno, persistiti localmente. ----

/// Coda locale delle segnalazioni di prezzo errato (inviate al backend quando esisterà).
final segnalazioniProvider = StateProvider<List<Segnalazione>>((ref) {
  final prefs = ref.watch(prefsProvider);
  ref.listenSelf((_, next) =>
      prefs.setStringList('segnalazioni', next.map((s) => jsonEncode(s.toJson())).toList()));
  final raw = prefs.getStringList('segnalazioni') ?? const [];
  try {
    return raw
        .map((s) => Segnalazione.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return <Segnalazione>[]; // preferenze corrotte: non bloccare l'avvio
  }
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
  try {
    return (jsonDecode(raw) as Map)
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
  } catch (_) {
    return <String, int>{}; // preferenze corrotte: non bloccare l'avvio
  }
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
  if (raw == null) return null;
  try {
    return Rientro.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null; // preferenze corrotte: non bloccare l'avvio
  }
});
