import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_you/config_provider.dart';
import 'package:daily_you/utils/file_layer.dart';
import 'package:daily_you/providers/entry_audio_provider.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AudioStorage {
  static final AudioStorage instance = AudioStorage._init();

  AudioStorage._init();

  bool usingExternalLocation() {
    return ConfigProvider.instance.get(ConfigKey.useExternalDb) ?? false;
  }

  Future<String> getInternalFolder() async {
    Directory basePath;
    if (Platform.isAndroid) {
      basePath = (await getExternalStorageDirectory())!;
      basePath = Directory('${basePath.path}/Audio');
      if (!basePath.existsSync()) {
        basePath.createSync(recursive: true);
      }
      return basePath.path;
    } else {
      basePath = await getApplicationSupportDirectory();
      basePath = Directory('${basePath.path}/Audio');
      if (!basePath.existsSync()) {
        basePath.createSync(recursive: true);
      }
      return basePath.path;
    }
  }

  Future<String> getFilePath(String audioName) async {
    final internalDir = await getInternalFolder();
    return join(internalDir, audioName);
  }

  Future<Uint8List?> getBytes(String audioName) async {
    var internalDir = await getInternalFolder();
    var bytes = await FileLayer.getFileBytes(internalDir,
        name: audioName, useExternalPath: false);
    return bytes;
  }

  Future<String?> create(String? audioName, Uint8List bytes,
      {DateTime? currTime}) async {
    currTime ??= DateTime.now();

    final internalFolder = await getInternalFolder();

    // Don't make a copy of files already in the folder
    if (audioName != null &&
        await FileLayer.exists(internalFolder,
            name: audioName, useExternalPath: false)) {
      return audioName;
    }

    var extension2 = audioName != null ? extension(audioName) : ".mp3";

    final timestamp =
        currTime.toIso8601String().split('.').first.replaceAll(':', '-');

    var newAudioName = "daily_you_$timestamp$extension2";

    // Ensure unique name
    int index = 1;
    while (await FileLayer.exists(internalFolder,
        name: newAudioName, useExternalPath: false)) {
      newAudioName = "daily_you_${timestamp}_$index$extension2";
      index += 1;
    }

    var audioFilePath = await FileLayer.createFile(
        internalFolder, newAudioName, bytes,
        useExternalPath: false);
    if (audioFilePath == null) return null;
    return newAudioName;
  }

  /// Copy an audio file from an external source path into the audio storage.
  /// Uses [File.copy] for streaming I/O — avoids loading the entire file into
  /// memory, so large audio files won't cause OOM.
  Future<String?> copyFrom(String sourcePath, String? sourceName) async {
    try {
      final internalFolder = await getInternalFolder();
      final ext = sourceName != null ? extension(sourceName) : extension(sourcePath);
      final timestamp =
          DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      var newName = 'daily_you_$timestamp$ext';

      int index = 1;
      while (await FileLayer.exists(internalFolder,
          name: newName, useExternalPath: false)) {
        newName = 'daily_you_${timestamp}_$index$ext';
        index += 1;
      }

      final destPath = join(internalFolder, newName);
      await File(sourcePath).copy(destPath);
      return newName;
    } catch (e) {
      print('AudioStorage.copyFrom error: $e');
      return null;
    }
  }

  Future<String?> rename(String oldName, String newBaseName) async {
    try {
      final internalFolder = await getInternalFolder();
      final oldPath = join(internalFolder, oldName);
      final oldExt = extension(oldName);
      // Sanitize: keep only valid filename chars, strip path separators
      final safeName = newBaseName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
      if (safeName.isEmpty) return oldName;
      var newName = '$safeName$oldExt';

      // Ensure unique name
      int index = 1;
      while (await FileLayer.exists(internalFolder,
          name: newName, useExternalPath: false)) {
        newName = '${safeName}_$index$oldExt';
        index += 1;
      }

      final newPath = join(internalFolder, newName);
      final oldFile = File(oldPath);
      if (!oldFile.existsSync()) return null;
      await oldFile.rename(newPath);
      return newName;
    } catch (e) {
      print('AudioStorage.rename error: $e');
      return null;
    }
  }

  Future<bool> delete(String audioName) async {
    try {
      final internalFolder = await getInternalFolder();
      // Only delete if the file actually exists (may have been renamed)
      if (await FileLayer.exists(internalFolder,
          name: audioName, useExternalPath: false)) {
        await FileLayer.deleteFile(internalFolder,
            name: audioName, useExternalPath: false);
      }
      return true;
    } catch (e) {
      print('AudioStorage.delete error: $e');
      return true; // Don't fail if cleanup fails
    }
  }

  Future<bool> garbageCollectAudios() async {
    var entryAudios = EntryAudioProvider.instance.audios;
    var entryAudioNames =
        entryAudios.map((entryAudio) => entryAudio.audioPath).toList();
    var internalAudios = Directory(await getInternalFolder()).list();
    await for (FileSystemEntity fileEntity in internalAudios) {
      if (fileEntity is File) {
        if (!entryAudioNames.contains(basename(fileEntity.path))) {
          await File(fileEntity.path).delete();
        }
      }
    }
    return true;
  }
}
