import 'dart:convert';

class ScoreNote {
  final List<String> pitches; // Ej: C4, E4, G4. Vacío si es silencio
  final String duration; // whole, half, quarter, eighth
  final bool isRest;
  final bool tieToNext;
  final bool slurToNext;

  const ScoreNote({
    required this.pitches,
    required this.duration,
    this.isRest = false,
    this.tieToNext = false,
    this.slurToNext = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'pitches': pitches,
      'duration': duration,
      'isRest': isRest,
      'tieToNext': tieToNext,
      'slurToNext': slurToNext,
    };
  }

  factory ScoreNote.fromMap(Map<String, dynamic> map) {
    final rawPitches = (map['pitches'] as List?) ?? const [];
    return ScoreNote(
      pitches: rawPitches.map((e) => e.toString()).toList(),
      duration: (map['duration'] ?? 'quarter').toString(),
      isRest: (map['isRest'] ?? false) == true,
      tieToNext: (map['tieToNext'] ?? false) == true,
      slurToNext: (map['slurToNext'] ?? false) == true,
    );
  }

  ScoreNote copyWith({
    List<String>? pitches,
    String? duration,
    bool? isRest,
    bool? tieToNext,
    bool? slurToNext,
  }) {
    return ScoreNote(
      pitches: pitches ?? this.pitches,
      duration: duration ?? this.duration,
      isRest: isRest ?? this.isRest,
      tieToNext: tieToNext ?? this.tieToNext,
      slurToNext: slurToNext ?? this.slurToNext,
    );
  }
}

class ScoreMeasure {
  final List<ScoreNote> notes;

  const ScoreMeasure({
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'notes': notes.map((n) => n.toMap()).toList(),
    };
  }

  factory ScoreMeasure.fromMap(Map<String, dynamic> map) {
    final rawNotes = (map['notes'] as List?) ?? const [];
    return ScoreMeasure(
      notes: rawNotes
          .map((e) => ScoreNote.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  ScoreMeasure copyWith({
    List<ScoreNote>? notes,
  }) {
    return ScoreMeasure(
      notes: notes ?? this.notes,
    );
  }
}

class ScoreDocument {
  final String clef; // treble, bass
  final String keySignature; // C, G, D, F, Bb...
  final String timeSignature; // 4/4, 3/4, 6/8...
  final List<ScoreMeasure> measures;

  const ScoreDocument({
    required this.clef,
    required this.keySignature,
    required this.timeSignature,
    required this.measures,
  });

  Map<String, dynamic> toMap() {
    return {
      'clef': clef,
      'keySignature': keySignature,
      'timeSignature': timeSignature,
      'measures': measures.map((m) => m.toMap()).toList(),
    };
  }

  factory ScoreDocument.fromMap(Map<String, dynamic> map) {
    final rawMeasures = (map['measures'] as List?) ?? const [];
    return ScoreDocument(
      clef: (map['clef'] ?? 'treble').toString(),
      keySignature: (map['keySignature'] ?? 'C').toString(),
      timeSignature: (map['timeSignature'] ?? '4/4').toString(),
      measures: rawMeasures
          .map((e) => ScoreMeasure.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ScoreDocument.fromJson(String source) {
    return ScoreDocument.fromMap(
      Map<String, dynamic>.from(jsonDecode(source) as Map),
    );
  }

  ScoreDocument copyWith({
    String? clef,
    String? keySignature,
    String? timeSignature,
    List<ScoreMeasure>? measures,
  }) {
    return ScoreDocument(
      clef: clef ?? this.clef,
      keySignature: keySignature ?? this.keySignature,
      timeSignature: timeSignature ?? this.timeSignature,
      measures: measures ?? this.measures,
    );
  }

  factory ScoreDocument.empty() {
    return const ScoreDocument(
      clef: 'treble',
      keySignature: 'C',
      timeSignature: '4/4',
      measures: [
        ScoreMeasure(notes: []),
      ],
    );
  }
}