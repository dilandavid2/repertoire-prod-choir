import 'package:flutter/material.dart';

import '../../data/repositories/song_repository.dart';
import 'score_models.dart';
import 'score_transpose.dart';
import 'score_view_widget.dart';

class ScoreEditorScreen extends StatefulWidget {
  final String? songId;

  const ScoreEditorScreen({
    super.key,
    this.songId,
  });

  @override
  State<ScoreEditorScreen> createState() => _ScoreEditorScreenState();
}

class _ScoreEditorScreenState extends State<ScoreEditorScreen> {
  final SongRepo repo = SongRepo();

  final TextEditingController titleCtrl = TextEditingController();

  bool _modoAcorde = false;
  List<String> _acordeActual = [];

  String? id;
  String baseKey = 'C';
  ScoreDocument document = ScoreDocument.empty();

  final List<String> _keys = <String>[
    'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#',
    'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb',
  ];

  final List<String> _timeSignatures = <String>[
    '4/4', '3/4', '2/4', '6/8',
  ];

  final List<String> _clefs = <String>[
    'treble',
    'bass',
  ];

  final List<String> _durations = <String>[
    'whole',
    'half',
    'quarter',
    'eighth',
  ];

  String _selectedNoteLetter = 'C';
  String _selectedAccidental = '';
  int _selectedOctave = 4;
  String _selectedDuration = 'quarter';
  bool _insertRest = false;
  bool _tieToNext = false;
  bool _slurToNext = false;
  int? _selectedMeasureIndex;
  int? _selectedNoteIndex;

  @override
  void initState() {
    super.initState();
    _loadSong();
  }



