import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/database/audio_storage.dart';
import 'package:daily_you/database/entry_audio_dao.dart';
import 'package:daily_you/models/audio.dart';
import 'package:flutter/material.dart';

class EntryAudioProvider with ChangeNotifier {
  static final EntryAudioProvider instance = EntryAudioProvider._init();

  EntryAudioProvider._init();

  List<EntryAudio> audios = List.empty();

  /// Load the provider's data from the app database
  Future<void> load() async {
    audios = await EntryAudioDao.getAll();
    notifyListeners();
  }

  // CRUD operations

  Future<EntryAudio> add(EntryAudio audio, {bool skipUpdate = false}) async {
    final audioWithId = await EntryAudioDao.add(audio);
    audios.add(audioWithId);
    await AppDatabase.instance.updateExternalDatabase();
    if (!skipUpdate) {
      notifyListeners();
    }
    return audioWithId;
  }

  Future<void> remove(EntryAudio audio) async {
    await AudioStorage.instance.delete(audio.audioPath);
    await EntryAudioDao.remove(audio);
    audios.removeWhere((x) => x.id == audio.id);
    await AppDatabase.instance.updateExternalDatabase();
    notifyListeners();
  }

  Future<void> update(EntryAudio audio) async {
    await EntryAudioDao.update(audio);
    final index = audios.indexWhere((x) => x.id == audio.id);
    audios[index] = audio;
    await AppDatabase.instance.updateExternalDatabase();
    notifyListeners();
  }

  /// Get all audios for a given entry.
  List<EntryAudio> getForEntry(int entryId) {
    return audios.where((audio) => audio.entryId == entryId).toList();
  }

  /// Remove all audios for a given entry (e.g. when deleting an entry).
  Future<void> removeAllForEntry(int entryId) async {
    final toRemove = getForEntry(entryId);
    for (final audio in toRemove) {
      await AudioStorage.instance.delete(audio.audioPath);
      await EntryAudioDao.remove(audio);
      audios.removeWhere((x) => x.id == audio.id);
    }
    if (toRemove.isNotEmpty) {
      await AppDatabase.instance.updateExternalDatabase();
      notifyListeners();
    }
  }
}
