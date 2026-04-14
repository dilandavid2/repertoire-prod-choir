import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/repositories/setlist_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/setlist_cloud_repository.dart';
import '../../core/utils/transpose.dart';

import '../score/score_models.dart';
import '../score/score_transpose.dart';
import '../score/score_view_widget.dart';

import 'gesture_controller.dart';

import 'dart:io';

import 'dart:async';

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
  GestureController? _gestureController;
  bool _gesturesEnabled = false;
  final ScrollController _verticalScrollController = ScrollController();
  double _currentPitch = 0;

  bool _pageGesturesEnabled = false;
  bool _pitchScrollEnabled = false;
  bool _autoScrollEnabled = false;

  double _autoScrollSpeed = 10.0;
  Timer? _autoScrollTimer;

  final Map<int, int> _scorePageBySongIndex = {};
  static const int _measuresPerScorePage = 2;
  List<_LiveSong> _currentSongs = [];

  late PageController _page;
  int _index = 0;
  int _songsCount = 0;
  double _fontSize = 20;
  double _currentYaw = 0;


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

  Future<void> _toggleCameraGestures() async {
    final shouldEnable = !_gesturesEnabled;

    if (!shouldEnable) {
      await _gestureController?.dispose();
      _gestureController = null;

      setState(() {
        _gesturesEnabled = false;
        _pageGesturesEnabled = false;
        _pitchScrollEnabled = false;
      });
      return;
    }

    _gestureController = GestureController(
      onLeft: () {
        if (_pageGesturesEnabled) _prev();
      },
      onRight: () {
        if (_pageGesturesEnabled) _next(_songsCount);
      },
      onYaw: (yaw) {
        setState(() {
          _currentYaw = yaw;
        });
      },
      onPitch: (pitch) {
        if (_pitchScrollEnabled) {
          _handlePitchScroll(pitch);
        } else {
          setState(() {
            _currentPitch = pitch;
          });
        }
      },
    );

    await _gestureController!.init();

    setState(() {
      _gesturesEnabled = true;
      _pageGesturesEnabled = true;
      _pitchScrollEnabled = false;
    });
  }

  bool _currentSongSupportsVerticalScroll() {
    if (_index < 0 || _index >= _currentSongs.length) return false;
    final current = _currentSongs[_index];
    return current.mode == 'score_image' || current.mode == 'score_pdf';
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!_autoScrollEnabled) return;
      if (!_verticalScrollController.hasClients) return;
      if (!_currentSongSupportsVerticalScroll()) return;

      final position = _verticalScrollController.position;
      final target = (_verticalScrollController.offset + _autoScrollSpeed)
          .clamp(position.minScrollExtent, position.maxScrollExtent);

      if (target == _verticalScrollController.offset) return;

      _verticalScrollController.jumpTo(target);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScrollEnabled = !_autoScrollEnabled;
    });

    if (_autoScrollEnabled) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _handlePitchScroll(double pitch) {
    _currentPitch = pitch;

    if (_autoScrollEnabled) {
      setState(() {
        _currentPitch = pitch;
      });
      return;
    }

    if (!mounted) return;
    if (!_verticalScrollController.hasClients) return;
    if (_index < 0 || _index >= _currentSongs.length) return;

    final current = _currentSongs[_index];
    final supportsVerticalScroll =
        current.mode == 'score_image' || current.mode == 'score_pdf';

    if (!supportsVerticalScroll) {
      setState(() {});
      return;
    }

    const double deadZone = 8.0;
    const double maxStep = 18.0;

    double delta = 0;

    if (pitch > deadZone) {
      delta = maxStep;
    } else if (pitch < -deadZone) {
      delta = -maxStep;
    }

    if (delta == 0) {
      setState(() {});
      return;
    }

    final position = _verticalScrollController.position;
    final target = (_verticalScrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    _verticalScrollController.jumpTo(target);

    setState(() {});
  }

  @override
  void dispose() {
    _gestureController?.dispose();
    _stopAutoScroll();
    _verticalScrollController.dispose();
    WakelockPlus.disable();
    _page.dispose();
    super.dispose();
  }

  void _load() {
    final setlist = setlistRepo.getById(widget.setlistId);
    _cloudSetlistId = setlist != null ? setlist['cloudId'] as String? : null;
    if (mounted) setState(() {});
  }

  void _resetVerticalScroll() {
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.jumpTo(0);
    }
  }

  int _pdfTotalPages(List<String> pages) {
    return pages.isEmpty ? 1 : pages.length;
  }

  int _imageTotalPages(List<String> pages) {
    return pages.isEmpty ? 1 : pages.length;
  }

  int _scoreTotalPages(ScoreDocument? score) {
    if (score == null || score.measures.isEmpty) return 1;
    return (score.measures.length / _measuresPerScorePage).ceil();
  }

  void _prev() {
    final songs = _currentSongs;
    if (_index < 0 || _index >= songs.length) return;

    final current = songs[_index];

    if (current.mode == 'score' && current.score != null) {
      final currentPage = _scorePageBySongIndex[_index] ?? 0;

      if (currentPage > 0) {
        setState(() {
          _resetVerticalScroll();
          _scorePageBySongIndex[_index] = currentPage - 1;
        });
        return;
      }
    }

    if (current.mode == 'score_image' && current.imagePages.isNotEmpty) {
      final currentPage = _scorePageBySongIndex[_index] ?? 0;

      if (currentPage > 0) {
        setState(() {
          _resetVerticalScroll();
          _scorePageBySongIndex[_index] = currentPage - 1;
        });
        return;
      }
    }

    if (current.mode == 'score_pdf' && current.pdfPages.isNotEmpty) {
      final currentPage = _scorePageBySongIndex[_index] ?? 0;

      if (currentPage > 0) {
        setState(() {
          _resetVerticalScroll();
          _scorePageBySongIndex[_index] = currentPage - 1;
        });
        return;
      }
    }

    if (_index > 0) {
      _page.animateToPage(
        _index - 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _next(int total) {
    final songs = _currentSongs;

    if (_index < 0 || _index >= songs.length) return;

    final current = songs[_index];

    if (current.mode == 'score' && current.score != null) {
      final currentPage = _scorePageBySongIndex[_index] ?? 0;
      final totalPages = _scoreTotalPages(current.score);

      if (currentPage < totalPages - 1) {
        setState(() {
          _resetVerticalScroll();
          _scorePageBySongIndex[_index] = currentPage + 1;
        });
        return;
      }
    }

    if (current.mode == 'score_image' && current.imagePages.isNotEmpty) {
      final currentPage = _scorePageBySongIndex[_index] ?? 0;
      final totalPages = _imageTotalPages(current.imagePages);

      if (currentPage < totalPages - 1) {
        setState(() {
          _resetVerticalScroll();
          _scorePageBySongIndex[_index] = currentPage + 1;
        });
        return;
      }
    }

    if (current.mode == 'score_pdf' && current.pdfPages.isNotEmpty) {
      final currentPage = _scorePageBySongIndex[_index] ?? 0;
      final totalPages = _pdfTotalPages(current.pdfPages);

      if (currentPage < totalPages - 1) {
        setState(() {
          _resetVerticalScroll();
          _scorePageBySongIndex[_index] = currentPage + 1;
        });
        return;
      }
    }

    if (_index < total - 1) {
      _page.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  String _hideChordsFromBody(String body) {
    return body.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]'),
          (_) => '',
    );
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

              final title = (it['title'] ?? song['title'] ?? '(sin título)').toString();
              final steps = (it['steps'] ?? 0) as int;
              final mode = (song['mode'] ?? 'chordpro').toString();

              // ===================== SCORE EDITABLE =====================
              if (mode == 'score') {
                ScoreDocument? score;

                final rawScore = song['scoreData'];
                if (rawScore is Map) {
                  score = ScoreDocument.fromMap(
                    Map<String, dynamic>.from(rawScore),
                  );
                  if (steps != 0) {
                    score = transposeScoreDocument(score, steps);
                  }
                }

                return _LiveSong(
                  title: title,
                  mode: mode,
                  body: '',
                  score: score,
                  imagePages: const [],
                  pdfPages: const [],
                );
              }

              // ===================== SCORE IMAGE =====================
              if (mode == 'score_image') {
                final rawPages = song['imagePages'];
                final pages = rawPages is List
                    ? rawPages.map((e) => e.toString()).toList()
                    : <String>[];

                return _LiveSong(
                  title: title,
                  mode: mode,
                  body: '',
                  score: null,
                  imagePages: pages,
                  pdfPages: const [],
                );
              }

              // ===================== SCORE PDF =====================
              if (mode == 'score_pdf') {
                final rawPages = song['pdfPages'];
                final pages = rawPages is List
                    ? rawPages.map((e) => e.toString()).toList()
                    : <String>[];

                return _LiveSong(
                  title: title,
                  mode: mode,
                  body: '',
                  score: null,
                  imagePages: const [],
                  pdfPages: pages,
                );
              }

              // ===================== TEXTO =====================
              final body = (it['bodyChordPro'] ?? song['bodyChordPro'] ?? '').toString();
              final transposed = transposeChordProBody(body, steps);

              return _LiveSong(
                title: title,
                mode: mode,
                body: transposed,
                score: null,
                imagePages: const [],
                pdfPages: const [],
              );
            }).toList();

            _currentSongs = songs;
            _songsCount = songs.length;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  '$setlistTitle • ${songs.isEmpty ? 0 : _index + 1}/${songs.length}',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Letra más pequeña',
                    onPressed: _smaller,
                    icon: const Icon(Icons.text_decrease),
                  ),
                  IconButton(
                    icon: Icon(_gesturesEnabled ? Icons.videocam : Icons.videocam_off),
                    onPressed: _toggleCameraGestures,
                  ),
                  Icon(
                    _gesturesEnabled ? Icons.remove_red_eye : Icons.remove_red_eye_outlined,
                    color: _gesturesEnabled ? Colors.green : Colors.grey,
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
                        case 'toggle_page_gestures':
                          if (_gesturesEnabled) {
                            setState(() {
                              _pageGesturesEnabled = !_pageGesturesEnabled;
                            });
                          }
                          break;

                        case 'toggle_pitch_scroll':
                          if (_gesturesEnabled) {
                            setState(() {
                              _pitchScrollEnabled = !_pitchScrollEnabled;
                            });
                          }
                          break;

                        case 'toggle_auto_scroll':
                          _toggleAutoScroll();
                          break;

                        case 'speed_up_auto_scroll':
                          setState(() {
                            _autoScrollSpeed = (_autoScrollSpeed + 2).clamp(2.0, 40.0);
                          });
                          if (_autoScrollEnabled) _startAutoScroll();
                          break;

                        case 'speed_down_auto_scroll':
                          setState(() {
                            _autoScrollSpeed = (_autoScrollSpeed - 2).clamp(2.0, 40.0);
                          });
                          if (_autoScrollEnabled) _startAutoScroll();
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
                      PopupMenuItem(
                        value: 'toggle_page_gestures',
                        child: Row(
                          children: [
                            Icon(
                              _pageGesturesEnabled ? Icons.swipe : Icons.swipe_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_pageGesturesEnabled
                                ? 'Gestos pasar página: ON'
                                : 'Gestos pasar página: OFF'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_pitch_scroll',
                        child: Row(
                          children: [
                            Icon(
                              _pitchScrollEnabled ? Icons.unfold_more : Icons.unfold_more_double,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_pitchScrollEnabled
                                ? 'Scroll con gestos: ON'
                                : 'Scroll con gestos: OFF'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_auto_scroll',
                        child: Row(
                          children: [
                            Icon(
                              _autoScrollEnabled ? Icons.play_circle : Icons.pause_circle,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_autoScrollEnabled
                                ? 'Auto-scroll: ON'
                                : 'Auto-scroll: OFF'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'speed_down_auto_scroll',
                        child: Row(
                          children: [
                            const Icon(Icons.remove, size: 20),
                            const SizedBox(width: 8),
                            Text('Velocidad auto-scroll -'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'speed_up_auto_scroll',
                        child: Row(
                          children: [
                            const Icon(Icons.add, size: 20),
                            const SizedBox(width: 8),
                            Text('Velocidad auto-scroll +'),
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
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        _resetVerticalScroll();
                      },
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        final s = songs[i];

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                  s.title,
                                  style: TextStyle(
                                    fontSize: _fontSize + 6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  _currentYaw > 20
                                      ? "➡️ Derecha (${_currentYaw.toStringAsFixed(1)})"
                                      : _currentYaw < -20
                                      ? "⬅️ Izquierda (${_currentYaw.toStringAsFixed(1)})"
                                      : "Centro (${_currentYaw.toStringAsFixed(1)})",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                ),

                                const SizedBox(height: 4),
                                Text(
                                  'Scroll gestos: ${_pitchScrollEnabled ? 'ON' : 'OFF'}  ·  Auto-scroll: ${_autoScrollEnabled ? 'ON' : 'OFF'}  ·  Velocidad: ${_autoScrollSpeed.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                if (s.mode == 'score' && s.score != null)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            ScoreViewWidget(
                                              document: s.score!,
                                              fontSize: _fontSize + 2,
                                              measuresPerPage: _measuresPerScorePage,
                                              pageIndex: _scorePageBySongIndex[i] ?? 0,
                                              measureStartIndex:
                                              (_scorePageBySongIndex[i] ?? 0) * _measuresPerScorePage,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Página ${(_scorePageBySongIndex[i] ?? 0) + 1} de ${_scoreTotalPages(s.score)}',
                                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else if (s.mode == 'score_image' && s.imagePages.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            controller: _verticalScrollController,
                                            child: Image.file(
                                              File(s.imagePages[_scorePageBySongIndex[i] ?? 0]),
                                              fit: BoxFit.fitWidth,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Página ${(_scorePageBySongIndex[i] ?? 0) + 1} de ${_imageTotalPages(s.imagePages)}',
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Pitch: ${_currentPitch.toStringAsFixed(1)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (s.mode == 'score_pdf' && s.pdfPages.isNotEmpty)
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: SingleChildScrollView(
                                              controller: _verticalScrollController,
                                              child: Image.file(
                                                File(s.pdfPages[_scorePageBySongIndex[i] ?? 0]),
                                                fit: BoxFit.fitWidth,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Página ${(_scorePageBySongIndex[i] ?? 0) + 1} de ${_pdfTotalPages(s.pdfPages)}',
                                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Pitch: ${_currentPitch.toStringAsFixed(1)}',
                                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: SelectableText(
                                          _hideChords ? _hideChordsFromBody(s.body) : s.body,
                                          style: TextStyle(
                                            fontSize: _fontSize,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    )
                            ],
                          ),
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
  final String mode;
  final String body;
  final ScoreDocument? score;
  final List<String> imagePages;
  final List<String> pdfPages;

  const _LiveSong({
    required this.title,
    required this.mode,
    required this.body,
    required this.score,
    required this.imagePages,
    required this.pdfPages,
  });
}