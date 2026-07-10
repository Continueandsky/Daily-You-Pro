import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:daily_you/database/audio_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class EntryAudioPlayer extends StatefulWidget {
  final String audioPath;
  final bool autoPlay;

  const EntryAudioPlayer({
    super.key,
    required this.audioPath,
    this.autoPlay = true,
  });

  @override
  State<EntryAudioPlayer> createState() => _EntryAudioPlayerState();
}

class _EntryAudioPlayerState extends State<EntryAudioPlayer>
    with WidgetsBindingObserver {
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCompleted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _filePath;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudio();
  }

  Future<void> _setupPlayer() async {
    // Cancel old subscriptions
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _isCompleted = true;
          _position = _duration;
        }
        if (state == PlayerState.playing) {
          _isCompleted = false;
        }
      });
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });

    await _audioPlayer.setSourceDeviceFile(_filePath!);
  }

  Future<void> _initAudio() async {
    try {
      _filePath = await AudioStorage.instance.getFilePath(widget.audioPath);
      await _setupPlayer();

      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.autoPlay) {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else if (_isCompleted) {
        // On Windows audioplayers has thread issues after completion,
        // so we fully re-initialize the player instance.
        await _audioPlayer.dispose();
        _audioPlayer = AudioPlayer();
        await _setupPlayer();
        setState(() {
          _isCompleted = false;
          _position = Duration.zero;
        });
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = basenameWithoutExtension(widget.audioPath);

    return Card.filled(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.music_note_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_hasError)
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 24)
                else
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: theme.colorScheme.primary,
                      size: 36,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (!_isLoading && !_hasError && _duration.inMilliseconds > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds
                            .toDouble()
                            .clamp(0, _duration.inMilliseconds.toDouble()),
                        max: _duration.inMilliseconds.toDouble(),
                        onChanged: (value) async {
                          try {
                            await _audioPlayer
                                .seek(Duration(milliseconds: value.toInt()));
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
