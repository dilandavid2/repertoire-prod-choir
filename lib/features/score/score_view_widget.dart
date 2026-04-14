import 'package:flutter/material.dart';
import 'score_models.dart';

class ScoreViewWidget extends StatelessWidget {
  final ScoreDocument document;
  final double fontSize;
  final int? measuresPerPage;
  final int pageIndex;
  final int measureStartIndex;

  const ScoreViewWidget({
    super.key,
    required this.document,
    this.fontSize = 18,
    this.measuresPerPage,
    this.pageIndex = 0,
    this.measureStartIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final allMeasures = document.measures;

    final measures = measuresPerPage == null
        ? allMeasures
        : allMeasures.skip(pageIndex * measuresPerPage!).take(measuresPerPage!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.piano, size: 18),
              label: Text('Clave: ${document.clef}'),
            ),
            Chip(
              avatar: const Icon(Icons.key, size: 18),
              label: Text('Tonalidad: ${document.keySignature}'),
            ),
            Chip(
              avatar: const Icon(Icons.space_bar, size: 18),
              label: Text('Compás: ${document.timeSignature}'),
            ),
          ],
        ),*/
        const SizedBox(height: 12),
        if (measures.isEmpty)
          const Text('No hay compases en esta partitura.')
        else
          Column(
            children: List.generate(measures.length, (index) {
              final measure = measures[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compás ${measureStartIndex + index + 1}',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _MeasurePainter(
                            measure: measure,
                            clef: document.clef,
                            keySignature: document.keySignature,
                          ),
                        ),
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
}

class _MeasurePainter extends CustomPainter {
  final ScoreMeasure measure;
  final String clef;
  final String keySignature;

  _MeasurePainter({
    required this.measure,
    required this.clef,
    required this.keySignature,
  });

  static const double _top = 28;
  static const double _left = 24;
  static const double _right = 24;
  static const double _lineGap = 18;
  static const double _noteHeadW = 18;
  static const double _noteHeadH = 13;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final paintLine = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.4;

    final staffTop = _top;
    final staffBottom = staffTop + (_lineGap * 4);
    final staffLeft = _left;
    final staffRight = size.width - _right;

    // 5 líneas del pentagrama
    for (int i = 0; i < 5; i++) {
      final y = staffTop + i * _lineGap;
      canvas.drawLine(
        Offset(staffLeft, y),
        Offset(staffRight, y),
        paintLine,
      );
    }

    // barra inicial y final del compás
    canvas.drawLine(
      Offset(staffLeft, staffTop),
      Offset(staffLeft, staffBottom),
      paintLine,
    );
    canvas.drawLine(
      Offset(staffRight, staffTop),
      Offset(staffRight, staffBottom),
      paintLine,
    );

    // dibujar clave simple como texto
    _drawClef(canvas, Offset(staffLeft + 8, staffTop + 26));

    final afterKeySignatureX = _drawKeySignature(
      canvas,
      staffLeft + 38,
      staffTop,
    );

    final notes = measure.notes;
    if (notes.isEmpty) {
      _drawCenteredText(
        canvas,
        'Compás vacío',
        Offset(size.width / 2, staffBottom + 32),
        fontSize: 14,
      );
      return;
    }

    final startX = afterKeySignatureX + 12;
    final availableWidth = (staffRight - startX - 10).clamp(40.0, 9999.0);
    final stepX = notes.length == 1 ? 0.0 : availableWidth / (notes.length - 1);

    final accidentalState = _initialAccidentalsFromKey(keySignature);

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final x = notes.length == 1 ? size.width / 2 : startX + (stepX * i);

      if (note.isRest) {
        _drawRest(
          canvas,
          note.duration,
          Offset(x, staffTop + (_lineGap * 2)),
        );
      } else {
        final sortedPitches = _sortedChordPitches(note.pitches);
        double? previousY;

        for (int j = 0; j < sortedPitches.length; j++) {
          final pitch = sortedPitches[j];
          final y = _pitchToY(pitch, clef, staffTop);

          double dx = 0;
          if (previousY != null && _areChordNotesClose(previousY, y)) {
            dx = (j.isEven) ? 8 : -8;
          }

          final center = Offset(x + dx, y);

          _drawNote(canvas, note, pitch, center, paintLine, accidentalState);
          _drawLedgerLinesIfNeeded(canvas, center, staffTop, paintLine);

          previousY = y;
        }
        if (!note.isRest && note.tieToNext && i < notes.length - 1) {
          final nextNote = notes[i + 1];

          if (!nextNote.isRest &&
              note.pitches.isNotEmpty &&
              nextNote.pitches.isNotEmpty &&
              _samePitchGroup(note.pitches, nextNote.pitches)) {
            final currentSorted = _sortedChordPitches(note.pitches);
            final nextSorted = _sortedChordPitches(nextNote.pitches);

            final currentY = _pitchToY(
              currentSorted.last,
              clef,
              staffTop,
            );

            final nextX = notes.length == 1
                ? size.width / 2
                : startX + (stepX * (i + 1));

            final nextY = _pitchToY(
              nextSorted.last,
              clef,
              staffTop,
            );

            _drawTie(
              canvas,
              Offset(x, currentY),
              Offset(nextX, nextY),
            );
          }
        }

        if (!note.isRest && note.slurToNext && i < notes.length - 1) {
          final nextNote = notes[i + 1];

          if (!nextNote.isRest &&
              note.pitches.isNotEmpty &&
              nextNote.pitches.isNotEmpty) {
            final currentSorted = _sortedChordPitches(note.pitches);
            final nextSorted = _sortedChordPitches(nextNote.pitches);

            final currentY = _pitchToY(
              currentSorted.first,
              clef,
              staffTop,
            );

            final nextX = notes.length == 1
                ? size.width / 2
                : startX + (stepX * (i + 1));

            final nextY = _pitchToY(
              nextSorted.first,
              clef,
              staffTop,
            );

            _drawSlur(
              canvas,
              Offset(x, currentY),
              Offset(nextX, nextY),
            );
          }
        }

      }
    }
    canvas.restore();
  }

  void _drawClef(Canvas canvas, Offset offset) {
    final symbol = clef == 'bass' ? '𝄢' : '𝄞';
    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: const TextStyle(
          fontSize: 34,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  void _drawNote(
      Canvas canvas,
      ScoreNote note,
      String pitch,
      Offset center,
      Paint linePaint,
      Map<String, String> accidentalState,
      ) {
    final parsedPitch = _parseStaffPitch(pitch);

    final headRect = Rect.fromCenter(
      center: center,
      width: _noteHeadW,
      height: _noteHeadH,
    );

    final symbol = _symbolToShowForPitch(parsedPitch, accidentalState);

    if (symbol.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(center.dx - 20, center.dy - 10),
      );
    }

    accidentalState[parsedPitch.letter] = parsedPitch.accidental;

    final headPaint = Paint()

      ..color = (note.duration == 'whole' || note.duration == 'half')
          ? Colors.white
          : Colors.black87
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(headRect, headPaint);
    canvas.drawOval(headRect, borderPaint);
    canvas.restore();

    // redonda no lleva plica
    if (note.duration == 'whole') return;

    final stemX = center.dx + 7;
    final stemTop = center.dy - 34;
    final stemBottom = center.dy;
    canvas.drawLine(
      Offset(stemX, stemBottom),
      Offset(stemX, stemTop),
      linePaint,
    );

    // corchea: una banderita simple
    if (note.duration == 'eighth') {
      final path = Path()
        ..moveTo(stemX, stemTop)
        ..quadraticBezierTo(
          stemX + 10,
          stemTop + 4,
          stemX + 6,
          stemTop + 14,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  void _drawRest(Canvas canvas, String duration, Offset center) {
    String symbol;
    switch (duration) {
      case 'whole':
        symbol = '𝄻';
        break;
      case 'half':
        symbol = '𝄼';
        break;
      case 'quarter':
        symbol = '𝄽';
        break;
      case 'eighth':
        symbol = '𝄾';
        break;
      default:
        symbol = '𝄽';
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _drawLedgerLinesIfNeeded(
      Canvas canvas,
      Offset center,
      double staffTop,
      Paint linePaint,
      ) {
    final topLineY = staffTop;
    final bottomLineY = staffTop + (_lineGap * 4);

    int drawn = 0;
    const int maxLedgerLines = 8;

    if (center.dy < topLineY - 1) {
      double y = topLineY - _lineGap;
      while (y >= center.dy - 1 && drawn < maxLedgerLines) {
        canvas.drawLine(
          Offset(center.dx - 12, y),
          Offset(center.dx + 12, y),
          linePaint,
        );
        y -= _lineGap;
        drawn++;
      }
    }

    if (center.dy > bottomLineY + 1) {
      double y = bottomLineY + _lineGap;
      while (y <= center.dy + 1 && drawn < maxLedgerLines) {
        canvas.drawLine(
          Offset(center.dx - 12, y),
          Offset(center.dx + 12, y),
          linePaint,
        );
        y += _lineGap;
        drawn++;
      }
    }
  }

  double _pitchToY(String pitch, String clef, double staffTop) {
    final parsed = _parseStaffPitch(pitch);

    // Referencia visual:
    // treble: E4 = línea inferior
    // bass: G2 = línea inferior
    final base = clef == 'bass'
        ? _parseStaffPitch('G2')
        : _parseStaffPitch('E4');

    final steps = _diatonicStepsBetween(base, parsed);

    return staffTop + (_lineGap * 4) - (steps * (_lineGap / 2));
  }

  _StaffPitch _parseStaffPitch(String pitch) {
    final m = RegExp(r'^([A-G])([#b]?)(-?\d+)$').firstMatch(pitch.trim());
    if (m == null) {
      return const _StaffPitch(letter: 'C', octave: 4, accidental: '');
    }

    return _StaffPitch(
      letter: m.group(1)!,
      accidental: m.group(2) ?? '',
      octave: int.tryParse(m.group(3)!) ?? 4,
    );
  }

  int _diatonicStepsBetween(_StaffPitch base, _StaffPitch target) {
    const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

    final baseIndex = letters.indexOf(base.letter);
    final targetIndex = letters.indexOf(target.letter);

    final octaveDiff = target.octave - base.octave;
    final letterDiff = targetIndex - baseIndex;

    return octaveDiff * 7 + letterDiff;
  }

  void _drawCenteredText(
      Canvas canvas,
      String text,
      Offset center, {
        double fontSize = 14,
      }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  List<String> _keySignatureSymbols(String key) {
    switch (key) {
      case 'G':
        return ['F#'];
      case 'D':
        return ['F#', 'C#'];
      case 'A':
        return ['F#', 'C#', 'G#'];
      case 'E':
        return ['F#', 'C#', 'G#', 'D#'];
      case 'B':
        return ['F#', 'C#', 'G#', 'D#', 'A#'];
      case 'F#':
        return ['F#', 'C#', 'G#', 'D#', 'A#', 'E#'];
      case 'C#':
        return ['F#', 'C#', 'G#', 'D#', 'A#', 'E#', 'B#'];
      case 'F':
        return ['Bb'];
      case 'Bb':
        return ['Bb', 'Eb'];
      case 'Eb':
        return ['Bb', 'Eb', 'Ab'];
      case 'Ab':
        return ['Bb', 'Eb', 'Ab', 'Db'];
      case 'Db':
        return ['Bb', 'Eb', 'Ab', 'Db', 'Gb'];
      case 'Gb':
        return ['Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb'];
      case 'Cb':
        return ['Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb', 'Fb'];
      case 'C':
      default:
        return [];
    }
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

  Map<String, String> _initialAccidentalsFromKey(String key) {
    final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
    final result = <String, String>{};

    for (final l in letters) {
      result[l] = _keySignatureAccidentalForLetter(l, key);
    }

    return result;
  }

  double _keyAccidentalY(String noteName, String clef, double staffTop) {
    final trebleMap = <String, String>{
      'F#': 'F5',
      'C#': 'C5',
      'G#': 'G5',
      'D#': 'D5',
      'A#': 'A4',
      'E#': 'E5',
      'B#': 'B4',
      'Bb': 'B4',
      'Eb': 'E5',
      'Ab': 'A4',
      'Db': 'D5',
      'Gb': 'G4',
      'Cb': 'C5',
      'Fb': 'F4',
    };

    final bassMap = <String, String>{
      'F#': 'A3',
      'C#': 'E3',
      'G#': 'B3',
      'D#': 'F3',
      'A#': 'C3',
      'E#': 'G3',
      'B#': 'D3',
      'Bb': 'D3',
      'Eb': 'G3',
      'Ab': 'C3',
      'Db': 'F3',
      'Gb': 'B2',
      'Cb': 'E3',
      'Fb': 'A2',
    };

    final map = clef == 'bass' ? bassMap : trebleMap;
    final refPitch = map[noteName] ?? 'C5';
    return _pitchToY(refPitch, clef, staffTop);
  }

  String _symbolToShowForPitch(
      _StaffPitch parsedPitch,
      Map<String, String> accidentalState,
      ) {
    final currentForLetter = accidentalState[parsedPitch.letter] ?? '';
    final actual = parsedPitch.accidental;

    if (actual == currentForLetter) {
      return '';
    }

    if (actual == '#') return '♯';
    if (actual == 'b') return '♭';

    // si el estado actual del compás/armadura tenía alteración
    // y ahora la nota viene natural, se necesita becuadro
    if (actual.isEmpty && currentForLetter.isNotEmpty) {
      return '♮';
    }

    return '';
  }

  double _drawKeySignature(Canvas canvas, double startX, double staffTop) {
    final symbols = _keySignatureSymbols(keySignature);
    if (symbols.isEmpty) return startX;

    double x = startX;

    for (final symbolPitch in symbols) {
      final accidental = symbolPitch.contains('#') ? '♯' : '♭';
      final y = _keyAccidentalY(symbolPitch, clef, staffTop);

      final textPainter = TextPainter(
        text: TextSpan(
          text: accidental,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(x, y - 10));

      x += 14;
    }

    return x + 10;
  }

  void _drawTie(Canvas canvas, Offset from, Offset to) {
    final path = Path()
      ..moveTo(from.dx + 10, from.dy + 12)
      ..quadraticBezierTo(
        (from.dx + to.dx) / 2,
        from.dy + 24,
        to.dx - 10,
        to.dy + 12,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawSlur(Canvas canvas, Offset from, Offset to) {
    final path = Path()
      ..moveTo(from.dx + 8, from.dy - 14)
      ..quadraticBezierTo(
        (from.dx + to.dx) / 2,
        ((from.dy + to.dy) / 2) - 26,
        to.dx - 8,
        to.dy - 14,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  bool _samePitchGroup(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    final sa = _sortedChordPitches(a);
    final sb = _sortedChordPitches(b);

    for (int i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }

    return true;
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter oldDelegate) {
    return oldDelegate.measure != measure || oldDelegate.clef != clef;
  }

  List<String> _sortedChordPitches(List<String> pitches) {
    final copy = List<String>.from(pitches);
    copy.sort((a, b) {
      final pa = _parseStaffPitch(a);
      final pb = _parseStaffPitch(b);

      const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
      final ai = (pa.octave * 7) + letters.indexOf(pa.letter);
      final bi = (pb.octave * 7) + letters.indexOf(pb.letter);

      return ai.compareTo(bi);
    });
    return copy;
  }

  bool _areChordNotesClose(double y1, double y2) {
    return (y1 - y2).abs() < (_lineGap * 0.75);
  }

}

class _StaffPitch {
  final String letter;
  final String accidental;
  final int octave;

  const _StaffPitch({
    required this.letter,
    required this.accidental,
    required this.octave,
  });
}

