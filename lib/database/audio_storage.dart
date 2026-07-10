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

  Future<String?> rename(String oldName, String newBaseName) async {
    final internalFolder = await getInternalFolder();
    final oldPath = join(internalFolder, oldName);
    final oldExt = extension(oldName);
    var newName = '$newBaseName$oldExt';

    // Ensure unique name
    int index = 1;
    while (await FileLayer.exists(internalFolder,
        name: newName, useExternalPath: false)) {
      newName = '${newBaseName}_$index$oldExt';
      index += 1;
    }

    final newPath = join(internalFolder, newName);
    await File(oldPath).rename(newPath);
    return newName;
  }

  Future<bool> delete(String audioName) async {
    final internalFolder = await getInternalFolder();
    await FileLayer.deleteFile(internalFolder,
        name: audioName, useExternalPath: false);
    return true;
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
