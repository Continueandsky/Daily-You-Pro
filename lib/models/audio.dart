const String audiosTable = 'entry_audios';

class EntryAudioFields {
  static const List<String> values = [
    id,
    entryId,
    audioPath,
    timeCreate
  ];
  static const String id = 'id';
  static const String entryId = 'entry_id';
  static const String audioPath = 'audio_path';
  static const String timeCreate = 'time_create';
}

class EntryAudio {
  final int? id;
  int? entryId;
  final String audioPath;
  final DateTime timeCreate;

  EntryAudio({
    this.id,
    required this.entryId,
    required this.audioPath,
    required this.timeCreate,
  });

  EntryAudio copy({
    int? id,
    int? entryId,
    String? audioPath,
    DateTime? timeCreate,
  }) =>
      EntryAudio(
        id: id ?? this.id,
        entryId: entryId ?? this.entryId,
        audioPath: audioPath ?? this.audioPath,
        timeCreate: timeCreate ?? this.timeCreate,
      );

  static EntryAudio fromJson(Map<String, Object?> json) => EntryAudio(
        id: json[EntryAudioFields.id] as int?,
        entryId: json[EntryAudioFields.entryId] as int?,
        audioPath: json[EntryAudioFields.audioPath] as String,
        timeCreate: DateTime.parse(json[EntryAudioFields.timeCreate] as String),
      );

  Map<String, Object?> toJson() => {
        EntryAudioFields.id: id,
        EntryAudioFields.entryId: entryId,
        EntryAudioFields.audioPath: audioPath,
        EntryAudioFields.timeCreate: timeCreate.toIso8601String(),
      };
}
