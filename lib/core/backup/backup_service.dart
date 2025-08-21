import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  static const _boxes = ['songs', 'songs_trash', 'categories', 'setlists'];

  /// Construye un JSON con todas las cajas
  static Future<String> exportAllToJson() async {
    final data = <String, dynamic>{};
    for (final name in _boxes) {
      final box = Hive.box(name);
      // Guardamos solo values (Maps) en una lista
      data[name] = box.values.map((e) => e).toList(growable: false);
    }
    data['_meta'] = {
      'app': 'Repertoire',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Guarda un archivo temporal .json y abre el share sheet
  static Future<void> shareBackupJson() async {
    final json = await exportAllToJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/repertoire-backup-${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], text: 'Backup de Repertoire');
  }

  /// Restaura desde un archivo .json elegido por el usuario
  static Future<void> restoreFromJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;

    final file = File(result.files.single.path!);
    final txt = await file.readAsString();
    final decoded = jsonDecode(txt) as Map<String, dynamic>;

    // Validación mínima
    if (decoded['_meta'] is! Map) throw Exception('Archivo inválido');

    // Volcamos datos a Hive (sobrescribe IDs iguales, inserta nuevos)
    for (final name in _boxes) {
      if (decoded[name] is! List) continue;
      final list = (decoded[name] as List).cast<dynamic>();
      final box = Hive.box(name);
      // Limpiar es opcional; aquí MERGE (no vacía)
      for (final item in list) {
        if (item is Map && item['id'] != null) {
          // upsert por id (si ya tienes tu repos con upsert, úsalo)
          final existingKey = box.keys.firstWhere(
            (k) => (box.get(k) as Map?)?['id'] == item['id'],
            orElse: () => null,
          );
          if (existingKey != null) {
            await box.put(existingKey, item);
          } else {
            await box.add(item);
          }
        } else {
          await box.add(item);
        }
      }
    }
  }
}