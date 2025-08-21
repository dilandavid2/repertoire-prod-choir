import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class SongRepo {
  final Box _box = Hive.box('songs');
  final Box _trash = Hive.box('songs_trash'); // <- nueva caja
  static const _uuid = Uuid();

  ValueListenable<Box> listen() => _box.listenable();
  ValueListenable<Box> listenTrash() => _trash.listenable();

  List<Map<String, dynamic>> all() =>
      _box.values.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  List<Map<String, dynamic>> allTrashed() =>
      _trash.values.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Map<String, dynamic>? getById(String id) {
    final v = _box.get(id);
    return v == null ? null : Map<String, dynamic>.from(v);
  }

  Future<String> upsert(Map<String, dynamic> song) async {
    var id = (song['id'] as String?) ?? _uuid.v4();
    song['id'] = id;
    final now = DateTime.now().toUtc().toIso8601String();
    song['createdAt'] ??= now;
    song['updatedAt'] = now;
    await _box.put(id, song);
    return id;
  }

  Future<void> trash(String id) async {
    final v = _box.get(id);
    if (v != null) {
      final m = Map<String, dynamic>.from(v);
      m['deletedAt'] = DateTime.now().toUtc().toIso8601String();
      await _trash.put(id, m);
      await _box.delete(id);
    }
  }

  Future<void> restore(String id) async {
    final v = _trash.get(id);
    if (v != null) {
      final m = Map<String, dynamic>.from(v)..remove('deletedAt');
      await _box.put(id, m);
      await _trash.delete(id);
    }
  }

  Future<void> deleteForever(String id) => _trash.delete(id);
}