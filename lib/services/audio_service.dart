import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const String _audioPathKey = 'custom_audio_path';
  bool _isPlaying = false;

  AudioService() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });
  }

  Future<void> playAzan() async {
    try {
      final audioPath = await getSavedAudioPath();

      if (audioPath != null && audioPath.isNotEmpty) {
        final file = File(audioPath);
        if (!await file.exists()) {
          print('Audio file does not exist: $audioPath');
          return;
        }

        print('Playing audio from: $audioPath');
        await _audioPlayer.stop();
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer.setSource(DeviceFileSource(audioPath));
        await _audioPlayer.resume();
      } else {
        print('No custom audio file selected');
      }
    } catch (e) {
      print('Error playing audio: $e');
      rethrow;
    }
  }

  Future<void> stopAzan() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        print('Audio stopped');
      }
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  bool get isPlaying => _isPlaying;

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
