import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> initialize() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String message) async {
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> stop() => _tts.stop();
}
