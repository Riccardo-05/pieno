// Stato condiviso (Riverpod). "Un solo stato, due rappresentazioni" (pag. 3):
// Mappa e Vicino a te leggono da qui. Per lo scheletro (Tappa 02) contiene il minimo:
// carburante selezionato, provincia corrente, dati caricati.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_service.dart';
import '../data/repository.dart';
import '../models/carburante.dart';
import '../models/impianto.dart';

/// URL pubblico della build dati. DA CONFIGURARE con l'hosting scelto (Tappa 01).
/// In sviluppo si può puntare a un server locale che serve build/public/.
const String kBaseUrlDati = 'https://riccardo-05.github.io/pieno';

final repositoryProvider = Provider<ProvinceRepository>((ref) {
  final repo = ProvinceRepository(baseUrl: kBaseUrlDati);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Carburante selezionato, condiviso tra le due viste. Default: benzina.
final carburanteProvider = StateProvider<Carburante>((ref) => Carburante.benzina);

/// Sigla provincia corrente. Per lo scheletro parte da un valore fisso; la scelta
/// per posizione arriva con la Tappa 03.
final provinciaProvider = StateProvider<String>((ref) => 'MI');

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

/// Le due viste che condividono lo stesso stato (pag. 3). Avvio previsto: Mappa,
/// ma finché la Mappa è un segnaposto (Tappa 04) l'avvio resta su Vicino a te.
enum Vista { mappa, vicino }

final vistaProvider = StateProvider<Vista>((ref) => Vista.vicino);

/// Posizione dell'utente per calcolare le distanze. Un solo fix, precisione bilanciata.
/// Se il permesso è negato resta null e le distanze non vengono mostrate.
final posizioneProvider = FutureProvider<Posizione?>((ref) async {
  try {
    return await LocationService().fixIniziale();
  } catch (_) {
    return null;
  }
});
