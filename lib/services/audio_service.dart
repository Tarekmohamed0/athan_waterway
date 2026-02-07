import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const String _audioPathKey = 'custom_audio_path';

  Future<void> playAzan() async {
    try {
      final audioPath = await getSavedAudioPath();

      if (audioPath != null && audioPath.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(audioPath));
      } else {
        print('No custom audio file selected');
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> stopAzan() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  Future<void> testAudio() async {
    await playAzan();
  }

  Future<void> saveAudioPath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_audioPathKey, path);
    } catch (e) {
      print('Error saving audio path: $e');
    }
  }

  Future<String?> getSavedAudioPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_audioPathKey);
    } catch (e) {
      print('Error getting saved audio path: $e');
      return null;
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
