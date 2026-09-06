import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCommand {
  const VoiceCommand(this.type, {this.argument});
  final VoiceCommandType type;
  final String? argument;
}

enum VoiceCommandType {
  unknown,
  openApp,
  back,
  home,
  scrollUp,
  scrollDown,
  tap,
  closeApp,
}

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    _initialized = await _speech.initialize();
    return _initialized;
  }

  bool get isListening => _speech.isListening;

  Future<void> listen({required void Function(String text) onResult}) async {
    if (!_initialized && !await initialize()) return;
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'pt_BR',
        listenMode: stt.ListenMode.confirmation,
      ),
      onResult: (result) {
        if (result.finalResult) onResult(result.recognizedWords);
      },
    );
  }

  Future<void> stop() => _speech.stop();

  VoiceCommand parse(String raw) {
    final text = raw.toLowerCase().trim();
    if (text.isEmpty) return const VoiceCommand(VoiceCommandType.unknown);
    if (text.contains('volte') || text.contains('voltar')) {
      return const VoiceCommand(VoiceCommandType.back);
    }
    if (text.contains('tela inicial') ||
        text == 'home' ||
        text.contains('início')) {
      return const VoiceCommand(VoiceCommandType.home);
    }
    if (text.contains('role para baixo') || text.contains('rolar para baixo')) {
      return const VoiceCommand(VoiceCommandType.scrollDown);
    }
    if (text.contains('role para cima') || text.contains('rolar para cima')) {
      return const VoiceCommand(VoiceCommandType.scrollUp);
    }
    if (text.contains('toque') || text.contains('clique')) {
      return const VoiceCommand(VoiceCommandType.tap);
    }
    if (text.contains('feche') || text.contains('fechar')) {
      return const VoiceCommand(VoiceCommandType.closeApp);
    }
    final openIndex = text.indexOf('abra ');
    if (openIndex >= 0) {
      final app = text
          .substring(openIndex + 5)
          .replaceFirst(RegExp(r'^o '), '')
          .trim();
      if (app.isNotEmpty) {
        return VoiceCommand(VoiceCommandType.openApp, argument: app);
      }
    }
    return const VoiceCommand(VoiceCommandType.unknown);
  }
}
