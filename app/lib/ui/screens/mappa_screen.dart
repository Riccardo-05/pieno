// Schermata 2 — Mappa (pag. 6, 13). Tappa 04.
// Stile personalizzato (assets/map_style.json), marcatori-prezzo come layer di simboli
// con gestione delle collisioni (non widget). Foglio inferiore ridimensionabile,
// selezione condivisa con l'elenco, comandi tondi a destra.
//
// Il foglio è un pannello SOVRAPPOSTO alla mappa (vedi _foglio): box e lista scorrevole
// sono due pezzi distinti, e su quella giuntura vivono i difetti storici di questa
// schermata — vedi _fisicaFoglio (banda bianca da overscroll) e presa_foglio.dart.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../data/navigator_launcher.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/formato.dart';
import '../../domain/geo.dart';
import '../../domain/geojson.dart';
import '../../domain/risparmio.dart';
import '../../models/carburante.dart';
import '../../models/impianto.dart';
import '../../models/segnalazione.dart';
import '../../state/app_state.dart';
import '../components/carburante_selettore.dart';
import '../components/ordinamento_shortcut.dart';
import '../components/pulsante_tondo.dart';
import '../components/scheda_impianto.dart';
import '../components/switch_pillola.dart';
import '../map/attribuzione_mappa.dart';
import '../map/pillole.dart';
import '../map/presa_foglio.dart';
import 'impostazioni_screen.dart';
import 'segnala_sheet.dart';

const _sorgente = 'prezzi';
const _layers = ['prezzi-testo', 'prezzi-migliore', 'prezzi-selezionato'];
// Layer selezionabili (i cluster no: si aprono con lo zoom, non si selezionano).
const _layersToccabili = {'prezzi-testo', 'prezzi-migliore', 'prezzi-selezionato'};

// Altezze del foglio prezzi (frazioni di schermo): chiuso (mostra prezzo + risparmio),
// medio, aperto. Il default è "medio", così di norma si vedono prezzo e risparmio.
const double _foglioMin = 0.30;
const double _foglioMedio = 0.46;
const double _foglioMax = 0.92;

// Quante righe mostrare sotto la scheda. L'elenco completo di una provincia arriva a
// ~1300 impianti: oltre le prime decine nessuno scorre, e il foglio diventa un muro di
// numeri. Il resto della provincia si guarda sulla mappa, che è la sua rappresentazione.
const int _maxRigheFoglio = 35;

/// Rimbalzo iOS **solo verso il basso**. Quando il foglio ha già toccato [_foglioMin] non
/// può rimpicciolirsi oltre e `DraggableScrollableSheet` gira il resto del gesto alla
/// lista come scorrimento normale: col rimbalzo di serie la lista sconfina sopra il primo
/// elemento, il contenuto scivola in basso e resta scoperto lo sfondo del foglio sopra la
/// maniglia (la banda bianca, tanto più alta quanto più violento è il gesto).
///
/// Qui si blocca il solo sconfinamento **in testa**, dove nasce la banda; in coda resta il
/// rimbalzo di `BouncingScrollPhysics`, che è ciò che dà la sensazione di precisione.
class _FisicaFoglio extends BouncingScrollPhysics {
  const _FisicaFoglio({super.parent});

  @override
  _FisicaFoglio applyTo(ScrollPhysics? ancestor) =>
      _FisicaFoglio(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Già oltre il bordo di testa e si continua a salire: consuma tutto lo spostamento.
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    // Sta per superare il bordo di testa: consuma la sola parte eccedente.
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    return super.applyBoundaryConditions(position, value); // in coda: rimbalzo
  }
}

// AlwaysScrollable tiene la lista sempre trascinabile anche a contenuto corto, così il
// gesto continua a comandare l'altezza del foglio.
const ScrollPhysics _fisicaFoglio =
    AlwaysScrollableScrollPhysics(parent: _FisicaFoglio());

class MappaScreen extends ConsumerStatefulWidget {
  const MappaScreen({super.key});

  @override
  ConsumerState<MappaScreen> createState() => _MappaScreenState();
}

