// Archivio locale offline-first (Roadmap 02: "Archivio locale").
// "L'ultima zona resta su disco: l'app apre sempre con qualcosa" (linee-guida/06-architettura.md).
// Nota: qui cache su file. La scelta definitiva Drift/Isar è rimandata (vedi pubspec.yaml).
//
// Sul web il filesystem non è disponibile: lo store diventa un no-op (l'app funziona
// comunque, prendendo i dati dalla rete). Su mobile/desktop usa i file.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class LocalStore {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/province');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _file(Directory dir, String provincia) => File('${dir.path}/$provincia.json');

  /// Salva il JSON grezzo di una provincia. Scrittura atomica (file temporaneo + rename).
  Future<void> salvaProvincia(String provincia, String jsonGrezzo) async {
    if (kIsWeb) return; // niente filesystem sul web
    final dir = await _dir();
    final tmp = File('${dir.path}/$provincia.json.tmp');
    await tmp.writeAsString(jsonGrezzo, flush: true);
    await tmp.rename(_file(dir, provincia).path);
  }

  /// Legge il JSON grezzo salvato, o null se assente (o su web).
  Future<String?> leggiProvincia(String provincia) async {
    if (kIsWeb) return null;
    final dir = await _dir();
    final f = _file(dir, provincia);
    return await f.exists() ? f.readAsString() : null;
  }

  Future<bool> haProvincia(String provincia) async {
    if (kIsWeb) return false;
    final dir = await _dir();
    return _file(dir, provincia).exists();
  }

  /// Cancella tutte le zone salvate (Impostazioni → Dati → «Cancella i dati salvati»).
  /// L'informativa privacy promette che svuotando i dati non resti nulla in locale:
  /// questo è il gesto che la mantiene senza disinstallare l'app.
  Future<void> svuota() async {
    if (kIsWeb) return;
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
