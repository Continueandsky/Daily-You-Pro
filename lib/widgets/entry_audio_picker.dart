import 'dart:async';
import 'dart:io';

import 'package:daily_you/database/audio_storage.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/models/audio.dart';
import 'package:daily_you/providers/entry_audio_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' hide context;
import 'package:record/record.dart';

class EntryAudioPicker extends StatefulWidget {
  final List<EntryAudio> currentAudios;
  final ValueChanged<List<EntryAudio>> onChangedAudios;

  const EntryAudioPicker({
    super.key,
    required this.currentAudios,
    required this.onChangedAudios,
  });

  @override
  State<EntryAudioPicker> createState() => _EntryAudioPickerState();
}

class _EntryAudioPickerState extends State<EntryAudioPicker> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription? _recordSub;

  @override
  void dispose() {
    _recordSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    // Stream-copy to avoid loading large files entirely into memory
    final audioName =
        await AudioStorage.instance.copyFrom(file.path!, file.name);
    if (audioName == null) return;

    if (Platform.isAndroid) {
      try { await File(file.path!).delete(); } catch (_) {}
    }

    _addAudio(audioName);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path == null) return;

      // Stream-copy the recorded file into audio storage
      final ext = extension(path);
      final audioName = await AudioStorage.instance.copyFrom(path, 'recording$ext');
      if (audioName != null) {
        _addAudio(audioName);
      }
      // Clean up temp recording
      try { await File(path).delete(); } catch (_) {}
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;

      const config = RecordConfig(encoder: AudioEncoder.aacLc);
      await _recorder.start(config, path: '${Directory.systemTemp.path}/dy_rec_${DateTime.now().millisecondsSinceEpoch}.m4a');

      setState(() => _isRecording = true);
      _recordSub = _recorder.onStateChanged().listen((state) {
        if (state == RecordState.stop && mounted) {
          setState(() => _isRecording = false);
        }
      });
    }
  }

  void _addAudio(String audioName) {
    final newAudio = EntryAudio(
      entryId: widget.currentAudios.isNotEmpty
          ? widget.currentAudios.first.entryId
          : null,
      audioPath: audioName,
      timeCreate: DateTime.now(),
    );
    widget.onChangedAudios([...widget.currentAudios, newAudio]);
  }

  Future<void> _removeAudio(EntryAudio audio) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteAudioTitle),
        content: Text(loc.deleteAudioDescription,
            style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.deleteAudioTitle),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final updated = widget.currentAudios.where((a) => a != audio).toList();
    widget.onChangedAudios(updated);
  }

  Future<void> _showRenameDialog(EntryAudio audio) async {
    final loc = AppLocalizations.of(context)!;
    final oldName = basenameWithoutExtension(audio.audioPath);
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

    try {
      final renamed =
          await AudioStorage.instance.rename(audio.audioPath, newName);
      if (renamed != null) {
        // If the audio is already in DB, update its record directly to avoid
        // the _saveEntry race condition (where _savingEntry=true drops the save).
        if (audio.id != null) {
          await EntryAudioProvider.instance.update(audio.copy(audioPath: renamed));
        }

        final updated = widget.currentAudios.map((a) {
          return identical(a, audio) ? a.copy(audioPath: renamed) : a;
        }).toList();
        widget.onChangedAudios(updated);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.renameAudioHint)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.renameAudioHint}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Action buttons row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pick file button
            IconButton(
              onPressed: _pickAudio,
              icon: Icon(Icons.audio_file_rounded,
                  color: theme.colorScheme.primary, size: 24),
              style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer),
              tooltip: loc.pickAudio,
            ),
            const SizedBox(width: 4),
            // Record button
            IconButton(
              onPressed: _toggleRecording,
              icon: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: _isRecording ? Colors.red : theme.colorScheme.primary,
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: _isRecording
                    ? Colors.red.withValues(alpha: 0.15)
                    : theme.colorScheme.primaryContainer,
              ),
              tooltip: _isRecording ? loc.stopRecording : loc.recordAudio,
            ),
          ],
        ),
        // Audio chips — Wrap gets proper width constraint
        if (widget.currentAudios.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.currentAudios.map((audio) {
                final fileName = basenameWithoutExtension(audio.audioPath);
                return InputChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(fileName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (audio.durationText.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(audio.durationText,
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  onPressed: () => _showRenameDialog(audio),
                  onDeleted: () => _removeAudio(audio),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
