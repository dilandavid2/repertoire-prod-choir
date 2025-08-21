import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // <-- necesario para ValueListenable

class SetlistRepo {
  final Box _box = Hive.box('setlists');
  static const _uuid = Uuid();

  ValueListenable<Box> listen() => _box.listenable();

  List<Map<String, dynamic>> all() =>
      _box.values.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Map<String, dynamic>? getById(String id) {
    final v = _box.get(id);
    return v == null ? null : Map<String, dynamic>.from(v);
  }

  Future<String> upsert(Map<String, dynamic> setlist) async {
    final id = (setlist['id'] as String?) ?? _uuid.v4();
    setlist['id'] = id;
    setlist['items'] ??= <Map<String, dynamic>>[];
    final now = DateTime.now().toUtc().toIso8601String();
    setlist['createdAt'] ??= now;
    setlist['updatedAt'] = now;
    await _box.put(id, setlist);
    return id;
  }

  Future<void> delete(String id) => _box.delete(id);
}