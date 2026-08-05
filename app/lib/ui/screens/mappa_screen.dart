// Schermata 2 — Mappa (pag. 6, 13). Tappa 04.
// Stile personalizzato (assets/map_style.json), marcatori-prezzo come layer di simboli
// con gestione delle collisioni (non widget). Foglio inferiore ridimensionabile,
// selezione condivisa con l'elenco, comandi tondi a destra.
//
// Nota web: la mappa è un "platform view" che cattura i gesti. Per questo il foglio NON
// è sovrapposto ma in colonna sotto la mappa, e si ridimensiona dalla sua maniglia
// (trascinamento o tocco). Su mobile l'effetto è comunque un pannello che cresce/cala.

import 'dart:typed_data';
import 'dart:ui' as ui;

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
import '../../models/segnalazione.dart';
import '../../state/app_state.dart';
import '../components/carburante_selettore.dart';
import '../components/ordinamento_shortcut.dart';
import '../components/pulsante_tondo.dart';
import '../components/scheda_impianto.dart';
import 'impostazioni_screen.dart';
import 'segnala_sheet.dart';

const _sorgente = 'prezzi';
const _layers = ['prezzi-testo', 'prezzi-migliore', 'prezzi-selezionato'];
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
  bool _movimentoProgrammatico = false;
  bool _mostraCerca = false;
  String? _provinciaCentrata; // per ricentrare solo al cambio di provincia

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

    // Sorgente con raggruppamento: sotto lo zoom 12 i punti si raggruppano e il cluster
    // mostra il minimo della zona (pag. 13: "da 2,059", non il conteggio).
    await c.addSource(
      _sorgente,
      const GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': []},
        cluster: true,
        clusterMaxZoom: 12,
        clusterRadius: 60,
        clusterProperties: {
          'min': ['min', ['get', 'prezzoNum']],
        },
      ),
    );
    // Pillole come sfondo dei prezzi (pag. 6): bianca 94% per i normali, gradiente
    // menta con alone per il più conveniente. I prezzi hanno larghezza costante
    // ("X,XXX"), quindi una pillola a misura fissa non si deforma.
    await c.addImage('pill-bianca', await _pill(w: 66, h: 32, menta: false, bordo: true));
    await c.addImage('pill-menta', await _pill(w: 78, h: 38, menta: true, alone: true));
    await c.addImage('pill-cluster', await _pill(w: 92, h: 34, menta: true));
    // Selezionato: inchiostro pieno, la pillola più grande di tutte, con alone che la
    // stacca dal resto. L'inchiostro è il colore della "voce selezionata" (pag. 4) ed è
    // l'unico scuro sulla mappa chiara: si trova a colpo d'occhio.
    await c.addImage(
      'pill-selezionata',
      await _pill(
        w: 84,
        h: 40,
        menta: false,
        alone: true,
        bordo: true, // sottile anello bianco: stacca l'inchiostro dal fondo della mappa
        tinta: PienoColors.inchiostro,
      ),
    );

    // Marcatori non raggruppati (hanno prezzo solo i punti singoli).
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-testo',
      const SymbolLayerProperties(
        iconImage: 'pill-bianca',
        iconAllowOverlap: false,
        textField: '{prezzo}',
        textSize: 15,
        textFont: ['Noto Sans Regular'],
        textColor: '#0E1620',
        textOffset: [0, -0.28],
        textAllowOverlap: false,
      ),
      filter: [
        'all',
        ['!=', ['get', 'migliore'], true],
        ['!=', ['get', 'selezionato'], true],
        ['!', ['has', 'point_count']],
      ],
    );
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-migliore',
      const SymbolLayerProperties(
        iconImage: 'pill-menta',
        iconAllowOverlap: true,
        textField: '{prezzo}',
        textSize: 17,
        textFont: ['Noto Sans Regular'],
        textColor: '#FFFFFF',
        textOffset: [0, -0.24],
        textAllowOverlap: true,
      ),
      filter: [
        'all',
        ['==', ['get', 'migliore'], true],
        ['!=', ['get', 'selezionato'], true],
        ['!', ['has', 'point_count']],
      ],
    );
    // Cluster: pillola menta con il prezzo minimo della zona ("da 1,8xx").
    await c.addSymbolLayer(
      _sorgente,
      'cluster-testo',
      const SymbolLayerProperties(
        iconImage: 'pill-cluster',
        iconAllowOverlap: true,
        textField: [
          'concat',
          'da ',
          ['number-format', ['get', 'min'], {'locale': 'it-IT', 'min-fraction-digits': 3, 'max-fraction-digits': 3}],
        ],
        textFont: ['Noto Sans Regular'],
        textSize: 13,
        textColor: '#FFFFFF',
        textOffset: [0, -0.3],
        textAllowOverlap: true,
      ),
      filter: ['has', 'point_count'],
    );
    // Selezionato per ultimo: sta sopra a tutti gli altri e non cede mai il posto alle
    // collisioni. È l'impianto aperto nel foglio: deve restare visibile per definizione.
    await c.addSymbolLayer(
      _sorgente,
      'prezzi-selezionato',
      const SymbolLayerProperties(
        iconImage: 'pill-selezionata',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        textField: '{prezzo}',
        textSize: 17,
        textFont: ['Noto Sans Regular'],
        textColor: '#FFFFFF',
        textOffset: [0, -0.24],
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: [
        'all',
        ['==', ['get', 'selezionato'], true],
        ['!', ['has', 'point_count']],
      ],
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
    final geo = geoJsonPrezzi(
      marcatori,
      carburante,
      idMigliore: ordinati.first.id,
      idSelezionato: ref.read(selezionatoProvider),
    );
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
    final target = pos != null
        ? LatLng(pos.lat, pos.lon)
        : LatLng(ordinati.first.lat ?? 41.9, ordinati.first.lon ?? 12.5);
    _movimentoProgrammatico = true;
    c.animateCamera(CameraUpdate.newLatLngZoom(target, 11));
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
    await c.animateCamera(
      zoom < 12 ? CameraUpdate.newLatLngZoom(punto, 13) : CameraUpdate.newLatLng(punto),
    );
  }

  void _vaiAllaPosizione() {
    final pos = ref.read(posizioneProvider).valueOrNull;
    if (pos != null) {
      _movimentoProgrammatico = true;
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.lat, pos.lon), 13));
    }
  }

  // La mappa si è fermata: se il movimento è dell'utente, offri "Cerca in questa zona".
  void _onCameraIdle() {
    if (_movimentoProgrammatico) {
      _movimentoProgrammatico = false;
      return;
    }
    if (mounted && !_mostraCerca) setState(() => _mostraCerca = true);
  }

  // Passa alla provincia il cui baricentro è più vicino al centro mappa corrente.
  void _cercaInQuestaZona() {
    setState(() => _mostraCerca = false);
    final centro = _controller?.cameraPosition?.target;
    final manifest = ref.read(manifestProvider).valueOrNull;
    if (centro == null || manifest == null) return;
    final sigla = manifest.provinciaPiuVicina(centro.latitude, centro.longitude);
    if (sigla != null) ref.read(provinciaSceltaProvider.notifier).state = sigla;
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
    ref.listen(marcatoriProvider, (_, __) => _aggiornaSorgente());
    ref.listen(ordinamentoProvider, (_, __) => _aggiornaSorgente());
    ref.listen(selezionatoProvider, (_, id) async {
      await _aggiornaSorgente();
      await _mostraSelezionato(id);
    });
    ref.listen(posizioneProvider, (_, __) {
      _aggiornaPosizione();
      _aggiornaSorgente();
    });

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
                    onCameraIdle: _onCameraIdle,
                    trackCameraPosition: true,
                    myLocationEnabled: false,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
                // Shortcut ordinamento in alto a sinistra (stile pillola in vetro).
                const Positioned(
                  top: 16,
                  left: PienoSpacing.margineLaterale,
                  child: OrdinamentoShortcut(),
                ),
                // Selettore carburante a tendina in alto a destra.
                const Positioned(
                  top: 16,
                  right: PienoSpacing.margineLaterale,
                  child: CarburanteSelettore(),
                ),
                // "Cerca in questa zona": appare dopo che l'utente sposta la mappa;
                // nessun ricaricamento automatico che sposta i risultati sotto il dito.
                if (_mostraCerca)
                  Positioned(
                    top: 16,
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            child: Text('Cerca in questa zona',
                                style: PienoText.voceImpostazione
                                    .copyWith(color: const Color(0xFFFFFFFF))),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Attribuzione obbligatoria, visibile SULLA mappa (linee-guida/
                // 06-architettura.md e 09-checklist-rilascio.md). Discreta ma leggibile:
                // non è un elemento dell'interfaccia, è una condizione di licenza.
                const Positioned(
                  left: PienoSpacing.margineLaterale,
                  bottom: 8,
                  child: _AttribuzioneMappa(),
                ),
                Positioned(
                  right: PienoSpacing.margineLaterale,
                  bottom: 24,
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
              ],
            ),
          ),
          _foglio(maxFoglio),
        ],
      ),
    );
  }

  Widget _foglio(double maxFoglio) {
    final carburante = ref.watch(carburanteProvider);
    final elenco = ref.watch(elencoProvider);
    final selId = ref.watch(selezionatoProvider);
    final pos = ref.watch(posizioneProvider).valueOrNull;
    final capacita = ref.watch(capacitaLitriProvider);

    final altezza = _altezzaFoglio.clamp(_foglioMin, maxFoglio);
    return Container(
      height: altezza,
      clipBehavior: Clip.antiAlias,
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
            onVerticalDragUpdate: (d) {
              setState(() {
                _altezzaFoglio = (_altezzaFoglio - d.delta.dy).clamp(_foglioMin, maxFoglio);
              });
              _sincronizzaEspanso(maxFoglio);
            },
            onTap: () {
              setState(() {
                _altezzaFoglio = _altezzaFoglio > (maxFoglio * 0.6) ? 300 : maxFoglio;
              });
              _sincronizzaEspanso(maxFoglio);
            },
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
            child: elenco.isEmpty
                ? const Center(child: Text('Nessun impianto in questa zona.'))
                : _contenuto(elenco, carburante, selId, pos, capacita),
          ),
        ],
      ),
    );
  }

  Widget _contenuto(List<Impianto> ordinati, carburante, String? selId, pos, int capacita) {
    final media = mediaZona(ordinati, carburante);
    final selezionato = _trova(ordinati, selId) ?? ordinati.first;
    final prezzoSel = selezionato.prezzoDi(carburante)!.valore;
    final risparmio =
        media == null ? 0.0 : risparmioSulPieno(prezzoSel, media, litri: capacita);
    final dist = (pos != null && selezionato.lat != null && selezionato.lon != null)
        ? distanzaKm(pos.lat, pos.lon, selezionato.lat!, selezionato.lon!)
        : null;

    return ListView(
      // Spazio in fondo per non far coprire l'ultima riga dallo switch flottante.
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
      children: [
        SchedaImpianto(
          impianto: selezionato,
          carburante: carburante,
          risparmioEuro: risparmio,
          distanzaKm: dist,
          onPortamiQui: () => _portamiQui(selezionato),
          onSegnala: () => mostraSegnala(context, selezionato, prezzoSel),
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

  // Disegna una pillola-marcatore come PNG: rettangolo arrotondato con coda a rombo.
  // menta=false → bianca 94%; menta=true → gradiente menta (pag. 6).
  // tinta → riempimento pieno con quel colore (selezionato: inchiostro), ha la
  // precedenza su menta/bianco. alone → alone radiale che isola il marcatore;
  // bordo → bordo bianco.
  Future<Uint8List> _pill({
    required double w,
    required double h,
    required bool menta,
    bool alone = false,
    bool bordo = false,
    ui.Color? tinta,
  }) async {
    const tail = 8.0;
    final totH = h + tail;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rr = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Radius.circular(h / 2),
    );
    final fill = ui.Paint();
    if (alone) {
      // Alone radiale che isola il marcatore dagli altri: della stessa famiglia di
      // colore del riempimento, così non introduce tinte nuove sulla mappa.
      canvas.drawCircle(
        ui.Offset(w / 2, h / 2),
        w / 2,
        ui.Paint()
          ..color = tinta != null
              ? tinta.withValues(alpha: 0.28)
              : const ui.Color(0x3300B39A)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14),
      );
    }
    if (tinta != null) {
      fill.color = tinta;
    } else if (menta) {
      fill.shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(w, h),
        const [ui.Color(0xFF00C2A6), ui.Color(0xFF00887E)],
      );
    } else {
      fill.color = const ui.Color(0xF0FFFFFF); // bianco ~94%
    }

    // coda a rombo (punta in basso)
    final cx = w / 2;
    final tailPath = ui.Path()
      ..moveTo(cx - tail, h - 2)
      ..lineTo(cx, h - 2 + tail)
      ..lineTo(cx + tail, h - 2)
      ..close();
    canvas.drawPath(tailPath, fill);
    canvas.drawRRect(rr, fill);
    if (bordo) {
      canvas.drawRRect(
        rr,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const ui.Color(0xE6FFFFFF),
      );
    }

    final img = await recorder.endRecording().toImage(w.ceil(), totH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void _sincronizzaEspanso(double maxFoglio) {
    final espanso = _altezzaFoglio > maxFoglio * 0.55;
    if (ref.read(foglioEspansoProvider) != espanso) {
      ref.read(foglioEspansoProvider.notifier).state = espanso;
    }
  }

  Impianto? _trova(List<Impianto> lista, String? id) {
    if (id == null) return null;
    for (final i in lista) {
      if (i.id == id) return i;
    }
    return null;
  }
}

/// Attribuzione della mappa. Le tile di OpenFreeMap derivano da OpenStreetMap: la
/// licenza ODbL richiede che il credito sia visibile dove la mappa è mostrata, non
/// solo dentro le impostazioni.
class _AttribuzioneMappa extends StatelessWidget {
  const _AttribuzioneMappa();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB8FFFFFF),
        borderRadius: BorderRadius.circular(PienoRadii.pillola),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '© OpenStreetMap contributors',
          style: PienoText.valoreDettaglio.copyWith(fontSize: 10),
        ),
      ),
    );
  }
}
