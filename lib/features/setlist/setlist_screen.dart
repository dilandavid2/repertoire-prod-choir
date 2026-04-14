import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../live/live_view_screen.dart';

import '../../data/repositories/setlist_cloud_repository.dart';
import '../../core/utils/transpose.dart'; // para transposeChord

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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

  final cloudRepo = SetlistCloudRepo();
  String? get cloudSetlistId => setlist?['cloudId'] as String?;

  Stream<Map<String, dynamic>?>? _setlistStream;
  Stream<List<Map<String, dynamic>>>? _itemsStream;

  Map<String, dynamic>? setlist;
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  bool _dirty = false; // <- hay cambios sin guardar

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setlist = setlistRepo.getById(widget.setlistId);

    if (setlist == null) {
      setlist = {
        'id': widget.setlistId,
        'title': 'Setlist',
        'notes': '',
        'items': <Map<String, dynamic>>[],
      };
    }

    if (setlist!['cloudId'] == null) {
      final cloudId = await cloudRepo.createSetlist(
        title: setlist!['title'] ?? 'Setlist',
      );
      setlist!['cloudId'] = cloudId;
      await setlistRepo.upsert(setlist!);
    }

    titleCtrl.text = setlist?['title'] ?? '';
    notesCtrl.text = setlist?['notes'] ?? '';

    final cid = cloudSetlistId;
    if (cid != null) {
      _setlistStream = cloudRepo.watchSetlist(cid).map((doc) => doc.data());
      _itemsStream = cloudRepo.watchItems(cid).map((snapshot) {
        return snapshot.docs.map((d) {
          final data = d.data();
          data['docId'] = d.id;
          return data;
        }).toList();
      });
    }

    if ((setlist!['cloudSyncedOnce'] ?? false) != true) {
      await _syncLocalItemsToCloudIfNeeded();
      setlist!['cloudSyncedOnce'] = true;
      await setlistRepo.upsert(setlist!);
    }

    if (mounted) setState(() {});
  }

  Future<void> _syncLocalItemsToCloudIfNeeded() async {
    if (cloudSetlistId == null || setlist == null) return;

    final localItems =
        (setlist!['items'] as List?)?.cast<Map>().toList() ?? <Map>[];

    // sincroniza metadata principal primero
    await cloudRepo.updateSetlistMeta(
      setlistId: cloudSetlistId!,
      title: (setlist!['title'] ?? 'Setlist').toString(),
      notes: (setlist!['notes'] ?? '').toString(),
    );

    if (localItems.isEmpty) return;

    final snapshot = await cloudRepo.watchItems(cloudSetlistId!).first;
    final cloudDocs = snapshot.docs.toList();

    // Si no hay nada en cloud, subimos todo
    if (cloudDocs.isEmpty) {
      for (var i = 0; i < localItems.length; i++) {
        final item = Map<String, dynamic>.from(localItems[i]);
        final songId = item['songId']?.toString();
        if (songId == null || songId.isEmpty) continue;

        final song = songRepo.getById(songId);
        final title = (item['title'] ?? song?['title'] ?? 'Sin título').toString();
        final baseKey = (item['baseKey'] ?? song?['baseKey'] ?? 'C').toString();

        await cloudRepo.addItem(
          setlistId: cloudSetlistId!,
          songId: songId,
          title: title,
          baseKey: baseKey,
          position: i,
          bodyChordPro: song?['bodyChordPro'] ?? item['bodyChordPro'] ?? '',
          mode: (song?['mode'] ?? 'chordpro').toString(),
        );
      }

      // aplicar semitonos después de crear
      final afterAdd = await cloudRepo.watchItems(cloudSetlistId!).first;
      final docs = afterAdd.docs.toList()
        ..sort((a, b) =>
            ((a.data()['position'] ?? 0) as int).compareTo((b.data()['position'] ?? 0) as int));

      for (var i = 0; i < localItems.length && i < docs.length; i++) {
        final item = Map<String, dynamic>.from(localItems[i]);
        final steps = (item['steps'] ?? 0) as int;

        if (steps != 0) {
          await cloudRepo.updateSteps(
            setlistId: cloudSetlistId!,
            itemId: docs[i].id,
            steps: steps,
          );
        }
      }

      return;
    }

    // Si ya existen items en cloud, solo completa faltantes por songId
    final cloudBySongId = <String, Map<String, dynamic>>{};
    for (final d in cloudDocs) {
      final data = d.data();
      final sid = data['songId']?.toString();
      if (sid != null && sid.isNotEmpty) {
        cloudBySongId[sid] = {
          'docId': d.id,
          ...data,
        };
      }
    }

    for (var i = 0; i < localItems.length; i++) {
      final item = Map<String, dynamic>.from(localItems[i]);
      final songId = item['songId']?.toString();
      if (songId == null || songId.isEmpty) continue;

      final song = songRepo.getById(songId);
      final title = (item['title'] ?? song?['title'] ?? 'Sin título').toString();
      final baseKey = (item['baseKey'] ?? song?['baseKey'] ?? 'C').toString();
      final steps = (item['steps'] ?? 0) as int;

      if (!cloudBySongId.containsKey(songId)) {
        await cloudRepo.addItem(
          setlistId: cloudSetlistId!,
          songId: songId,
          title: title,
          baseKey: baseKey,
          position: i,
          bodyChordPro: song?['bodyChordPro'] ?? item['bodyChordPro'] ?? '',
          mode: (song?['mode'] ?? 'chordpro').toString(),
        );
      }
    }

    // refresca y alinea positions/steps/baseKey/title
    final refreshed = await cloudRepo.watchItems(cloudSetlistId!).first;
    final refreshedDocs = refreshed.docs.toList();

    final refreshedBySongId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in refreshedDocs) {
      final sid = d.data()['songId']?.toString();
      if (sid != null && sid.isNotEmpty) {
        refreshedBySongId[sid] = d;
      }
    }

    final orderedIds = <String>[];

    for (var i = 0; i < localItems.length; i++) {
      final item = Map<String, dynamic>.from(localItems[i]);
      final songId = item['songId']?.toString();
      if (songId == null || songId.isEmpty) continue;

      final doc = refreshedBySongId[songId];
      if (doc == null) continue;

      final data = doc.data();
      final localTitle = (item['title'] ?? data['title'] ?? 'Sin título').toString();
      final localBaseKey = (item['baseKey'] ?? data['baseKey'] ?? 'C').toString();
      final localSteps = (item['steps'] ?? 0) as int;

      // actualiza steps si cambió
      if ((data['steps'] ?? 0) != localSteps) {
        await cloudRepo.updateSteps(
          setlistId: cloudSetlistId!,
          itemId: doc.id,
          steps: localSteps,
        );
      }

      // actualiza campos extra si cambiaron
      final needsMetaUpdate =
          (data['title'] ?? '') != localTitle || (data['baseKey'] ?? '') != localBaseKey;

      if (needsMetaUpdate) {
        await cloudRepo.updateItemMeta(
          setlistId: cloudSetlistId!,
          itemId: doc.id,
          title: localTitle,
          baseKey: localBaseKey,
        );
      }

      orderedIds.add(doc.id);
    }

    if (orderedIds.isNotEmpty) {
      await cloudRepo.reorder(
        setlistId: cloudSetlistId!,
        itemIdsInOrder: orderedIds,
      );
    }
  }

  Future<void> _save() async {
    setlist!['title'] = titleCtrl.text.trim();
    setlist!['notes'] = notesCtrl.text.trim();
    await setlistRepo.upsert(setlist!);

    if (cloudSetlistId != null) {
      await cloudRepo.updateSetlistMeta(
        setlistId: cloudSetlistId!,
        title: setlist!['title'],
        notes: setlist!['notes'],
      );
    }

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

    Future<void> _addSongToCloud(_SongPickResult chosen) async {
      final snapshot = await cloudRepo.watchItems(cloudSetlistId!).first;
      final position = snapshot.docs.length;

      final song = songRepo.getById(chosen.id);

      await cloudRepo.addItem(
        setlistId: cloudSetlistId!,
        songId: chosen.id,
        title: chosen.title,
        baseKey: song?['baseKey'] ?? 'C',
        position: position,
        bodyChordPro: song?['bodyChordPro'] ?? '',
        mode: (song?['mode'] ?? 'chordpro').toString(),
      );
    }

    if (chosen == null) return;

    await _addSongToCloud(chosen);

    _markDirty(() {
      final song = songRepo.getById(chosen.id);
      final list = (setlist!['items'] as List).cast<Map>().toList();
      list.add({
        'songId': chosen.id,
        'title': chosen.title,
        'order': list.length,
        'steps': 0,
        'baseKey': song?['baseKey'] ?? 'C',
      });
      setlist!['items'] = list;
    });
  }

  void _changeSteps(int index, int delta) async {
    final list = (setlist!['items'] as List).cast<Map>().toList();
    final m = Map<String, dynamic>.from(list[index]);

    final newSteps = ((m['steps'] ?? 0) as int) + delta;

    _markDirty(() {
      m['steps'] = newSteps;
      list[index] = m;
      setlist!['items'] = list;
    });

    final snapshot = await cloudRepo.watchItems(cloudSetlistId!).first;
    final docs = snapshot.docs.toList();

    if (index < docs.length) {
      await cloudRepo.updateSteps(
        setlistId: cloudSetlistId!,
        itemId: docs[index].id,
        steps: newSteps,
      );
    }
  }

  void _removeItem(int index) async {
    _markDirty(() {
      final list = (setlist!['items'] as List).cast<Map>().toList();
      list.removeAt(index);
      for (var i = 0; i < list.length; i++) {
        list[i]['order'] = i;
      }
      setlist!['items'] = list;
    });

    final snapshot = await cloudRepo.watchItems(cloudSetlistId!).first;
    final docs = snapshot.docs.toList();

    if (index < docs.length) {
      await cloudRepo.removeItem(
        setlistId: cloudSetlistId!,
        itemId: docs[index].id,
      );
    }
  }

  Future<void> _copiarCodigoSetlist() async {
    await Clipboard.setData(ClipboardData(text: cloudSetlistId!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código del setlist copiado')),
    );
  }

  Future<void> _compartirCodigoSetlist() async {
    await Share.share(
      'Únete a mi setlist en Repertoire.\nCódigo: $cloudSetlistId',
      subject: 'Código de setlist',
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_setlistStream == null || _itemsStream == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _setlistStream!,
      builder: (context, setlistSnap) {
        if (!setlistSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final cloudSetlist = setlistSnap.data!;
        final titulo = cloudSetlist['title'] ?? 'Setlist';
        final notas = cloudSetlist['notes'] ?? '';

        if (titleCtrl.text != titulo) {
          titleCtrl.text = titulo;
        }
        if (notesCtrl.text != notas) {
          notesCtrl.text = notas;
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _itemsStream!,
          builder: (context, itemsSnap) {
            if (!itemsSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final cloudItems = itemsSnap.data!;

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
                      onPressed: _copiarCodigoSetlist,
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copiar código',
                    ),
                    IconButton(
                      onPressed: _compartirCodigoSetlist,
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Compartir código',
                    ),
                    IconButton(
                      tooltip: 'Vista en vivo',
                      icon: const Icon(Icons.slideshow_outlined),
                      onPressed: () async {
                        await _save();
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
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Título del setlist',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) async {
                              await cloudRepo.updateSetlistMeta(
                                setlistId: cloudSetlistId!,
                                title: v,
                                notes: notesCtrl.text,
                              );
                            },
                          ),

                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              'Código del setlist: $cloudSetlistId',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                          const SizedBox(height: 12),
                          TextField(
                            controller: notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notas (guión inicial, BPM, etc.)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) async {
                              await cloudRepo.updateSetlistMeta(
                                setlistId: cloudSetlistId!,
                                title: titleCtrl.text,
                                notes: v,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: cloudItems.isEmpty
                          ? const Center(
                        child: Text('No hay canciones en este setlist'),
                      )
                          : ReorderableListView.builder(
                        itemCount: cloudItems.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex--;

                          final reordered = List<Map<String, dynamic>>.from(cloudItems);
                          final moved = reordered.removeAt(oldIndex);
                          reordered.insert(newIndex, moved);

                          final ids = reordered
                              .map((e) => e['docId'] as String)
                              .toList();

                          await cloudRepo.reorder(
                            setlistId: cloudSetlistId!,
                            itemIdsInOrder: ids,
                          );

                          _markDirty(() {
                            final localItems = reordered.map((e) {
                              return {
                                'songId': e['songId'],
                                'title': e['title'],
                                'order': e['position'] ?? 0,
                                'steps': e['steps'] ?? 0,
                                'baseKey': e['baseKey'] ?? 'C',
                              };
                            }).toList();

                            for (var i = 0; i < localItems.length; i++) {
                              localItems[i]['order'] = i;
                            }

                            setlist!['items'] = localItems;
                          });

                          await setlistRepo.upsert(setlist!);
                        },
                        itemBuilder: (context, index) {
                          final item = cloudItems[index];
                          final baseKey = item['baseKey'] ?? 'C';
                          final steps = item['steps'] ?? 0;
                          final mode = (item['mode'] ?? 'chordpro').toString();

                          final canTranspose = mode == 'chordpro' || mode == 'score';
                          final newKey = canTranspose ? transposeChord(baseKey, steps) : baseKey;

                          String tipoLabel;
                          switch (mode) {
                            case 'score':
                              tipoLabel = 'Partitura editable';
                              break;
                            case 'score_image':
                              tipoLabel = 'Partitura por imagen';
                              break;
                            case 'score_pdf':
                              tipoLabel = 'Partitura por PDF';
                              break;
                            default:
                              tipoLabel = 'Letra/Acordes';
                          }

                          return Card(
                            key: ValueKey(item['docId']),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              title: Text(item['title'] ?? 'Sin título'),
                              subtitle: Text(
                                canTranspose
                                    ? 'Tono: $baseKey → $newKey  (${steps >= 0 ? '+' : ''}$steps semitonos)'
                                    : 'Tipo: $tipoLabel',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canTranspose) ...[
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () async {
                                        await cloudRepo.updateSteps(
                                          setlistId: cloudSetlistId!,
                                          itemId: item['docId'],
                                          steps: steps - 1,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () async {
                                        await cloudRepo.updateSteps(
                                          setlistId: cloudSetlistId!,
                                          itemId: item['docId'],
                                          steps: steps + 1,
                                        );
                                      },
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await cloudRepo.removeItem(
                                        setlistId: cloudSetlistId!,
                                        itemId: item['docId'],
                                      );
                                    },
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
            );
          },
        );
      },
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