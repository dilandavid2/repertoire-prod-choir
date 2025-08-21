// Transposición semitono a semitono para acordes [C], [G/B], etc.

const _sharp = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
const _flat  = ['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'];

int _idx(String n) {
  switch (n) {
    case 'C': case 'B#': return 0;
    case 'C#': case 'Db': return 1;
    case 'D': return 2;
    case 'D#': case 'Eb': return 3;
    case 'E': case 'Fb': return 4;
    case 'F': case 'E#': return 5;
    case 'F#': case 'Gb': return 6;
    case 'G': return 7;
    case 'G#': case 'Ab': return 8;
    case 'A': return 9;
    case 'A#': case 'Bb': return 10;
    case 'B': case 'Cb': return 11;
  }
  throw ArgumentError('Nota inválida: $n');
}

({String root, String suffix}) _split(String chord) {
  final m = RegExp(r'^([A-G](?:#|b)?)(.*)$').firstMatch(chord.trim());
  if (m == null) return (root: chord, suffix: '');
  return (root: m.group(1)!, suffix: m.group(2)!);
}

String transposeChord(String chord, int steps) {
  if (chord.contains('/')) {
    final p = chord.split('/');
    return '${transposeChord(p[0], steps)}/${transposeChord(p[1], steps)}';
  }
  final s = _split(chord);
  final base = _idx(s.root);
  final target = (base + steps) % 12;
  final preferSharp = s.root.contains('#');
  final preferFlat  = s.root.contains('b');

  String note;
  if (!preferSharp && !preferFlat) {
    note = steps >= 0 ? _sharp[target] : _flat[target];
  } else {
    note = preferSharp ? _sharp[target] : _flat[target];
  }
  return '$note${s.suffix}';
}

String transposeChordProLine(String line, int steps) {
  return line.replaceAllMapped(RegExp(r'\[([^\]]+)\]'), (m) {
    return '[${transposeChord(m.group(1)!.trim(), steps)}]';
  });
}

String transposeChordProBody(String body, int steps) =>
    body.split('\n').map((l) => transposeChordProLine(l, steps)).join('\n');


String stripChordProLine(String line) =>
    line.replaceAll(RegExp(r'\[([^\]]+)\]'), '');

String stripChordProBody(String body) =>
    body.split('\n').map(stripChordProLine).join('\n');