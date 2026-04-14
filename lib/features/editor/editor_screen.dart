import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/transpose.dart';
import '../../data/repositories/song_repository.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../score/score_editor_screen.dart';

const kKeys = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];

class EditorScreen extends StatefulWidget {
  final String? songId;
  const EditorScreen({super.key, this.songId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _catBox = Hive.box('categories');
  List<String> selectedCats = [];

  final repo = SongRepo();
  final titleCtrl = TextEditingController();
  final bodyCtrl  = TextEditingController();
  String baseKey = 'C';
  String? id;

  @override
  void initState() {
    super.initState();
    if (widget.songId != null) {
      final s = repo.getById(widget.songId!);
      if (s != null) {
        id = s['id'];
        titleCtrl.text = s['title'] ?? '';
        baseKey = s['baseKey'] ?? 'C';
        bodyCtrl.text = s['bodyChordPro'] ?? '';
        selectedCats = (s['categoryIds'] as List? ?? []).cast<String>(); // <-- ESTA
      }
    }
  }
  Future<void> _save() async {
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título a la canción')),
      );
      return;
    }
    final song = {
      'id': id,
      'title': titleCtrl.text.trim(),
      'baseKey': baseKey,
      'bodyChordPro': bodyCtrl.text,

      'songCategoryNames': selectedCats
          .map((id) => (_catBox.get(id) as Map?)?['name'])
          .whereType<String>()
          .toList(),
      'categoryIds': selectedCats,
    };
    final savedId = await repo.upsert(song);
    setState(() => id = savedId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Canción guardada')),
    );
  }

  void _transpose(int steps) {
    bodyCtrl.text = transposeChordProBody(bodyCtrl.text, steps);
    setState(() {});
  }

  Future<void> _share() async {
    final payload = {
      'schema': 'tu_coro.song',
      'version': 1,
      'payload': {
        'id': id,
        'title': titleCtrl.text.trim(),
        'baseKey': baseKey,
        'bodyChordPro': bodyCtrl.text,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }
    };
    final s = const JsonEncoder.withIndent('  ').convert(payload);
    final t = 'Canción: ${titleCtrl.text.trim()}';
    await Share.share(s, subject: t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Nueva canción' : 'Editar canción'),
        actions: [
          IconButton(
            tooltip: 'Editor de partitura',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScoreEditorScreen(songId: id),
                ),
              );
            },
            icon: const Icon(Icons.library_music),
          ),
          IconButton(onPressed: _share, icon: const Icon(Icons.share)),
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Tono base:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: baseKey,
                  items: kKeys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) => setState(() => baseKey = v ?? 'C'),
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => _transpose(-1),
                  child: const Text('− ½'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _transpose(1),
                  child: const Text('+ ½'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Box>(
              valueListenable: _catBox.listenable(),
              builder: (_, __, ___) {
                final cats = _catBox.values.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                return Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: [
                    ...cats.map((c) {
                      final id = c['id'] as String;
                      final sel = selectedCats.contains(id);
                      return FilterChip(
                        label: Text(c['name'] ?? ''),
                        selected: sel,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              selectedCats.add(id);
                            } else {
                              selectedCats.remove(id);
                            }
                          });
                        },
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva categoría'),
                      onPressed: () async {
                        final txt = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Nueva categoría'),
                            content: TextField(controller: txt, decoration: const InputDecoration(border: OutlineInputBorder())),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
                            ],
                          ),
                        );
                        if (ok == true && txt.text.trim().isNotEmpty) {
                          final id = const Uuid().v4();
                          await _catBox.put(id, {'id': id, 'name': txt.text.trim()});
                          setState(() => selectedCats.add(id));
                        }
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: bodyCtrl,
                expands: true,
                maxLines: null,
                minLines: null,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Letra + acordes (ChordPro: [C]Dios está ...)',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
      //floatingActionButton:
          //FloatingActionButton(onPressed: _save, child: const Icon(Icons.check)),
    );
  }
}