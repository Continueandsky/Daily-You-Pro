import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:daily_you/config_provider.dart';
import 'package:daily_you/database/audio_storage.dart';
import 'package:daily_you/models/audio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';

class EntryAudioPlaylist extends StatefulWidget {
  final List<EntryAudio> audios;
  final bool autoPlay;

  const EntryAudioPlaylist({
    super.key,
    required this.audios,
    this.autoPlay = true,
  });

  @override
  State<EntryAudioPlaylist> createState() => _EntryAudioPlaylistState();
}

class _EntryAudioPlaylistState extends State<EntryAudioPlaylist>
    with WidgetsBindingObserver {
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  AudioPlayer _audioPlayer = AudioPlayer();
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCompleted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _pollTimer;
  double _playbackRate = 1.0;

  EntryAudio get _currentAudio => widget.audios[_currentIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrent();
  }

  @override
  void didUpdateWidget(EntryAudioPlaylist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audios != widget.audios) {
      _currentIndex = 0;
      _loadCurrent();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (!mounted || !_isPlaying) return;
      try {
        final pos = await _audioPlayer.getCurrentPosition();
        final dur = await _audioPlayer.getDuration();
        if (pos != null && dur != null && dur.inMilliseconds > 0) {
          if (!mounted) return;
          setState(() {
            _position = pos;
            _duration = dur;
          });
          // Track completed — position at or past end
          if (pos.inMilliseconds >= dur.inMilliseconds - 500) {
            _pollTimer?.cancel();
            await _onTrackCompleted();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _onTrackCompleted() async {
    final loopAudio =
        context.read<ConfigProvider>().get(ConfigKey.loopAudio) ?? false;
    final hasNext = _currentIndex + 1 < widget.audios.length;

    if (hasNext) {
      _currentIndex++;
      await _loadCurrent();
    } else if (loopAudio) {
      _currentIndex = 0;
      await _loadCurrent();
    } else {
      // All tracks finished, stop
      setState(() {
        _isCompleted = true;
        _isPlaying = false;
        _position = _duration;
      });
    }
  }

  Future<void> _loadCurrent() async {
    try {
      _pollTimer?.cancel();
      setState(() {
        _isLoading = true;
        _hasError = false;
        _isCompleted = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      final filePath =
          await AudioStorage.instance.getFilePath(_currentAudio.audioPath);

      // Verify file exists before attempting to play
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('Audio file not found: $_currentAudio.audioPath');
      }

      await _audioPlayer.setSourceDeviceFile(filePath);
      await _audioPlayer.setPlaybackRate(_playbackRate);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (widget.autoPlay || _isPlaying) {
        await _audioPlayer.resume();
        setState(() => _isPlaying = true);
        _startPolling();
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
      _pollTimer?.cancel();
      _audioPlayer.pause();
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        _pollTimer?.cancel();
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else if (_isCompleted) {
        final loopAudio =
            context.read<ConfigProvider>().get(ConfigKey.loopAudio) ?? false;
        _currentIndex = (loopAudio && widget.audios.length > 1) ? 0 : _currentIndex;
        await _loadCurrent();
      } else {
        await _audioPlayer.resume();
        setState(() => _isPlaying = true);
        _startPolling();
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex + 1 < widget.audios.length) {
      _currentIndex++;
      await _loadCurrent();
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _loadCurrent();
    }
  }

  Future<void> _cycleSpeed() async {
    final currentIdx = _speeds.indexOf(_playbackRate);
    final nextIdx = (currentIdx + 1) % _speeds.length;
    final newRate = _speeds[nextIdx];
    await _audioPlayer.setPlaybackRate(newRate);
    setState(() => _playbackRate = newRate);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = basenameWithoutExtension(_currentAudio.audioPath);
    final count = widget.audios.length;

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
                Icon(Icons.music_note_rounded,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis),
                      if (count > 1)
                        Text('${_currentIndex + 1} / $count',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else if (_hasError)
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 24)
                else ...[
                  // Speed control — tap to cycle 0.5× → 0.75× → 1× → 1.25× → 1.5× → 2×
                  GestureDetector(
                    onTap: _cycleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _playbackRate == 1.0
                            ? '1×'
                            : '${_playbackRate.toStringAsFixed(_playbackRate == 0.5 || _playbackRate == 1.5 ? 1 : 2)}×',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (count > 1)
                    IconButton(
                      onPressed: _currentIndex > 0 ? _playPrevious : null,
                      icon: Icon(Icons.skip_previous_rounded,
                          color: _currentIndex > 0
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                          size: 28),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: theme.colorScheme.primary,
                        size: 36),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (count > 1)
                    IconButton(
                      onPressed:
                          _currentIndex + 1 < count ? _playNext : null,
                      icon: Icon(Icons.skip_next_rounded,
                          color: _currentIndex + 1 < count
                              ? theme.colorScheme.primary
                              : theme.disabledColor,
                          size: 28),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ],
            ),
            if (!_isLoading && !_hasError && _duration.inMilliseconds > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(_formatDuration(_position),
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
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
                            setState(() {
                              _position =
                                  Duration(milliseconds: value.toInt());
                            });
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  Text(_formatDuration(_duration),
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