  void _loadSong() {
    if (widget.songId == null) return;

    final song = repo.getById(widget.songId!);
    if (song == null) return;

    id = song['id'] as String?;
    titleCtrl.text = (song['title'] ?? '').toString();
    baseKey = (song['baseKey'] ?? 'C').toString();

    final rawScoreData = song['scoreData'];
    if (rawScoreData is Map) {
      document = ScoreDocument.fromMap(
        Map<String, dynamic>.from(rawScoreData),
      );
    } else {
      document = ScoreDocument.empty().copyWith(
        keySignature: baseKey,
      );
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  String _buildPitch() {
    if (_selectedAccidental == 'n') {
      return '$_selectedNoteLetter$_selectedOctave'; // sin accidental
    }
    return '$_selectedNoteLetter$_selectedAccidental$_selectedOctave';
  }

  String _applyKeySignatureToPitch(String pitch) {
    final parsed = _parseEditorPitch(pitch);
    final noteLetter = parsed.$1;
    final accidental = parsed.$2;
    final octave = parsed.$3;

    if (_selectedAccidental == 'n') {
      return '$noteLetter$octave'; // fuerza natural
    }

    if (accidental.isNotEmpty) return pitch;

    final keyAcc = _keySignatureAccidentalForLetter(
      noteLetter,
      document.keySignature,
    );

    return '$noteLetter$keyAcc$octave';
  }

  String _keySignatureAccidentalForLetter(String noteLetter, String key) {
    final map = {
      'G': {'F': '#'},
      'D': {'F': '#', 'C': '#'},
      'A': {'F': '#', 'C': '#', 'G': '#'},
      'E': {'F': '#', 'C': '#', 'G': '#', 'D': '#'},
      'B': {'F': '#', 'C': '#', 'G': '#', 'D': '#', 'A': '#'},
      'F#': {'F': '#', 'C': '#', 'G': '#', 'D': '#', 'A': '#', 'E': '#'},
      'C#': {'F': '#', 'C': '#', 'G': '#', 'D': '#', 'A': '#', 'E': '#', 'B': '#'},
      'F': {'B': 'b'},
      'Bb': {'B': 'b', 'E': 'b'},
      'Eb': {'B': 'b', 'E': 'b', 'A': 'b'},
      'Ab': {'B': 'b', 'E': 'b', 'A': 'b', 'D': 'b'},
      'Db': {'B': 'b', 'E': 'b', 'A': 'b', 'D': 'b', 'G': 'b'},
      'Gb': {'B': 'b', 'E': 'b', 'A': 'b', 'D': 'b', 'G': 'b', 'C': 'b'},
      'Cb': {'B': 'b', 'E': 'b', 'A': 'b', 'D': 'b', 'G': 'b', 'C': 'b', 'F': 'b'},
    };

    return map[key]?[noteLetter] ?? '';
  }

  void _addMeasure() {
    setState(() {
      final updated = List<ScoreMeasure>.from(document.measures)
        ..add(const ScoreMeasure(notes: <ScoreNote>[]));
      document = document.copyWith(measures: updated);
    });
  }

  void _removeLastMeasure() {
    if (document.measures.isEmpty) return;
    setState(() {
      final updated = List<ScoreMeasure>.from(document.measures)..removeLast();
      document = document.copyWith(
        measures: updated.isEmpty
            ? <ScoreMeasure>[const ScoreMeasure(notes: <ScoreNote>[])]
            : updated,
      );
    });
  }

  void _addNoteToMeasure(int measureIndex) {
    final measures = List<ScoreMeasure>.from(document.measures);
    final measure = measures[measureIndex];
    final notes = List<ScoreNote>.from(measure.notes);

    final pitchesToInsert = _insertRest
        ? <String>[]
        : (_modoAcorde
        ? normalizeChordPitches(
      _acordeActual.map(_applyKeySignatureToPitch).toList(),
    )
        : <String>[_applyKeySignatureToPitch(_buildPitch())]);

    if (!_insertRest && pitchesToInsert.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una nota al acorde')),
      );
      return;
    }


    notes.add(
      ScoreNote(
        pitches: pitchesToInsert,
        duration: _selectedDuration,
        isRest: _insertRest,
        tieToNext: _tieToNext,
        slurToNext: _slurToNext,
      ),
    );

    measures[measureIndex] = measure.copyWith(notes: notes);

    setState(() {
      document = document.copyWith(measures: measures);
      _acordeActual.clear();
    });
  }

  void _removeLastNoteFromMeasure(int measureIndex) {
    final measures = List<ScoreMeasure>.from(document.measures);
    final measure = measures[measureIndex];
    final notes = List<ScoreNote>.from(measure.notes);

    if (notes.isEmpty) return;

    notes.removeLast();
    measures[measureIndex] = measure.copyWith(notes: notes);

    setState(() {
      document = document.copyWith(measures: measures);
    });
  }

  void _selectNote(int measureIndex, int noteIndex) {
    final note = document.measures[measureIndex].notes[noteIndex];

    setState(() {
      _selectedMeasureIndex = measureIndex;
      _selectedNoteIndex = noteIndex;
      _selectedDuration = note.duration;
      _insertRest = note.isRest;
      _tieToNext = note.tieToNext;
      _slurToNext = note.slurToNext;

      if (!note.isRest && note.pitches.isNotEmpty) {
        final parsed = _parseEditorPitch(note.pitches.first);
        _selectedNoteLetter = parsed.$1;
        _selectedAccidental = parsed.$2;
        _selectedOctave = parsed.$3;
        _acordeActual = normalizeChordPitches(List<String>.from(note.pitches));
      } else {
        _acordeActual = [];
      }
    });
  }

  (String, String, int) _parseEditorPitch(String pitch) {
    final m = RegExp(r'^([A-G])([#b]?)(-?\d+)$').firstMatch(pitch.trim());
    if (m == null) {
      return ('C', '', 4);
    }

    return (
    m.group(1)!,
    m.group(2) ?? '',
    int.tryParse(m.group(3)!) ?? 4,
    );
  }



  void _deleteSelectedNote() {
    if (_selectedMeasureIndex == null || _selectedNoteIndex == null) return;

    final measures = List<ScoreMeasure>.from(document.measures);
    final measure = measures[_selectedMeasureIndex!];
    final notes = List<ScoreNote>.from(measure.notes);

    if (_selectedNoteIndex! < 0 || _selectedNoteIndex! >= notes.length) return;

    notes.removeAt(_selectedNoteIndex!);
    measures[_selectedMeasureIndex!] = measure.copyWith(notes: notes);

    setState(() {
      document = document.copyWith(measures: measures);
      _selectedMeasureIndex = null;
      _selectedNoteIndex = null;
    });
  }

  void _applyEditToSelectedNote() {


    if (_selectedMeasureIndex == null || _selectedNoteIndex == null) return;

    final measures = List<ScoreMeasure>.from(document.measures);
    final measure = measures[_selectedMeasureIndex!];
    final notes = List<ScoreNote>.from(measure.notes);

    if (_selectedNoteIndex! < 0 || _selectedNoteIndex! >= notes.length) return;

    final pitchesToApply = _insertRest
        ? <String>[]
        : (_modoAcorde
        ? normalizeChordPitches(
      _acordeActual.map(_applyKeySignatureToPitch).toList(),
    )
        : <String>[_applyKeySignatureToPitch(_buildPitch())]);

    notes[_selectedNoteIndex!] = ScoreNote(
      pitches: pitchesToApply,
      duration: _selectedDuration,
      isRest: _insertRest,
      tieToNext: _tieToNext,
      slurToNext: _slurToNext,
    );

    measures[_selectedMeasureIndex!] = measure.copyWith(notes: notes);

    setState(() {
      document = document.copyWith(measures: measures);
    });
  }

  void _clearSelectedNote() {
    setState(() {
      _selectedMeasureIndex = null;
      _selectedNoteIndex = null;
      _tieToNext = false;
      _slurToNext = false;
    });
  }

  void _transpose(int semitones) {
    setState(() {
      document = transposeScoreDocument(document, semitones);
    });
  }

  Future<void> _save() async {
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título a la partitura')),
      );
      return;
    }

