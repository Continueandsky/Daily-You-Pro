import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/models/audio.dart';

class EntryAudioDao {
  static Future<List<EntryAudio>> getAll() async {
    final result = await AppDatabase.instance.database!
        .query(audiosTable, orderBy: '${EntryAudioFields.timeCreate} DESC');

    return result.map((json) => EntryAudio.fromJson(json)).toList();
  }

  static Future<List<EntryAudio>> getForEntry(int entryId) async {
    final maps = await AppDatabase.instance.database!.query(audiosTable,
        where: '${EntryAudioFields.entryId} = ?',
        whereArgs: [entryId],
        orderBy: '${EntryAudioFields.timeCreate} DESC');

    return maps.map((json) => EntryAudio.fromJson(json)).toList();
  }

  static Future<EntryAudio> add(EntryAudio entryAudio) async {
    final id = await AppDatabase.instance.database!
        .insert(audiosTable, entryAudio.toJson());

    return entryAudio.copy(id: id);
  }

  static Future<void> remove(EntryAudio entryAudio) async {
    await AppDatabase.instance.database!.delete(
      audiosTable,
      where: '${EntryAudioFields.id} = ?',
      whereArgs: [entryAudio.id],
    );
  }

  static Future<void> update(EntryAudio audio) async {
    await AppDatabase.instance.database!.update(
      audiosTable,
      audio.toJson(),
      where: '${EntryAudioFields.id} = ?',
      whereArgs: [audio.id],
    );
  }
}
