import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/database/entry_audio_dao.dart';
import 'package:daily_you/models/entry.dart';
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

  Future<void> add(EntryAudio audio, {skipUpdate = false}) async {
    final audioWithId = await EntryAudioDao.add(audio);
    audios.add(audioWithId);
    await AppDatabase.instance.updateExternalDatabase();
    if (!skipUpdate) {
      notifyListeners();
    }
  }

  Future<void> remove(EntryAudio audio) async {
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

  /// Get the audio for a given entry, returns null if no audio is associated.
  EntryAudio? getForEntry(Entry entry) {
    return audios.where((audio) => audio.entryId == entry.id!).firstOrNull;
  }
}
