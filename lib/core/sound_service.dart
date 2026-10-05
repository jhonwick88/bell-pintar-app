import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsInitialized = false;

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5); // 0.5 is normal speed in flutter_tts
      _ttsInitialized = true;
    } catch (_) {}
  }

  /// Memutar suara bel dari aset aplikasi (chime, westminster, bell) atau file lokal perangkat
  Future<void> playDemoBell({int? audioId, String? title, String? filePath}) async {
    try {
      await _audioPlayer.stop();

      // Jika file berasal dari upload lokal perangkat
      if (filePath != null && filePath.isNotEmpty) {
        try {
          await _audioPlayer.play(DeviceFileSource(filePath));
          return;
        } catch (_) {}
      }

      String assetFile = 'audio/bell_sekolah.mp3';

      if (audioId == 1) {
        assetFile = 'audio/masuk_jam1.wav';
      } else if (audioId == 5 || audioId == 6) {
        assetFile = 'audio/istirahat.wav';
      } else if (audioId == 9 || audioId == 10) {
        assetFile = 'audio/westminster.wav';
      } else if (audioId == 11) {
        assetFile = 'audio/chime.wav';
      } else {
        assetFile = 'audio/chime.wav';
      }

      await _audioPlayer.play(AssetSource(assetFile));
    } catch (_) {
      // Fallback jika asset spesifik belum termuat
      try {
        await _audioPlayer.play(AssetSource('audio/chime.wav'));
      } catch (_) {}
    }
  }

  /// Memutar suara pengumuman Text-To-Speech
  Future<void> speakDemoTTS(String text, {double speed = 1.0, bool playChime = true}) async {
    try {
      await _initTts();
      if (playChime) {
        try {
          await _audioPlayer.play(AssetSource('audio/chime.wav'));
          await Future.delayed(const Duration(milliseconds: 1400));
        } catch (_) {}
      }

      final rate = 0.5 * speed;
      await _flutterTts.setSpeechRate(rate.clamp(0.2, 1.0));
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();
    } catch (_) {}
  }
}
