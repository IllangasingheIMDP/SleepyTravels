import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;
class AudioFileService {
  AudioFileService._();
  static final AudioFileService instance = AudioFileService._();

  /// Copy a temporary audio file to permanent storage
  Future<String?> saveAudioFile(String tempPath, String originalName) async {
    try {
      final tempFile = File(tempPath);

      if (!await tempFile.exists()) {
        return null;
      }

      // Get the app's documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final alarmsDir = Directory(path.join(appDocDir.path, 'alarm_sounds'));

      // Create the directory if it doesn't exist
      if (!await alarmsDir.exists()) {
        await alarmsDir.create(recursive: true);
      }

      // Create a unique filename based on timestamp and original name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(originalName);
      final fileName =
          '${timestamp}_${path.basenameWithoutExtension(originalName)}$extension';
      final permanentPath = path.join(alarmsDir.path, fileName);

      // Copy the file to permanent location
      await tempFile.copy(permanentPath);

      
      return permanentPath;
    } catch (e) {
      developer.log('AudioFileService: Error saving audio file: $e');
      return null;
    }
  }

  /// Check if an audio file exists
  Future<bool> audioFileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete an audio file
  Future<bool> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the size of audio files directory
  Future<int> getAudioFilesDirSize() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final alarmsDir = Directory(path.join(appDocDir.path, 'alarm_sounds'));

      if (!await alarmsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (FileSystemEntity entity in alarmsDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      developer.log('AudioFileService: Error calculating directory size: $e');
      return 0;
    }
  }
}
