// Disegno delle "pillole" di sfondo dei prezzi sulla mappa (pag. 6), come immagini PNG
// registrate nello stile. Logica pura (solo dart:ui), fuori dallo schermo mappa così è
// isolata e testabile.

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Disegna la pillola-sfondo (rettangolo arrotondato) come PNG. La dimensione finale la
/// decide icon-text-fit in base al testo: qui conta solo il colore e la nitidezza, per
/// cui si disegna in alta risoluzione. menta=true → gradiente; tinta → riempimento pieno
/// (selezionato: inchiostro); bordo → sottile anello bianco.
Future<Uint8List> disegnaPillola(
    {required bool menta, bool bordo = false, ui.Color? tinta}) async {
  const w = 160.0, h = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // Raggio moderato (non semicerchio pieno): con icon-text-fit i bordi si allungano
  // molto meno visibilmente rispetto a una pillola completamente tonda.
  final rr = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(0, 0, w, h),
    const ui.Radius.circular(22),
  );
  final fill = ui.Paint();
  if (tinta != null) {
    fill.color = tinta;
  } else if (menta) {
    fill.shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(w, h),
      const [ui.Color(0xFF00C2A6), ui.Color(0xFF00887E)],
    );
  } else {
    fill.color = const ui.Color(0xF0FFFFFF); // bianco ~94%
  }
  canvas.drawRRect(rr, fill);
  if (bordo) {
    canvas.drawRRect(
      rr,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const ui.Color(0xF2FFFFFF),
    );
  }
  final img = await recorder.endRecording().toImage(w.ceil(), h.ceil());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
