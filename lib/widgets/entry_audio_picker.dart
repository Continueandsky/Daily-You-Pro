import 'dart:io';

import 'package:daily_you/database/audio_storage.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/models/audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' hide context;

class EntryAudioPicker extends StatefulWidget {
  final EntryAudio? currentAudio;
  final ValueChanged<EntryAudio?> onChangedAudio;

  const EntryAudioPicker({
    super.key,
    this.currentAudio,
    required this.onChangedAudio,
  });

  @override
  State<EntryAudioPicker> createState() => _EntryAudioPickerState();
}

class _EntryAudioPickerState extends State<EntryAudioPicker> {
  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final bytes = await File(file.path!).readAsBytes();
    final audioName = await AudioStorage.instance.create(
      file.name,
      bytes,
    );

    if (audioName == null) return;

    // Delete picked file from cache
    if (Platform.isAndroid) {
      await File(file.path!).delete();
    }

    widget.onChangedAudio(EntryAudio(
      entryId: widget.currentAudio?.entryId,
      audioPath: audioName,
      timeCreate: DateTime.now(),
    ));
  }

  void _removeAudio() {
    widget.onChangedAudio(null);
  }

  Future<void> _showRenameDialog() async {
    final loc = AppLocalizations.of(context)!;
    final oldName = basenameWithoutExtension(widget.currentAudio!.audioPath);
    final controller = TextEditingController(text: oldName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.renameAudioTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: loc.renameAudioHint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return loc.renameAudioHint;
              }
              return null;
            },
            onFieldSubmitted: (value) {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(value.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Text(loc.renameAudioConfirm),
          ),
        ],
      ),
    );

    if (newName == null || newName == oldName) return;

    final renamed = await AudioStorage.instance.rename(
      widget.currentAudio!.audioPath,
      newName,
    );

    if (renamed != null) {
      widget.onChangedAudio(widget.currentAudio!.copy(
        audioPath: renamed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = widget.currentAudio != null;
    final fileName = hasAudio
        ? basenameWithoutExtension(widget.currentAudio!.audioPath)
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _pickAudio,
          icon: Icon(
            hasAudio ? Icons.music_note_rounded : Icons.music_note_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer),
          tooltip: AppLocalizations.of(context)!.pickAudio,
        ),
        if (hasAudio && fileName != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: InputChip(
              label: Text(
                fileName,
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: _showRenameDialog,
              onDeleted: _removeAudio,
              deleteIcon: const Icon(Icons.close, size: 18),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
          ),
      ],
    );
  }
}
