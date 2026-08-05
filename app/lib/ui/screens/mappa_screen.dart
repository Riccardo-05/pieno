// Schermata 2 — Mappa (pag. 6, 13). Tappa 04.
// Stile personalizzato (assets/map_style.json), marcatori-prezzo come layer di simboli
// con gestione delle collisioni (non widget). Foglio inferiore ridimensionabile,
// selezione condivisa con l'elenco, comandi tondi a destra.
//
// Nota web: la mappa è un "platform view" che cattura i gesti. Per questo il foglio NON
// è sovrapposto ma in colonna sotto la mappa, e si ridimensiona dalla sua maniglia
// (trascinamento o tocco). Su mobile l'effetto è comunque un pannello che cresce/cala.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../data/navigator_launcher.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/geo.dart';
import '../../domain/geojson.dart';
import '../../domain/risparmio.dart';
import '../../models/impianto.dart';
import '../../state/app_state.dart';
import '../components/pulsante_tondo.dart';
import '../components/scheda_impianto.dart';

const _sorgente = 'prezzi';
const _layers = ['prezzi-testo', 'prezzi-migliore'];
const double _foglioMin = 150;

class MappaScreen extends ConsumerStatefulWidget {
  const MappaScreen({super.key});

  @override
  ConsumerState<MappaScreen> createState() => _MappaScreenState();
}

