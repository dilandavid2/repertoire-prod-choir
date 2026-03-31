import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/setlist_cloud_repository.dart';
import '../../core/utils/transpose.dart';

class LiveViewScreen extends StatefulWidget {
  final String setlistId;
  const LiveViewScreen({super.key, required this.setlistId});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  final setlistRepo = SetlistRepo();
  final songRepo = SongRepo();
  final cloudRepo = SetlistCloudRepo();

  late PageController _page;
  int _index = 0;
  double _fontSize = 20;

  bool _keepAwake = true;
  bool _hideChords = false;

  String? _cloudSetlistId;

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _load();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _page.dispose();
    super.dispose();
  }

  void _load() {
    final setlist = setlistRepo.getById(widget.setlistId);
    _cloudSetlistId = setlist?['cloudId'] as String?;
    if (mounted) setState(() {});
  }

  void _prev() {
    if (_index > 0) {
      _page.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _next(int total) {
    if (_index < total - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _smaller() => setState(() => _fontSize = (_fontSize - 2).clamp(14, 42));
  void _bigger() => setState(() => _fontSize = (_fontSize + 2).clamp(14, 42));

  @override
  Widget build(BuildContext context) {
    if (_cloudSetlistId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: cloudRepo.watchSetlist(_cloudSetlistId!).map((doc) => doc.data()),
      builder: (context, setlistSnap) {
        if (!setlistSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final setlistData = setlistSnap.data!;
        final setlistTitle = setlistData['title'] ?? 'Vista en vivo';

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: cloudRepo.watchItems(_cloudSetlistId!).map((snapshot) {
            final docs = snapshot.docs.map((d) {
              final data = d.data();
              data['docId'] = d.id;
              return data;
            }).toList();

            docs.sort((a, b) =>
                ((a['position'] ?? 0) as int).compareTo((b['position'] ?? 0) as int));

            return docs;
          }),
          builder: (context, itemsSnap) {
            if (!itemsSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final items = itemsSnap.data!;

            final songs = items.map<_LiveSong>((it) {
              final song = songRepo.getById(it['songId'] as String? ?? '') ?? {};
              final title = (it['title'] ?? song['title'] ?? '(sin título)') as String;
              final body = (it['bodyChordPro'] ?? song['bodyChordPro'] ?? '') as String;
              final steps = (it['steps'] ?? 0) as int;
              final transposed = transposeChordProBody(body, steps);
              return _LiveSong(title: title, body: transposed);
            }).toList();

            return Scaffold(
              appBar: AppBar(
                title: Text('$setlistTitle • ${songs.isEmpty ? 0 : _index + 1}/${songs.length}'),
                actions: [
                  IconButton(
                    tooltip: 'Letra más pequeña',
                    onPressed: _smaller,
                    icon: const Icon(Icons.text_decrease),
                  ),
                  IconButton(
                    tooltip: 'Letra más grande',
                    onPressed: _bigger,
                    icon: const Icon(Icons.text_increase),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'toggle_awake':
                          _keepAwake = !_keepAwake;
                          _keepAwake
                              ? await WakelockPlus.enable()
                              : await WakelockPlus.disable();
                          setState(() {});
                          break;
                        case 'toggle_chords':
                          setState(() => _hideChords = !_hideChords);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle_awake',
                        child: Row(
                          children: [
                            Icon(
                              _keepAwake ? Icons.visibility : Icons.visibility_off,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_keepAwake
                                ? 'Pantalla siempre encendida: ON'
                                : 'Pantalla siempre encendida: OFF'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_chords',
                        child: Row(
                          children: [
                            Icon(_hideChords ? Icons.music_off : Icons.music_note, size: 20),
                            const SizedBox(width: 8),
                            Text(_hideChords ? 'Mostrar acordes' : 'Ocultar acordes'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: songs.isEmpty
                  ? const Center(child: Text('Este setlist no tiene canciones.'))
                  : Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: songs.length,
                      itemBuilder: (context, i) {
                        final s = songs[i];
                        final text =
                        _hideChords ? stripChordProBody(s.body) : s.body;
                        return _SongSlide(
                          title: s.title,
                          body: text,
                          fontSize: _fontSize,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _prev,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () => _next(songs.length),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Siguiente'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SongSlide extends StatelessWidget {
  final String title;
  final String body;
  final double fontSize;
  const _SongSlide({
    required this.title,
    required this.body,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: fontSize + 6, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    body.isEmpty ? '(sin letra)' : body,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: fontSize,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSong {
  final String title;
  final String body;
  _LiveSong({required this.title, required this.body});
}