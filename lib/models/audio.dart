const String audiosTable = 'entry_audios';

class EntryAudioFields {
  static const List<String> values = [
    id,
    entryId,
    audioPath,
    timeCreate,
    duration,
  ];
  static const String id = 'id';
  static const String entryId = 'entry_id';
  static const String audioPath = 'audio_path';
  static const String timeCreate = 'time_create';
  static const String duration = 'duration';
}

class EntryAudio {
  final int? id;
  int? entryId;
  final String audioPath;
  final DateTime timeCreate;
  final int? durationMs;

  EntryAudio({
    this.id,
    required this.entryId,
    required this.audioPath,
    required this.timeCreate,
    this.durationMs,
  });

  String get durationText {
    if (durationMs == null || durationMs! <= 0) return '';
    final totalSeconds = durationMs! ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  EntryAudio copy({
    int? id,
    int? entryId,
    String? audioPath,
    DateTime? timeCreate,
    int? durationMs,
  }) =>
      EntryAudio(
        id: id ?? this.id,
        entryId: entryId ?? this.entryId,
        audioPath: audioPath ?? this.audioPath,
        timeCreate: timeCreate ?? this.timeCreate,
        durationMs: durationMs ?? this.durationMs,
      );

  static EntryAudio fromJson(Map<String, Object?> json) => EntryAudio(
        id: json[EntryAudioFields.id] as int?,
        entryId: json[EntryAudioFields.entryId] as int?,
        audioPath: json[EntryAudioFields.audioPath] as String,
        timeCreate: DateTime.parse(json[EntryAudioFields.timeCreate] as String),
        durationMs: json[EntryAudioFields.duration] as int?,
      );

  Map<String, Object?> toJson() => {
        EntryAudioFields.id: id,
        EntryAudioFields.entryId: entryId,
        EntryAudioFields.audioPath: audioPath,
        EntryAudioFields.timeCreate: timeCreate.toIso8601String(),
        EntryAudioFields.duration: durationMs,
      };
}