class _MappaScreenState extends ConsumerState<MappaScreen> {
  MapLibreMapController? _controller;
  String? _stile;
  bool _stilePronto = false;
  double _altezzaFoglio = 300;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map_style.json').then((s) {
      if (mounted) setState(() => _stile = s);
    });
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

    await c.addSource(
      _sorgente,
      const GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-testo',
      const SymbolLayerProperties(
        textField: '{prezzo}',
        textSize: 15,
        textFont: ['Noto Sans Regular'],
        textColor: '#0E1620',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.6,
        textAllowOverlap: false,
      ),
      filter: ['!=', ['get', 'migliore'], true],
    );
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-migliore',
      const SymbolLayerProperties(
        textField: '{prezzo}',
        textSize: 17,
        textFont: ['Noto Sans Regular'],
        textColor: '#00806F',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 2.2,
        textAllowOverlap: true,
      ),
      filter: ['==', ['get', 'migliore'], true],
    );
    _stilePronto = true;
    c.onFeatureTapped.add((point, latLng, featureId, layerId, annotation) {
      c.queryRenderedFeatures(point, _layers, null).then((feats) {
        if (feats.isEmpty) return;
        final props = (feats.first as Map)['properties'] as Map?;
        final id = props?['id'];
        if (id != null) ref.read(selezionatoProvider.notifier).state = id as String;
      });
    });
    await _aggiornaSorgente();
    await _aggiornaPosizione();
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
    final dati = ref.read(datiProvinciaProvider).valueOrNull?.dati;
    if (dati == null) return;
    final carburante = ref.read(carburanteProvider);
    final ordinati = ordinaPerPrezzo(dati.impianti, carburante);
    final idMigliore = ordinati.isNotEmpty ? ordinati.first.id : null;
    final geo = geoJsonPrezzi(dati.impianti, carburante, idMigliore: idMigliore);
    await c.setGeoJsonSource(_sorgente, geo);
    _centra(ordinati);
  }

  void _centra(List<Impianto> ordinati) {
    final c = _controller;
    if (c == null || ordinati.isEmpty) return;
    final pos = ref.read(posizioneProvider).valueOrNull;
    final target = pos != null
        ? LatLng(pos.lat, pos.lon)
        : LatLng(ordinati.first.lat ?? 41.9, ordinati.first.lon ?? 12.5);
    c.animateCamera(CameraUpdate.newLatLngZoom(target, 11));
  }

  void _vaiAllaPosizione() {
    final pos = ref.read(posizioneProvider).valueOrNull;
    if (pos != null) {
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.lat, pos.lon), 13));
    }
  }

  Future<void> _portamiQui(Impianto i) async {
    if (i.lat == null || i.lon == null) return;
    final ok = await portamiQui(i.lat!, i.lon!);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il navigatore.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(datiProvinciaProvider, (_, __) => _aggiornaSorgente());
    ref.listen(carburanteProvider, (_, __) => _aggiornaSorgente());
    ref.listen(posizioneProvider, (_, __) => _aggiornaPosizione());

    if (_stile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final maxFoglio = MediaQuery.of(context).size.height * 0.85;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapLibreMap(
                    styleString: _stile!,
                    initialCameraPosition:
                        const CameraPosition(target: LatLng(41.9, 12.5), zoom: 5),
                    onMapCreated: (c) => _controller = c,
                    onStyleLoadedCallback: _onStyleLoaded,
                    myLocationEnabled: false,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
                Positioned(
                  right: PienoSpacing.margineLaterale,
                  bottom: 24,
                  child: Column(
                    children: [
                      PulsanteTondo(
                        icona: const Icon(Icons.tune, size: 22, color: PienoColors.inchiostro),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Impostazioni: in arrivo (Tappa 05)')),
                        ),
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
              ],
            ),
          ),
          _foglio(maxFoglio),
        ],
      ),
    );
  }

  Widget _foglio(double maxFoglio) {
    final dati = ref.watch(datiProvinciaProvider).valueOrNull?.dati;
    final carburante = ref.watch(carburanteProvider);
    final selId = ref.watch(selezionatoProvider);
    final pos = ref.watch(posizioneProvider).valueOrNull;

    final altezza = _altezzaFoglio.clamp(_foglioMin, maxFoglio);
    return Container(
      height: altezza,
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(PienoRadii.schedaPrincipale)),
        boxShadow: PienoElevations.schedaPrincipale,
      ),
      child: Column(
        children: [
          // Maniglia: trascinala (o toccala) per allargare/stringere il foglio.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => setState(() {
              _altezzaFoglio = (_altezzaFoglio - d.delta.dy).clamp(_foglioMin, maxFoglio);
            }),
            onTap: () => setState(() {
              _altezzaFoglio = _altezzaFoglio > (maxFoglio * 0.6) ? 300 : maxFoglio;
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: PienoColors.grafite.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: dati == null
                ? const Center(child: Text('Nessun dato.'))
                : _contenuto(dati.impianti, carburante, selId, pos),
          ),
        ],
      ),
    );
  }

  Widget _contenuto(List<Impianto> impianti, carburante, String? selId, pos) {
    final ordinati = ordinaPerPrezzo(impianti, carburante);
    if (ordinati.isEmpty) {
      return const Center(child: Text('Nessun impianto con questo carburante.'));
    }
    final media = mediaZona(ordinati, carburante);
    final selezionato = _trova(ordinati, selId) ?? ordinati.first;
    final prezzoSel = selezionato.prezzoDi(carburante)!.valore;
    final risparmio = media == null ? 0.0 : risparmioSulPieno(prezzoSel, media);
    final dist = (pos != null && selezionato.lat != null && selezionato.lon != null)
        ? distanzaKm(pos.lat, pos.lon, selezionato.lat!, selezionato.lon!)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        SchedaImpianto(
          impianto: selezionato,
          carburante: carburante,
          risparmioEuro: risparmio,
          distanzaKm: dist,
          onPortamiQui: () => _portamiQui(selezionato),
          altezzaAzione: PienoSizes.bottoneFoglioMappa,
        ),
        const SizedBox(height: 18),
        Text('TUTTI GLI IMPIANTI', style: PienoText.occhiello),
        const SizedBox(height: 8),
        for (final i in ordinati) _riga(i, carburante, media, i.id == selezionato.id),
      ],
    );
  }

  Widget _riga(Impianto i, carburante, double? media, bool attivo) {
    final prezzo = i.prezzoDi(carburante)!;
    final rame = sopraLaMedia(i, carburante, media);
    return InkWell(
      onTap: () => ref.read(selezionatoProvider.notifier).state = i.id,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x14000000))),
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
              prezzo.valore.toStringAsFixed(3).replaceAll('.', ','),
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
