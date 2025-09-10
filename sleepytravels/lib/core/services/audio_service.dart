import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_manager/flutter_ringtone_manager.dart';
import 'package:audio_session/audio_session.dart';
import 'audio_file_service.dart';
import 'dart:developer' as developer;

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  final FlutterRingtoneManager _ringtone = FlutterRingtoneManager();
  bool _isPlaying = false;
  bool _isRingtonePlaying = false;
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    // Initialize any audio settings if needed
    // Listen to player state changes to keep _isPlaying accurate
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.alarm,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
        ),
      );
    } catch (e) {
      developer.log('AudioService: Error configuring AudioSession: $e');
    }

    _player.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      _syncNotifier();

      if (wasPlaying != _isPlaying) {
        developer.log(
          'AudioService: Player state changed - playing: $_isPlaying',
        );
      }
    });
  }

  bool get isPlaying => _isPlaying;
  ValueNotifier<bool> get isPlayingNotifier => _isPlayingNotifier;

  void _syncNotifier() {
    _isPlayingNotifier.value = _isPlaying || _isRingtonePlaying;
  }

  /// Play a bundled asset as a ringtone/alert using flutter_ringtone_manager.
  /// Pass the relative path inside your Flutter assets (e.g. "audio/test.mp3").
  Future<void> playAssetAsRingtone(String assetPath) async {
    try {
      if (_isRingtonePlaying || _isPlaying) return;
      await _player.stop();
      await _ringtone.playAudioAsset(assetPath);
      _isRingtonePlaying = true;
      _syncNotifier();
    } catch (e) {
      developer.log(
        'AudioService: Error playing asset via RingtoneManager: $e',
      );
      _isRingtonePlaying = false;
      _syncNotifier();
    }
  }

  /// Play the system default alarm sound (loops by the OS) using flutter_ringtone_manager.
  Future<void> playSystemAlarm() async {
    try {
      if (_isRingtonePlaying || _isPlaying) return;
      await _player.stop();
      await _ringtone.playAlarm();
      _isRingtonePlaying = true;
      _syncNotifier();
    } catch (e) {
      developer.log('AudioService: Error playing system alarm: $e');
      _isRingtonePlaying = false;
      _syncNotifier();
    }
  }

  Future<void> playFromPath(String path) async {
    try {
      // If already playing, don't start another
      if (_isPlaying || _isRingtonePlaying) {
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
      _syncNotifier();
    } catch (e) {
      developer.log('AudioService: Error playing audio: $e');
      developer.log('AudioService: Error type: ${e.runtimeType}');
      _isPlaying = false;
      _syncNotifier();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      try {
        await _ringtone.stop();
      } catch (e) {
        // ignore stop errors from ringtone manager
      }
      _isRingtonePlaying = false;
      _syncNotifier();
    } catch (e) {
      developer.log('AudioService: Error stopping audio: $e');
      _isPlaying = false;
      _isRingtonePlaying = false;
      _syncNotifier();
    }
  }
}