class _MappaScreenState extends ConsumerState<MappaScreen> {
  MapLibreMapController? _controller;
  String? _stile;
  bool _stilePronto = false;
  bool _movimentoProgrammatico = false;
  bool _mostraCerca = false;
  String? _provinciaCentrata; // per ricentrare solo al cambio di provincia
  final _sheetController = DraggableScrollableController();
  bool _boxMossoDallaPresa = false; // il gesto sulla scheda ha mosso il box, non la lista

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map_style.json').then((s) {
      if (mounted) setState(() => _stile = s);
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;

    // Puntino "sono qui" (pag. 4: solo il blu posizione #2F6BFF), stile mappe:
    // alone tenue + punto pieno con bordo bianco. Sotto ai marcatori-prezzo.
    await c.addSource('posizione',
        const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}));
    await c.addCircleLayer(
      'posizione',
      'pos-alone',
      const CircleLayerProperties(circleRadius: 22, circleColor: '#2F6BFF', circleOpacity: 0.15),
    );
    await c.addCircleLayer(
      'posizione',
      'pos-punto',
      const CircleLayerProperties(
        circleRadius: 7,
        circleColor: '#2F6BFF',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );

    // Sorgente con raggruppamento: sotto lo zoom 12 i punti si raggruppano e il cluster
    // mostra il minimo della zona (pag. 13: "da 2,059", non il conteggio).
    await c.addSource(
      _sorgente,
      const GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': []},
        cluster: true,
        clusterMaxZoom: 12,
        clusterRadius: 50, // più stretto: meno raggruppamenti spuri di poche stazioni
        clusterProperties: {
          'min': ['min', ['get', 'prezzoNum']],
        },
      ),
    );
    // Sorgente separata per il solo impianto selezionato (non raggruppata): aggiornarla
    // costa una feature, non l'intera provincia → nessun lag al tocco di un marcatore.
    await c.addSource('selezione',
        const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}));
    // Pillole come sfondo dei prezzi (pag. 6): bianca 94% i normali, gradiente menta il
    // più conveniente (e i cluster), inchiostro il selezionato. Con icon-text-fit la
    // pillola si adatta SEMPRE al testo, su ogni densità di schermo: niente misure fisse
    // che escono dallo sfondo (bug iPhone).
    await c.addImage('pill-bianca', await disegnaPillola(menta: false, bordo: true));
    await c.addImage('pill-menta', await disegnaPillola(menta: true));
    // Cluster: menta scura piena (più saturo del gradiente) → il testo bianco stacca
    // meglio e i cluster si distinguono dal marcatore "migliore".
    await c.addImage(
        'pill-cluster', await disegnaPillola(menta: false, tinta: PienoColors.mentaScura));
    await c.addImage('pill-selezionata',
        await disegnaPillola(menta: false, bordo: true, tinta: PienoColors.inchiostro));

    // Marcatori non raggruppati (hanno prezzo solo i punti singoli).
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-testo',
      const SymbolLayerProperties(
        iconImage: 'pill-bianca',
        iconTextFit: 'both',
        iconTextFitPadding: [3, 12, 3, 12],
        iconAllowOverlap: false,
        textField: '{prezzo}',
        textSize: 15,
        textFont: ['Noto Sans Regular'],
        textColor: '#0E1620',
        textAllowOverlap: false,
      ),
      filter: [
        'all',
        ['!=', ['get', 'migliore'], true],
        ['!', ['has', 'point_count']],
      ],
    );
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-migliore',
      const SymbolLayerProperties(
        iconImage: 'pill-menta',
        iconTextFit: 'both',
        iconTextFitPadding: [3, 12, 3, 12],
        iconAllowOverlap: true,
        textField: '{prezzo}',
        textSize: 17,
        textFont: ['Noto Sans Regular'],
        textColor: '#FFFFFF',
        textAllowOverlap: true,
      ),
      filter: [
        'all',
        ['==', ['get', 'migliore'], true],
        ['!', ['has', 'point_count']],
      ],
    );
    // Cluster: pillola menta con il prezzo minimo della zona ("da 1,8xx").
    await c.addSymbolLayer(
      _sorgente,
      'cluster-testo',
      const SymbolLayerProperties(
        iconImage: 'pill-cluster',
        iconTextFit: 'both',
        iconTextFitPadding: [4, 12, 4, 12],
        iconAllowOverlap: true,
        // Niente 'number-format': su MapLibre nativo iOS non è supportato come sul web
        // e mandava in crash l'app. 'to-string' del minimo (già a 3 decimali) è sicuro.
        textField: ['concat', 'da ', ['to-string', ['get', 'min']]],
        textFont: ['Noto Sans Regular'],
        textSize: 13,
        textColor: '#FFFFFF',
        textAllowOverlap: true,
      ),
      filter: ['has', 'point_count'],
    );
    // Selezionato per ultimo: sta sopra a tutti gli altri e non cede mai il posto alle
    // collisioni. È l'impianto aperto nel foglio: deve restare visibile per definizione.
    await c.addSymbolLayer(
      'selezione',
      'prezzi-selezionato',
      const SymbolLayerProperties(
        iconImage: 'pill-selezionata',
        iconTextFit: 'both',
        iconTextFitPadding: [4, 13, 4, 13],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        textField: '{prezzo}',
        textSize: 17,
        textFont: ['Noto Sans Regular'],
        textColor: '#FFFFFF',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );
    _stilePronto = true;
    c.onFeatureTapped.add((point, latLng, featureId, layerId, annotation) {
      // I cluster e gli altri layer non si selezionano.
      if (!_layersToccabili.contains(layerId)) return;
      final diretto = featureId.isNotEmpty ? featureId : null;
      if (diretto != null) {
        _toggleSelezione(diretto); // via veloce: id già nel callback, niente query
        return;
      }
      // Ripiego se l'id della feature non fosse disponibile: interroga la mappa.
      c.queryRenderedFeatures(point, _layers, null).then((feats) {
        if (feats.isEmpty) return;
        final id = ((feats.first as Map)['properties'] as Map?)?['id'];
        if (id != null) _toggleSelezione(id as String);
      });
    });
    await _aggiornaSorgente();
    await _aggiornaPosizione();
    await _aggiornaSelezione();
  }

  void _toggleSelezione(String id) {
    HapticFeedback.selectionClick();
    // Ritoccando la stazione già selezionata la si deseleziona.
    final corrente = ref.read(selezionatoProvider);
    ref.read(selezionatoProvider.notifier).state = corrente == id ? null : id;
  }

  // Aggiorna SOLO la sorgente del selezionato (una feature): niente lag al tocco.
  Future<void> _aggiornaSelezione() async {
    final c = _controller;
    if (c == null || !_stilePronto) return;
    final imp = _trova(ref.read(marcatoriProvider), ref.read(selezionatoProvider));
    await c.setGeoJsonSource('selezione', geoJsonUno(imp, ref.read(carburanteProvider)));
  }

  Future<void> _aggiornaPosizione() async {
    final c = _controller;
    if (c == null || !_stilePronto) return;
    final pos = ref.read(posizioneProvider).valueOrNull;
    if (pos == null) return;
    await c.setGeoJsonSource('posizione', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [pos.lon, pos.lat],
          },
          'properties': <String, dynamic>{},
        }
      ],
    });
  }

  Future<void> _aggiornaSorgente() async {
    final c = _controller;
    if (c == null || !_stilePronto) return;
    final marcatori = ref.read(marcatoriProvider);
    final carburante = ref.read(carburanteProvider);
    if (marcatori.isEmpty) {
      await c.setGeoJsonSource(_sorgente, {'type': 'FeatureCollection', 'features': []});
      return;
    }
    // Il marcatore "migliore" (pillola menta) è il primo secondo il criterio scelto
    // (prezzo, bilanciato o distanza): così la mappa reagisce al cambio di ordinamento.
    final ord = ref.read(ordinamentoProvider);
    final pos = ref.read(posizioneProvider).valueOrNull;
    final ordinati = ordina(marcatori, carburante, ord, pos);
    final geo = geoJsonPrezzi(marcatori, carburante, idMigliore: ordinati.first.id);
    await c.setGeoJsonSource(_sorgente, geo);

    // Ricentra solo quando cambia la provincia (non a ogni cambio di ordinamento).
    final provincia = ref.read(provinciaProvider);
    if (provincia != _provinciaCentrata) {
      _centra(ordinati);
      _provinciaCentrata = provincia;
    }
  }

  void _centra(List<Impianto> ordinati) {
    final c = _controller;
    if (c == null || ordinati.isEmpty) return;
    final pos = ref.read(posizioneProvider).valueOrNull;
    final grezzo = pos != null
        ? LatLng(pos.lat, pos.lon)
        : LatLng(ordinati.first.lat ?? 41.9, ordinati.first.lon ?? 12.5);
    _movimentoProgrammatico = true;
    c.animateCamera(CameraUpdate.newLatLngZoom(_centroVisibile(grezzo, 11), 11));
  }

  /// Porta in vista l'impianto selezionato, ma **solo se è fuori schermo**: chi ha
  /// appena toccato un marcatore non si vede scappare la mappa sotto il dito, mentre
  /// chi seleziona dall'elenco lo ritrova centrato (pag. 3: "un solo stato, due
  /// rappresentazioni").
  Future<void> _mostraSelezionato(String? id) async {
    final c = _controller;
    if (c == null || id == null || !_stilePronto) return;
    final imp = _trova(ref.read(marcatoriProvider), id);
    if (imp?.lat == null || imp?.lon == null) return;
    final punto = LatLng(imp!.lat!, imp.lon!);

    final zoom = c.cameraPosition?.zoom ?? 11;
    bool visibile = false;
    try {
      final area = await c.getVisibleRegion();
      visibile = punto.latitude >= area.southwest.latitude &&
          punto.latitude <= area.northeast.latitude &&
          punto.longitude >= area.southwest.longitude &&
          punto.longitude <= area.northeast.longitude;
    } catch (_) {
      // Regione non disponibile: meglio non muovere la mappa che muoverla a sproposito.
      return;
    }
    if (visibile && zoom >= 12) return;

    _movimentoProgrammatico = true;
    final zoomFinale = zoom < 12 ? 13.0 : zoom;
    await c.animateCamera(
      CameraUpdate.newLatLngZoom(_centroVisibile(punto, zoomFinale), zoomFinale),
    );
  }

  void _vaiAllaPosizione() {
    final pos = ref.read(posizioneProvider).valueOrNull;
    if (pos != null) {
      HapticFeedback.selectionClick();
      _movimentoProgrammatico = true;
      // Zoom 15 (livello via): ben oltre lo zoom dei cluster (12), così intorno a te
      // vedi i singoli distributori, non i raggruppamenti.
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_centroVisibile(LatLng(pos.lat, pos.lon), 15), 15));
    }
  }

  // Centro-camera che fa apparire [target] al centro della porzione di mappa VISIBILE,
  // cioè la fascia fra la parte alta (sotto notch/comandi) e il bordo superiore del foglio.
  // La camera mette il proprio centro a metà schermo (H/2); per portare target al centro
  // della fascia visibile [topPx, H − foglioPx] lo si sposta a sud di (foglioPx − topPx)/2
  // pixel. Calcolo geografico → funziona su web e su nativo, con qualsiasi altezza foglio.
  LatLng _centroVisibile(LatLng target, double zoom) {
    final mq = MediaQuery.of(context);
    final foglioPx = mq.size.height * ref.read(foglioExtentProvider);
    final topPx = mq.padding.top + 8;
    final salitaPx = (foglioPx - topPx) / 2; // di quanto il punto deve salire sullo schermo
    if (salitaPx <= 0) return target;
    // Metri per pixel alla latitudine e zoom dati. MapLibre usa tile da 512px, quindi la
    // risoluzione è metà della classica formula a 256px (78271.5 = 156543.0 / 2): senza
    // questa correzione lo spostamento risultava doppio e il pallino finiva troppo in alto.
    final mppx = 78271.51696 * cos(target.latitude * pi / 180) / pow(2, zoom);
    final dLat = salitaPx * mppx / 111320.0; // pixel → metri → gradi di latitudine
    return LatLng(target.latitude - dLat, target.longitude);
  }

  // La mappa si è fermata. Offri "Cerca in questa zona" SOLO se il centro mappa cade in
  // una provincia diversa da quella caricata: altrimenti il pulsante non farebbe nulla
  // (e comparirebbe di continuo). Così appare di rado e ha sempre un effetto.
  void _onCameraIdle() {
    if (_movimentoProgrammatico) {
      _movimentoProgrammatico = false;
      return;
    }
    if (!mounted) return;
    final centro = _controller?.cameraPosition?.target;
    final manifest = ref.read(manifestProvider).valueOrNull;
    final corrente = ref.read(provinciaProvider);
    final vicina = (centro != null && manifest != null)
        ? manifest.provinciaPiuVicina(centro.latitude, centro.longitude)
        : null;
    final diversa = vicina != null && vicina != corrente;
    if (_mostraCerca != diversa) setState(() => _mostraCerca = diversa);
  }

  // Passa alla provincia il cui baricentro è più vicino al centro mappa corrente.
  void _cercaInQuestaZona() {
    setState(() => _mostraCerca = false);
    final centro = _controller?.cameraPosition?.target;
    final manifest = ref.read(manifestProvider).valueOrNull;
    if (centro == null || manifest == null) return;
    final sigla = manifest.provinciaPiuVicina(centro.latitude, centro.longitude);
    if (sigla != null) {
      HapticFeedback.lightImpact();
      // Segna la provincia come "già centrata": al ricarico i marcatori si aggiornano ma
      // la mappa RESTA sull'area che stai guardando, senza saltare alla tua posizione.
      _provinciaCentrata = sigla;
      ref.read(provinciaSceltaProvider.notifier).state = sigla;
    }
  }

  Future<void> _portamiQui(Impianto i) async {
    if (i.lat == null || i.lon == null) return;
    // Prepara il ritorno dopo il rifornimento.
    final prezzo = i.prezzoDi(ref.read(carburanteProvider))?.valore ?? 0;
    ref.read(rientroProvider.notifier).state = Rientro(
      impiantoId: i.id,
      nome: i.nome,
      prezzoMostrato: prezzo,
      quando: DateTime.now(),
    );
    final ok = await portamiQui(i.lat!, i.lon!, navigatore: ref.read(navigatoreProvider));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il navigatore.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(marcatoriProvider, (_, __) {
      _aggiornaSorgente();
      _aggiornaSelezione();
    });
    ref.listen(ordinamentoProvider, (_, __) => _aggiornaSorgente());
    ref.listen(selezionatoProvider, (_, id) {
      _aggiornaSelezione(); // leggero: aggiorna solo la sorgente della selezione
      _mostraSelezionato(id);
      // Toccando un marcatore, apri il foglio almeno all'altezza "media".
      if (id != null &&
          _sheetController.isAttached &&
          _sheetController.size < _foglioMedio - 0.01) {
        _sheetController.animateTo(_foglioMedio,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
    ref.listen(posizioneProvider, (prev, next) {
      // Ignora le transizioni di stato (es. "loading" quando si dà il consenso): reagisci
      // solo quando cambia davvero la posizione. Evita ricostruzioni pesanti a vuoto.
      if (prev?.valueOrNull == next.valueOrNull) return;
      _aggiornaPosizione();
      _aggiornaSorgente();
    });

    if (_stile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final schermo = MediaQuery.of(context);
    final topSicuro = schermo.padding.top + 8; // sotto Dynamic Island / notch
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              styleString: _stile!,
              initialCameraPosition:
                  const CameraPosition(target: LatLng(41.9, 12.5), zoom: 5),
              onMapCreated: (c) => _controller = c,
              onStyleLoadedCallback: _onStyleLoaded,
              onCameraIdle: _onCameraIdle,
              trackCameraPosition: true,
              myLocationEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
          ),
          // Comandi flottanti: stanno SOPRA il foglio e ne seguono l'altezza. In un
          // Consumer isolato, così la mappa non si ridisegna a ogni frame del trascinamento.
          Positioned.fill(child: _controlli(topSicuro)),
          _foglio(),
        ],
      ),
    );
  }

  Widget _controlli(double topSicuro) {
    return Consumer(
      builder: (context, ref, _) {
        final h = MediaQuery.of(context).size.height;
        final ext = ref.watch(foglioExtentProvider);
        final sopraFoglio = h * ext + 12;
        final espanso = ext > 0.66; // foglio quasi aperto: i comandi bassi sfumano
        return Stack(
          children: [
            Positioned(
              top: topSicuro,
              left: PienoSpacing.margineLaterale,
              child: const OrdinamentoShortcut(),
            ),
            Positioned(
              top: topSicuro,
              right: PienoSpacing.margineLaterale,
              child: const CarburanteSelettore(),
            ),
            if (_mostraCerca)
              Positioned(
                top: topSicuro + 52,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: PienoColors.inchiostro,
                    borderRadius: BorderRadius.circular(PienoRadii.pillola),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(PienoRadii.pillola),
                      onTap: _cercaInQuestaZona,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text('Cerca in questa zona',
                            style: PienoText.voceImpostazione
                                .copyWith(color: const Color(0xFFFFFFFF))),
                      ),
                    ),
                  ),
                ),
              ),
            // Attribuzione obbligatoria e comandi tondi: appena SOPRA il foglio; sfumano
            // quando il foglio è quasi aperto per non finire sopra i controlli in alto.
            Positioned(
              left: PienoSpacing.margineLaterale,
              bottom: sopraFoglio,
              child: IgnorePointer(
                ignoring: espanso,
                child: AnimatedOpacity(
                  opacity: espanso ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: const AttribuzioneMappa(),
                ),
              ),
            ),
            Positioned(
              right: PienoSpacing.margineLaterale,
              bottom: sopraFoglio,
              child: IgnorePointer(
                ignoring: espanso,
                child: AnimatedOpacity(
                  opacity: espanso ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Column(
                    children: [
                      PulsanteTondo(
                        icona: const Icon(Icons.tune, size: 22, color: PienoColors.inchiostro),
                        onTap: () => Navigator.of(context).push(ImpostazioniScreen.rotta()),
                      ),
                      const SizedBox(height: 12),
                      PulsanteTondo(
                        icona: const Icon(Icons.my_location,
                            size: 22, color: PienoColors.bluPosizione),
                        onTap: _vaiAllaPosizione,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Foglio prezzi. Due pezzi distinti, non uno solo:
  //
  //   BOX      il pannello sovrapposto alla mappa. Ne comanda l'altezza il trascinamento
  //            della maniglia (chrome fisso del box) oppure, quando la lista è già in
  //            cima, il trascinamento della lista stessa.
  //   LISTA    il contenuto scorrevole DENTRO il box: scheda dell'impianto selezionato,
  //            occhiello, righe. Clippata dal box, con rimbalzo in coda.
  //
  // La maniglia sta nel box e NON nella lista: è il bordo del pannello, quindi non deve
  // scorrere via col contenuto.
  Widget _foglio() {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        ref.read(foglioExtentProvider.notifier).state = n.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _foglioMedio,
        minChildSize: _foglioMin,
        maxChildSize: _foglioMax,
        snap: true,
        snapSizes: const [_foglioMedio],
        builder: (context, scrollController) => GestureDetector(
          // Swipe verso sinistra sul foglio → vai a "Vicino a te" (lo scroll è verticale,
          // quindi il gesto orizzontale non interferisce).
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -350) {
              HapticFeedback.selectionClick();
              ref.read(vistaProvider.notifier).state = Vista.vicino;
            }
          },
          child: Container(
            decoration: const BoxDecoration(
              color: PienoColors.foglio,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(PienoRadii.schedaPrincipale)),
              boxShadow: PienoElevations.schedaPrincipale,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _maniglia(),
                    // La lista occupa ciò che resta del box e viene ritagliata da esso: il
                    // suo rimbalzo resta dentro il pannello, non lo scopre mai.
                    // Il contenuto osserva carburante/elenco/selezione/posizione in un
                    // Consumer isolato: i loro cambi ricostruiscono solo il foglio, non la
                    // mappa (L2).
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) => _contenuto(ref, scrollController),
                      ),
                    ),
                  ],
                ),
                _dissolvenzaInCoda(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Lo switch flottante galleggia sopra il foglio, alla stessa altezza che ha su "Vicino a
  // te". Perché non sembri appiccicato sopra il contenuto, l'ultimo tratto del foglio
  // sfuma nel colore del pannello: le righe non vengono tagliate a metà dallo switch, si
  // dissolvono sotto di lui. Decorativa e non cliccabile: la lista sotto resta toccabile.
  Widget _dissolvenzaInCoda() {
    final altezza =
        MediaQuery.of(context).padding.bottom + kSpazioSwitchFlottante;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: altezza,
      child: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00F7FAFB), PienoColors.foglio, PienoColors.foglio],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }

  // Maniglia: bordo fisso del box e sua unica presa diretta. Stando fuori dalla lista non
  // riceve più i gesti dallo scorrimento, quindi il trascinamento lo comanda qui a mano
  // sul controller del foglio (44×5 su una striscia alta ~28: bersaglio comodo al pollice).
  Widget _maniglia() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) {
        if (!_sheetController.isAttached) return;
        final h = MediaQuery.of(context).size.height;
        // dy positivo = dito verso il basso = box più basso.
        _sheetController.jumpTo(
          (_sheetController.size - d.delta.dy / h).clamp(_foglioMin, _foglioMax),
        );
      },
      onVerticalDragEnd: (d) => _snapFoglio(d.primaryVelocity ?? 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: PienoColors.grafite.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  // La scheda dell'impianto come presa del box. Il riconoscitore qui dentro vince
  // sull'elenco (è più interno), perciò quando il gesto deve scorrere la lista glielo si
  // gira a mano: è il prezzo da pagare per avere una presa che si comporta sempre allo
  // stesso modo, invece che solo con la lista in cima.
  Widget _presaScheda(ScrollController scroll, Widget scheda) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (!_sheetController.isAttached) return;
        final presa = decidiPresa(
          dy: d.delta.dy,
          dimensioneBox: _sheetController.size,
          offsetLista: scroll.hasClients ? scroll.offset : 0,
          boxMin: _foglioMin,
          boxMax: _foglioMax,
        );
        switch (presa) {
          case PresaFoglio.alzaBox:
          case PresaFoglio.abbassaBox:
            final h = MediaQuery.of(context).size.height;
            _boxMossoDallaPresa = true;
            _sheetController.jumpTo(
              (_sheetController.size - d.delta.dy / h).clamp(_foglioMin, _foglioMax),
            );
          case PresaFoglio.scorriLista:
            if (scroll.hasClients) {
              scroll.jumpTo((scroll.offset - d.delta.dy)
                  .clamp(0.0, scroll.position.maxScrollExtent));
            }
        }
      },
      onVerticalDragEnd: (d) {
        // Snap solo se il gesto ha davvero mosso il box: se ha scorso la lista, il foglio
        // non deve saltare da nessuna parte.
        if (!_boxMossoDallaPresa) return;
        _boxMossoDallaPresa = false;
        _snapFoglio(d.primaryVelocity ?? 0);
      },
      child: scheda,
    );
  }

  // Fine del trascinamento della maniglia: con un gesto deciso si va nella sua direzione,
  // altrimenti all'altezza più vicina. Replica a mano lo `snap` che DraggableScrollableSheet
  // applica da sé ai gesti che passano dalla lista.
  void _snapFoglio(double velocitaVerticale) {
    if (!_sheetController.isAttached) return;
    final corrente = _sheetController.size;
    const altezze = [_foglioMin, _foglioMedio, _foglioMax];
    late double meta;
    if (velocitaVerticale.abs() > 700) {
      meta = velocitaVerticale < 0 ? _foglioMax : _foglioMin; // negativo = verso l'alto
    } else {
      meta = altezze.reduce((a, b) =>
          (a - corrente).abs() <= (b - corrente).abs() ? a : b);
    }
    HapticFeedback.selectionClick();
    _sheetController.animateTo(meta,
        duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
  }

  // `ref` è quello del Consumer che avvolge il foglio (vedi _foglio): le watch qui sotto
  // registrano la dipendenza sul foglio, non sull'intera schermata (mappa esclusa) — L2.
  // Qui c'è SOLO il contenuto scorrevole: la maniglia sta nel box (vedi _maniglia).
  Widget _contenuto(WidgetRef ref, ScrollController scrollController) {
    final carburante = ref.watch(carburanteProvider);
    final elenco = ref.watch(elencoProvider);
    final selId = ref.watch(selezionatoProvider);
    final pos = ref.watch(posizioneProvider).valueOrNull;
    final capacita = ref.watch(capacitaLitriProvider);

    if (elenco.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: _fisicaFoglio,
        children: const [
          SizedBox(height: 40),
          Center(child: Text('Nessun impianto in questa zona.')),
        ],
      );
    }

    final media = mediaZona(elenco, carburante);
    final selezionato = _trova(elenco, selId) ?? elenco.first;
    final prezzoSel = selezionato.prezzoDi(carburante)!.valore;
    final risparmio =
        media == null ? 0.0 : risparmioSulPieno(prezzoSel, media, litri: capacita);
    final dist = (pos != null && selezionato.lat != null && selezionato.lon != null)
        ? distanzaKm(pos.lat, pos.lon, selezionato.lat!, selezionato.lon!)
        : null;

    // Righe mostrate: le prime _maxRigheFoglio secondo l'ordinamento scelto. L'occhiello
    // dichiara sempre quante sono: se l'elenco è tagliato non può dire "tutti".
    final righe = elenco.length > _maxRigheFoglio
        ? elenco.sublist(0, _maxRigheFoglio)
        : elenco;
    final occhiello = righe.length < elenco.length
        ? 'I PRIMI ${righe.length} IMPIANTI'
        : 'TUTTI GLI IMPIANTI';

    // Testata della lista (scorre insieme alle righe, dentro il box): la scheda
    // dell'impianto selezionato e l'occhiello. Le righe sono costruite in modo lazy da
    // ListView.builder per non generare tutti i widget in un colpo (L1).
    final testa = <Widget>[
      // La scheda è anche la presa del box: è larga quanto il foglio, quindi molto più
      // facile da afferrare della maniglia (vedi presa_foglio.dart per la regola).
      _presaScheda(
        scrollController,
        SchedaImpianto(
          impianto: selezionato,
          carburante: carburante,
          risparmioEuro: risparmio,
          distanzaKm: dist,
          onPortamiQui: () => _portamiQui(selezionato),
          onSegnala: () => mostraSegnala(context, selezionato, prezzoSel),
          altezzaAzione: PienoSizes.bottoneFoglioMappa,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(occhiello, style: PienoText.occhiello),
      ),
    ];

    return ListView.builder(
      controller: scrollController, // integra trascinamento del foglio e scroll dei contenuti
      physics: _fisicaFoglio,
      // In coda lo spazio dello switch flottante: l'ultima riga non ci finisce sotto.
      padding: EdgeInsets.fromLTRB(
          18, 0, 18, kSpazioSwitchFlottante + MediaQuery.of(context).padding.bottom),
      itemCount: testa.length + righe.length,
      itemBuilder: (context, index) {
        if (index < testa.length) return testa[index];
        final i = righe[index - testa.length];
        return _riga(i, carburante, media, i.id == selezionato.id);
      },
    );
  }

  Widget _riga(Impianto i, Carburante carburante, double? media, bool attivo) {
    final prezzo = i.prezzoDi(carburante)!;
    final rame = sopraLaMedia(i, carburante, media);
    return InkWell(
      onTap: () => ref.read(selezionatoProvider.notifier).state = i.id,
      child: Container(
        // La riga selezionata è la stessa cosa del marcatore in inchiostro sulla mappa:
        // qui si segnala con una superficie morbida, non con una linea dura (pag. 2).
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: attivo ? 12 : 0),
        decoration: BoxDecoration(
          color: attivo ? PienoColors.inchiostro.withValues(alpha: 0.06) : null,
          borderRadius: attivo ? BorderRadius.circular(18) : null,
          border: attivo
              ? null
              : const Border(bottom: BorderSide(color: Color(0x14000000))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                i.nome.isNotEmpty ? i.nome : i.marchio,
                style: attivo
                    ? PienoText.voceImpostazione.copyWith(fontWeight: FontWeight.w700)
                    : PienoText.voceImpostazione,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formattaPrezzo(prezzo.valore),
              style: PienoText.prezzoLista.copyWith(
                color: rame ? PienoColors.rame : PienoColors.inchiostro,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Impianto? _trova(List<Impianto> lista, String? id) {
    if (id == null) return null;
    for (final i in lista) {
      if (i.id == id) return i;
    }
    return null;
  }
}