    final existing = id != null ? repo.getById(id!) : null;

    final song = <String, dynamic>{
      ...?existing,
      'id': id,
      'title': titleCtrl.text.trim(),
      'baseKey': baseKey,
      'mode': 'score',
      'scoreFormat': 'json',
      'scoreData': document.toMap(),
      'bodyChordPro': existing?['bodyChordPro'] ?? '',
    };

    final savedId = await repo.upsert(song);

    if (!mounted) return;

    setState(() {
      id = savedId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partitura guardada')),
    );
  }

  Widget _buildTopControls() {
    return Column(
      children: [
        TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: document.clef,
                decoration: const InputDecoration(
                  labelText: 'Clave',
                  border: OutlineInputBorder(),
                ),
                items: _clefs
                    .map((c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    document = document.copyWith(clef: v);
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: document.keySignature,
                decoration: const InputDecoration(
                  labelText: 'Tonalidad',
                  border: OutlineInputBorder(),
                ),
                items: _keys
                    .map((k) => DropdownMenuItem<String>(
                  value: k,
                  child: Text(k),
                ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    baseKey = v;
                    document = document.copyWith(keySignature: v);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: document.timeSignature,
          decoration: const InputDecoration(
            labelText: 'Compás',
            border: OutlineInputBorder(),
          ),
          items: _timeSignatures
              .map((t) => DropdownMenuItem<String>(
            value: t,
            child: Text(t),
          ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              document = document.copyWith(timeSignature: v);
            });
          },
        ),
      ],
    );
  }

  Widget _buildInsertControls() {


    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Inserción de notas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Insertar silencio'),
              value: _insertRest,
              onChanged: (v) {
                setState(() {
                  _insertRest = v;
                });
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo acorde'),
              value: _modoAcorde,
              onChanged: (v) {
                setState(() {
                  _modoAcorde = v;
                  _acordeActual.clear();
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDuration,
              decoration: const InputDecoration(
                labelText: 'Duración',
                border: OutlineInputBorder(),
              ),
              items: _durations
                  .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(d),
              ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _selectedDuration = v;
                });
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ligadura con siguiente'),
              value: _tieToNext,
              onChanged: (v) {
                setState(() {
                  _tieToNext = v;
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Slur con siguiente'),
              value: _slurToNext,
              onChanged: (v) {
                setState(() {
                  _slurToNext = v;
                });
              },
            ),
            const SizedBox(height: 10),
            if (!_insertRest)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedNoteLetter,
                      decoration: const InputDecoration(
                        labelText: 'Nota',
                        border: OutlineInputBorder(),
                      ),
                      items: const ['C', 'D', 'E', 'F', 'G', 'A', 'B']
                          .map((n) => DropdownMenuItem<String>(
                        value: n,
                        child: Text(n),
                      ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedNoteLetter = v;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAccidental,
                      decoration: const InputDecoration(
                        labelText: 'Alteración',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Auto')),
                        DropdownMenuItem(value: '#', child: Text('♯')),
                        DropdownMenuItem(value: 'b', child: Text('♭')),
                        DropdownMenuItem(value: 'n', child: Text('♮')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedAccidental = v;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedOctave,
                      decoration: const InputDecoration(
                        labelText: 'Octava',
                        border: OutlineInputBorder(),
                      ),
                      items: const [2, 3, 4, 5, 6]
                          .map((o) => DropdownMenuItem<int>(
                        value: o,
                        child: Text('$o'),
                      ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedOctave = v;
                        });
                      },
                    ),
                  ),
                ],
              ),
            if (!_insertRest && _modoAcorde) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      final currentPitch = _buildPitch();
                      if (_acordeActual.contains(currentPitch)) return;
                      setState(() {
                        _acordeActual.add(currentPitch);
                      });
                    },
                    child: const Text('Agregar al acorde'),
                  ),
                  FilledButton.tonal(
                    onPressed: _acordeActual.isNotEmpty
                        ? () {
                      setState(() {
                        _acordeActual.removeLast();
                      });
                    }
                        : null,
                    child: const Text('Quitar última del acorde'),
                  ),
                  FilledButton.tonal(
                    onPressed: _acordeActual.isNotEmpty
                        ? () {
                      setState(() {
                        _acordeActual.clear();
                      });
                    }
                        : null,
                    child: const Text('Limpiar acorde'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _acordeActual.isEmpty
                    ? 'Acorde actual: vacío'
                    : 'Acorde actual: ${_acordeActual.join(", ")}',
              ),
            ],

            if (_selectedMeasureIndex != null && _selectedNoteIndex != null) ...[
              Text(
                'Nota seleccionada: compás ${_selectedMeasureIndex! + 1}, posición ${_selectedNoteIndex! + 1}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: (_selectedMeasureIndex != null && _selectedNoteIndex != null)
                      ? _applyEditToSelectedNote
                      : null,
                  child: const Text('Aplicar a seleccionada'),
                ),
                FilledButton.tonal(
                  onPressed: (_selectedMeasureIndex != null && _selectedNoteIndex != null)
                      ? _deleteSelectedNote
                      : null,
                  child: const Text('Eliminar seleccionada'),
                ),
                FilledButton.tonal(
                  onPressed: (_selectedMeasureIndex != null && _selectedNoteIndex != null)
                      ? _clearSelectedNote
                      : null,
                  child: const Text('Quitar selección'),
                ),
              ],
            ),
            if (!_insertRest) ...[
              const SizedBox(height: 8),
              Text('Nota actual: ${_buildPitch()}'),
            ],
          ],
        ),
      ),

    );

  }

  Widget _buildMeasureEditor() {
    final measures = document.measures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _addMeasure,
              icon: const Icon(Icons.add),
              label: const Text('Agregar compás'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _removeLastMeasure,
              icon: const Icon(Icons.remove),
              label: const Text('Quitar último'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (measures.isEmpty)
          const Text('No hay compases.')
        else
          Column(
            children: List.generate(measures.length, (i) {
              final measure = measures[i];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compás ${i + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(measure.notes.length, (noteIndex) {
                          final n = measure.notes[noteIndex];
                          final isSelected =
                              _selectedMeasureIndex == i && _selectedNoteIndex == noteIndex;

                          return ChoiceChip(
                            selected: isSelected,
                            avatar: Icon(
                              n.isRest ? Icons.do_not_disturb_alt : Icons.music_note,
                              size: 18,
                            ),
                            label: Text(
                              n.isRest
                                  ? 'Silencio (${n.duration})'
                                  : '${normalizeChordPitches(n.pitches).join('-')} (${n.duration})'
                                  '${n.tieToNext ? ' ~' : ''}'
                                  '${n.slurToNext ? ' ⌒' : ''}',
                            ),
                            onSelected: (_) => _selectNote(i, noteIndex),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _addNoteToMeasure(i),
                            child: const Text('Agregar nota'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () => _removeLastNoteFromMeasure(i),
                            child: const Text('Quitar última'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildTransposeBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: () => _transpose(-2),
          child: const Text('-1 tono'),
        ),
        FilledButton.tonal(
          onPressed: () => _transpose(-1),
          child: const Text('-1/2'),
        ),
        FilledButton.tonal(
          onPressed: () => _transpose(1),
          child: const Text('+1/2'),
        ),
        FilledButton.tonal(
          onPressed: () => _transpose(2),
          child: const Text('+1 tono'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Nueva partitura' : 'Editar partitura'),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.save),
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildTopControls(),
          const SizedBox(height: 12),
          _buildInsertControls(),
          const SizedBox(height: 12),
          const Text(
            'Transposición',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTransposeBar(),
          const SizedBox(height: 12),
          const Text(
            'Edición por compases',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildMeasureEditor(),
          const SizedBox(height: 12),
          const Text(
            'Vista previa',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ScoreViewWidget(
            document: document,
            fontSize: 16,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}