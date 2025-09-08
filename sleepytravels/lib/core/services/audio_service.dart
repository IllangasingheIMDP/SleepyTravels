import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'audio_file_service.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    // Initialize any audio settings if needed
    // Listen to player state changes to keep _isPlaying accurate
    _player.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      _isPlayingNotifier.value = _isPlaying;

      if (wasPlaying != _isPlaying) {
        print('AudioService: Player state changed - playing: $_isPlaying');
      }
    });
  }

  bool get isPlaying => _isPlaying;
  ValueNotifier<bool> get isPlayingNotifier => _isPlayingNotifier;

  Future<void> playFromPath(String path) async {
    try {
      // If already playing, don't start another
      if (_isPlaying) {
        return;
      }

      // Check if file exists using our audio file service
      final exists = await AudioFileService.instance.audioFileExists(path);
      if (!exists) {
        return;
      }

      // Stop any current playback
      await _player.stop();

      // Set the file path
      await _player.setFilePath(path);

      // Set loop mode to repeat (like an alarm)
      await _player.setLoopMode(LoopMode.one);

      // Set volume to maximum
      await _player.setVolume(1.0);

      // Play the audio
      await _player.play();
      _isPlaying = true;
      _isPlayingNotifier.value = true;
    } catch (e) {
      print('AudioService: Error playing audio: $e');
      print('AudioService: Error type: ${e.runtimeType}');
      _isPlaying = false;
      _isPlayingNotifier.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _isPlayingNotifier.value = false;
    } catch (e) {
      print('AudioService: Error stopping audio: $e');
      _isPlaying = false;
      _isPlayingNotifier.value = false;
    }
  }
}
