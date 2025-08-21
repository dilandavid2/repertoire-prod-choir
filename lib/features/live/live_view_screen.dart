import 'package:flutter/material.dart';
import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/transpose.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

class LiveViewScreen extends StatefulWidget {
  final String setlistId;
  const LiveViewScreen({super.key, required this.setlistId});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  final setlistRepo = SetlistRepo();
  final songRepo = SongRepo();

  late PageController _page;
  int _index = 0;
  double _fontSize = 20; // se puede ajustar en vivo

  String _setlistTitle = '';
  late List<_LiveSong> _songs = [];

  bool _keepAwake = true;   // pantalla siempre encendida (wakelock)
  bool _hideChords = false; // ocultar/mostrar acordes

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _load();
    WakelockPlus.enable(); // pantalla encendida por defecto
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _page.dispose();
    super.dispose();
  }

  void _load() {
    final setlist = setlistRepo.getById(widget.setlistId);
    _setlistTitle = setlist?['title'] ?? 'Vista en vivo';
    final items = (setlist?['items'] as List? ?? []).cast<Map>();

    _songs = items.map<_LiveSong>((it) {
      final song = songRepo.getById(it['songId'] as String? ?? '') ?? {};
      final title = (it['title'] ?? song['title'] ?? '(sin título)') as String;
      final body = (song['bodyChordPro'] ?? '') as String;
      final steps = (it['steps'] ?? 0) as int;
      final transposed = transposeChordProBody(body, steps);
      return _LiveSong(title: title, body: transposed);
    }).toList();

    if (mounted) setState(() {});
  }

  void _prev() {
    if (_index > 0) _page.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _next() {
    if (_index < _songs.length - 1) _page.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _smaller() => setState(() => _fontSize = (_fontSize - 2).clamp(14, 42));
  void _bigger()  => setState(() => _fontSize = (_fontSize + 2).clamp(14, 42));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_setlistTitle • ${_songs.isEmpty ? 0 : _index + 1}/${_songs.length}'),
        actions: [
          IconButton(tooltip: 'Letra más pequeña', onPressed: _smaller, icon: const Icon(Icons.text_decrease)),
          IconButton(tooltip: 'Letra más grande',   onPressed: _bigger,  icon: const Icon(Icons.text_increase)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'toggle_awake':
                  _keepAwake = !_keepAwake;
                  _keepAwake ? await WakelockPlus.enable() : await WakelockPlus.disable();
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
                    Icon(_keepAwake ? Icons.visibility : Icons.visibility_off, size: 20),
                    const SizedBox(width: 8),
                    Text(_keepAwake ? 'Pantalla siempre encendida: ON' : 'Pantalla siempre encendida: OFF'),
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
      body: _songs.isEmpty
          ? const Center(child: Text('Este setlist no tiene canciones.'))
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemCount: _songs.length,
                    itemBuilder: (context, i) {
                      final s = _songs[i];
                      // ⬇️ Si _hideChords está activo, quitamos [C], [G/B], etc.
                      final text = _hideChords ? stripChordProBody(s.body) : s.body;
                      return _SongSlide(title: s.title, body: text, fontSize: _fontSize);
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _prev,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Anterior'),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Siguiente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SongSlide extends StatelessWidget {
  final String title;
  final String body;
  final double fontSize;
  const _SongSlide({required this.title, required this.body, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: fontSize + 6, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    body.isEmpty ? '(sin letra)' : body,
                    style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, height: 1.4),
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