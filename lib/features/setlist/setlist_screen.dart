import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../live/live_view_screen.dart';
import '../../core/utils/transpose.dart'; // ajusta la ruta si difiere

/// -------- LISTA DE SETLISTS --------
class SetlistScreen extends StatelessWidget {
  const SetlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SetlistRepo();
    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: ValueListenableBuilder<Box>(
        valueListenable: repo.listen(),
        builder: (_, __, ___) {
          final items = repo.all()
            ..sort((a, b) => (b['updatedAt'] ?? '').compareTo(a['updatedAt'] ?? ''));
          if (items.isEmpty) {
            return const Center(child: Text('Sin setlists. Toca + para crear uno.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = items[i];
              return ListTile(
                title: Text(s['title'] ?? '(sin título)'),
                subtitle: Text(s['notes'] ?? ''),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SetlistEditorScreen(setlistId: s['id'])),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => repo.delete(s['id']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final id = await repo.upsert({
            'title': 'Nuevo setlist',
            'notes': '',
            'items': <Map<String, dynamic>>[],
          });
          // ignore: use_build_context_synchronously
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => SetlistEditorScreen(setlistId: id)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// -------- EDITOR DE UN SETLIST --------
class SetlistEditorScreen extends StatefulWidget {
  final String setlistId;
  const SetlistEditorScreen({super.key, required this.setlistId});

  @override
  State<SetlistEditorScreen> createState() => _SetlistEditorScreenState();
}

class _SetlistEditorScreenState extends State<SetlistEditorScreen> {
  final setlistRepo = SetlistRepo();
  final songRepo = SongRepo();

  Map<String, dynamic>? setlist;
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  bool _dirty = false; // <- hay cambios sin guardar

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setlist = setlistRepo.getById(widget.setlistId) ?? {
      'id': widget.setlistId,
      'title': 'Setlist',
      'notes': '',
      'items': <Map<String, dynamic>>[],
    };
    titleCtrl.text = setlist?['title'] ?? '';
    notesCtrl.text = setlist?['notes'] ?? '';
    setState(() {});
  }

  Future<void> _save() async {
    setlist!['title'] = titleCtrl.text.trim();
    setlist!['notes'] = notesCtrl.text.trim();
    await setlistRepo.upsert(setlist!);
    if (mounted) {
      _dirty = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Setlist guardado')));
      setState(() {});
    }
  }

  void _markDirty([VoidCallback? change]) {
    change?.call();
    if (!_dirty) {
      setState(() => _dirty = true);
    } else {
      setState(() {}); // refresca UI
    }
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('¿Quieres guardar antes de salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Descartar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await _save();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Si el usuario eligió "Descartar" -> true; si guardó, también true
    return res != null ? true : !_dirty ? true : false;
  }

  Future<void> _addSong() async {
    final chosen = await showDialog<_SongPickResult>(
      context: context,
      builder: (ctx) => _SongPickerDialog(songRepo: songRepo),
    );
    if (chosen == null) return;
    _markDirty(() {
      final list = (setlist!['items'] as List).cast<Map>().toList();
      list.add({
        'songId': chosen.id,
        'title': chosen.title,
        'steps': 0,
        'order': list.length,
      });
      setlist!['items'] = list;
    });
  }

  void _changeSteps(int index, int delta) {
    _markDirty(() {
      final list = (setlist!['items'] as List).cast<Map>().toList();
      final m = Map<String, dynamic>.from(list[index]);
      m['steps'] = (m['steps'] as int) + delta;
      list[index] = m;
      setlist!['items'] = list;
    });
  }

  void _removeItem(int index) {
    _markDirty(() {
      final list = (setlist!['items'] as List).cast<Map>().toList();
      list.removeAt(index);
      for (var i = 0; i < list.length; i++) {
        list[i]['order'] = i;
      }
      setlist!['items'] = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (setlist == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final items = (setlist!['items'] as List).cast<Map>().toList()
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

    return WillPopScope(
      onWillPop: _confirmLeaveIfDirty,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar Setlist'),
          actions: [
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.save),
              tooltip: 'Guardar',
            ),
            IconButton(
              tooltip: 'Vista en vivo',
              icon: const Icon(Icons.slideshow_outlined),
              onPressed: () async {
                // si estás usando el modo "guardar manual", guarda antes de presentar
                if (mounted && _dirty) {
                  await _save();
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveViewScreen(setlistId: widget.setlistId),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addSong,
          child: const Icon(Icons.add),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Título del setlist',
                  border: const OutlineInputBorder(),
                  suffixIcon: _dirty ? const Icon(Icons.circle, size: 10, color: Colors.amber)
                                     : const SizedBox.shrink(),
                ),
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas (quién inicia, BPM, etc.)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markDirty(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    _markDirty(() {
                      if (newIndex > oldIndex) newIndex--;
                      final list = items;
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      for (var i = 0; i < list.length; i++) {
                        list[i]['order'] = i;
                      }
                      setlist!['items'] = list;
                    });
                  },
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final title = (it['title'] ?? '(sin título)') as String;
                    final steps = (it['steps'] ?? 0) as int;
                    final baseKey = it['baseKey'] ?? 'C';
                    final newKey  = transposeChord(baseKey, steps); // ← del util

                    return Card(
                      key: ValueKey(it['songId']),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(title),
                        subtitle: Text(
                          'Tono: $baseKey → $newKey  (${steps >= 0 ? '+' : ''}$steps semitonos)'
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Bajar ½',
                              icon: const Icon(Icons.remove),
                              onPressed: () => _changeSteps(i, -1),
                            ),
                            IconButton(
                              tooltip: 'Subir ½',
                              icon: const Icon(Icons.add),
                              onPressed: () => _changeSteps(i, 1),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeItem(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------- DIALOGO PARA ELEGIR CANCIÓN --------
class _SongPickerDialog extends StatelessWidget {
  final SongRepo songRepo;
  const _SongPickerDialog({required this.songRepo});

  @override
  Widget build(BuildContext context) {
    final songs = songRepo.all();
    return AlertDialog(
      title: const Text('Añadir canción'),
      content: songs.isEmpty
          ? const Text('No hay canciones en la biblioteca.')
          : SizedBox(
              width: 400,
              height: 300,
              child: ListView.separated(
                itemCount: songs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = songs[i];
                  return ListTile(
                    title: Text(s['title'] ?? '(sin título)'),
                    subtitle: Text('Tono base: ${s['baseKey'] ?? '-'}'),
                    onTap: () => Navigator.pop(
                      context,
                      _SongPickResult(id: s['id'] as String, title: s['title'] ?? '(sin título)'),
                    ),
                  );
                },
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }
}

class _SongPickResult {
  final String id;
  final String title;
  _SongPickResult({required this.id, required this.title});
}