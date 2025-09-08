import 'package:just_audio/just_audio.dart';


class AudioService {
AudioService._();
static final AudioService instance = AudioService._();


final AudioPlayer _player = AudioPlayer();


Future<void> init() async {
// nothing to init now
}


Future<void> playFromPath(String path) async {
try {
await _player.setFilePath(path);
await _player.setLoopMode(LoopMode.off);
await _player.play();
} catch (e) {
// ignore; file may be inaccessible
}
}


Future<void> stop() async {
await _player.stop();
}
}