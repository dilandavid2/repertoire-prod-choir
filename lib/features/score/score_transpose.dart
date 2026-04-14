import 'score_models.dart';

const List<String> _sharpNotes = <String>[
  'C', 'C#', 'D', 'D#', 'E', 'F',
  'F#', 'G', 'G#', 'A', 'A#', 'B'
];

const List<String> _flatNotes = <String>[
  'C', 'Db', 'D', 'Eb', 'E', 'F',
  'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
];

int _noteIndex(String note) {
  switch (note) {
    case 'C':
    case 'B#':
      return 0;
    case 'C#':
    case 'Db':
      return 1;
    case 'D':
      return 2;
    case 'D#':
    case 'Eb':
      return 3;
    case 'E':
    case 'Fb':
      return 4;
    case 'F':
    case 'E#':
      return 5;
    case 'F#':
    case 'Gb':
      return 6;
    case 'G':
      return 7;
    case 'G#':
    case 'Ab':
      return 8;
    case 'A':
      return 9;
    case 'A#':
    case 'Bb':
      return 10;
    case 'B':
    case 'Cb':
      return 11;
    default:
      throw ArgumentError('Nota inválida: $note');
  }
}

class _ParsedPitch {
  final String note;
  final int octave;

  const _ParsedPitch({
    required this.note,
    required this.octave,
  });
}

_ParsedPitch _parsePitch(String pitch) {
  final match = RegExp(r'^([A-G](?:#|b)?)(-?\d+)$').firstMatch(pitch.trim());
  if (match == null) {
    throw ArgumentError('Pitch inválido: $pitch');
  }

  return _ParsedPitch(
    note: match.group(1)!,
    octave: int.parse(match.group(2)!),
  );
}

String transposePitch(String pitch, int semitones) {
  final parsed = _parsePitch(pitch);
  final originalIndex = _noteIndex(parsed.note);

  final midi = ((parsed.octave + 1) * 12) + originalIndex;
  final transposedMidi = midi + semitones;

  final newOctave = (transposedMidi ~/ 12) - 1;
  final newIndex = transposedMidi % 12;

  final preferFlat = parsed.note.contains('b');
  final newNote = preferFlat ? _flatNotes[newIndex] : _sharpNotes[newIndex];

  return '$newNote$newOctave';
}

int comparePitches(String a, String b) {
  final pa = _parsePitch(a);
  final pb = _parsePitch(b);

  final ma = (pa.octave + 1) * 12 + _noteIndex(pa.note);
  final mb = (pb.octave + 1) * 12 + _noteIndex(pb.note);

  return ma.compareTo(mb);
}

List<String> normalizeChordPitches(List<String> pitches) {
  final copy = List<String>.from(pitches);
  copy.sort(comparePitches);
  return copy;
}

ScoreNote transposeScoreNote(ScoreNote note, int semitones) {
  if (note.isRest) return note;
  if (note.pitches.isEmpty) return note;

  final transposed = note.pitches
      .map((p) => transposePitch(p, semitones))
      .toList();

  return note.copyWith(
    pitches: normalizeChordPitches(transposed),
  );
}

ScoreMeasure transposeScoreMeasure(ScoreMeasure measure, int semitones) {
  return measure.copyWith(
    notes: measure.notes
        .map((n) => transposeScoreNote(n, semitones))
        .toList(),
  );
}

ScoreDocument transposeScoreDocument(ScoreDocument document, int semitones) {
  return document.copyWith(
    measures: document.measures
        .map((m) => transposeScoreMeasure(m, semitones))
        .toList(),
  );
}
String getKeySignatureAccidental(String noteLetter, String key) {
  final map = {
    'G': {'F': '#'},
    'D': {'F': '#', 'C': '#'},
    'A': {'F': '#', 'C': '#', 'G': '#'},
    'E': {'F': '#', 'C': '#', 'G': '#', 'D': '#'},
    'B': {'F': '#', 'C': '#', 'G': '#', 'D': '#', 'A': '#'},
    'F': {'B': 'b'},
    'Bb': {'B': 'b', 'E': 'b'},
    'Eb': {'B': 'b', 'E': 'b', 'A': 'b'},
  };

  return map[key]?[noteLetter] ?? '';
}