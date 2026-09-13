import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/models/gesture_state.dart';
import 'core/services/native_bridge.dart';
import 'core/services/speech_service.dart';
import 'core/services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'JARVIS',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF050A12),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF25D9FF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechService();
  final _tts = TtsService();
  final _native = NativeBridge();
  late final AnimationController _visualizer;
  CameraController? _camera;
  bool assistant = false;
  bool fingerControl = false;
  bool cameraActive = false;
  bool accessibility = false;
  String transcript = '';
  String message = 'Olá. Como posso ajudar?';
  GestureState gestureState = GestureState.idle;
  Offset cursor = const Offset(.5, .5);
  Offset? _lastCursor;
  List<CameraDescription> _cameras = const [];

  @override
  void initState() {
    super.initState();
    _visualizer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _tts.initialize();
    _refreshAccessibility();
  }

  @override
  void dispose() {
    _visualizer.dispose();
    _camera?.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _refreshAccessibility() async {
    final value = await _native.isAccessibilityEnabled();
    if (mounted) setState(() => accessibility = value);
  }

  Future<void> _toggleAssistant() async {
    if (assistant) {
      await _speech.stop();
      setState(() => assistant = false);
      await _tts.speak('Assistente desativado.');
      return;
    }
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _notify('Permita o microfone nas configurações do Android.');
      return;
    }
    final ready = await _speech.initialize();
    if (!ready) {
      _notify('Reconhecimento de voz indisponível neste dispositivo.');
      return;
    }
    setState(() => assistant = true);
    await _tts.speak('Assistente ativado.');
    await _listen();
  }

  Future<void> _listen() async {
    if (!assistant) return;
    setState(() => message = 'Estou ouvindo...');
    await _speech.listen(
      onResult: (text) async {
        setState(() => transcript = text);
        final command = _speech.parse(text);
        await _execute(command);
        if (assistant && mounted) await _listen();
      },
    );
  }

  Future<void> _execute(VoiceCommand command) async {
    switch (command.type) {
      case VoiceCommandType.openApp:
        final app = command.argument ?? '';
        final opened = await _native.openApp(app);
        await _respond(
          opened ? 'Abrindo $app.' : 'Não encontrei o aplicativo $app.',
        );
      case VoiceCommandType.back:
        await _native.performAction('back');
        await _respond('Voltando.');
      case VoiceCommandType.home:
        await _native.performAction('home');
        await _respond('Indo para a tela inicial.');
      case VoiceCommandType.scrollDown:
        await _native.performAction('scrollDown');
        await _respond('Rolando para baixo.');
      case VoiceCommandType.scrollUp:
        await _native.performAction('scrollUp');
        await _respond('Rolando para cima.');
      case VoiceCommandType.tap:
        await _native.performAction('tap', x: cursor.dx, y: cursor.dy);
        await _respond('Toque executado.');
      case VoiceCommandType.closeApp:
        await _native.performAction('back');
        await _respond('Fechando.');
      case VoiceCommandType.unknown:
        await _respond('Não entendi o comando.');
    }
  }

  Future<void> _respond(String text) async {
    if (!mounted) return;
    setState(() => message = text);
    await _tts.speak(text);
  }

  Future<void> _toggleCamera() async {
    if (cameraActive) {
      await _camera?.dispose();
      setState(() {
        _camera = null;
        cameraActive = false;
        fingerControl = false;
      });
      return;
    }
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _notify('Permita a câmera nas configurações do Android.');
      return;
    }
    try {
      _cameras = await availableCameras();
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      setState(() {
        _camera = controller;
        cameraActive = true;
        fingerControl = true;
        gestureState = GestureState.moving;
      });
    } catch (_) {
      _notify('Não foi possível iniciar a câmera.');
    }
  }

  void _onGesturePan(DragUpdateDetails details, BoxConstraints constraints) {
    if (!fingerControl) return;
    final next = Offset(
      (cursor.dx + details.delta.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (cursor.dy + details.delta.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );
    _lastCursor = cursor;
    setState(() {
      cursor = cursor + (next - cursor) * .35;
      gestureState = details.delta.dy.abs() > details.delta.dx.abs()
          ? GestureState.scroll
          : GestureState.moving;
    });
  }

  Future<void> _onGestureEnd() async {
    if (!fingerControl || _lastCursor == null) return;
    final dx = cursor.dx - _lastCursor!.dx;
    final dy = cursor.dy - _lastCursor!.dy;
    if (dy.abs() > .12) {
      await _native.performAction(dy > 0 ? 'scrollDown' : 'scrollUp');
    } else if (dx.abs() > .12) {
      await _native.performAction(dx > 0 ? 'swipeRight' : 'swipeLeft');
    }
    setState(() => gestureState = GestureState.idle);
  }

  Future<void> _onTapDown(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (!fingerControl) return;
    setState(() {
      gestureState = GestureState.tap;
      cursor = Offset(
        (details.localPosition.dx / constraints.maxWidth).clamp(0, 1),
        (details.localPosition.dy / constraints.maxHeight).clamp(0, 1),
      );
    });
    await _native.performAction('tap', x: cursor.dx, y: cursor.dy);
    if (mounted) setState(() => gestureState = GestureState.idle);
  }

  void _notify(String text) {
    setState(() => message = text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF081827), Color(0xFF050A12)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _header(),
                  const SizedBox(height: 20),
                  _greeting(),
                  const SizedBox(height: 16),
                  _cameraArea(),
                  const SizedBox(height: 18),
                  _statusPanel(),
                  const SizedBox(height: 16),
                  _controls(),
                  const SizedBox(height: 18),
                  _calibrationCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFB2F5FF), Color(0xFF25D9FF)],
            ).createShader(b),
            child: const Text(
              'JARVIS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: 5,
              ),
            ),
          ),
          Text(
            'ASSISTENTE INTELIGENTE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .45),
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      IconButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (_) => _settingsSheet(),
        ),
        icon: const Icon(Icons.tune_rounded),
        color: const Color(0xFF8DEBFF),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .06),
        ),
      ),
    ],
  );

  Widget _greeting() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        transcript.isEmpty
            ? 'Ative o assistente ou controle por dedo para começar.'
            : 'Comando reconhecido: $transcript',
        style: TextStyle(
          color: Colors.white.withValues(alpha: .55),
          fontSize: 13,
        ),
      ),
    ],
  );

  Widget _cameraArea() => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      onPanUpdate: (d) => _onGesturePan(d, constraints),
      onPanEnd: (_) => _onGestureEnd(),
      onTapDown: (d) => _onTapDown(d, constraints),
      child: Container(
        height: 255,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF06111D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF25D9FF).withValues(alpha: .18),
          ),
        ),
        child: Stack(
          children: [
            if (_camera?.value.isInitialized == true)
              Positioned.fill(child: CameraPreview(_camera!))
            else
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _visualizer,
                  builder: (_, child) => CustomPaint(
                    painter: VisualizerPainter(
                      _visualizer.value,
                      assistant || fingerControl,
                    ),
                  ),
                ),
              ),
            if (fingerControl)
              Positioned(
                left: cursor.dx * constraints.maxWidth - 14,
                top: cursor.dy * 255 - 14,
                child: const _Cursor(),
              ),
            Positioned(
              top: 14,
              left: 14,
              child: _chip(
                cameraActive ? 'CÂMERA ATIVA' : 'CÂMERA INATIVA',
                cameraActive,
              ),
            ),
            Positioned(
              bottom: 14,
              right: 14,
              child: _chip(
                gestureState.name.toUpperCase(),
                gestureState != GestureState.idle,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _chip(String text, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .48),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: active ? const Color(0xFF51E6B0) : Colors.white54,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _statusPanel() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Column(
      children: [
        _status('Microfone', assistant, Icons.mic_rounded),
        _line(),
        _status('Câmera', cameraActive, Icons.camera_alt_rounded),
        _line(),
        _status('Controle por dedo', fingerControl, Icons.touch_app_rounded),
        _line(),
        _status(
          'Accessibility Service',
          accessibility,
          Icons.accessibility_new_rounded,
        ),
      ],
    ),
  );
  Widget _line() =>
      Divider(height: 17, color: Colors.white.withValues(alpha: .07));
  Widget _status(String label, bool active, IconData icon) => Row(
    children: [
      Icon(
        icon,
        size: 17,
        color: active ? const Color(0xFF51E6B0) : Colors.white38,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      Text(
        active ? 'ATIVO' : 'INATIVO',
        style: TextStyle(
          color: active ? const Color(0xFF51E6B0) : Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    ],
  );

  Widget _controls() => Column(
    children: [
      _button(
        assistant ? 'Desativar Assistente' : 'Ativar Assistente',
        assistant ? Icons.stop_circle_outlined : Icons.mic_rounded,
        assistant,
        _toggleAssistant,
      ),
      const SizedBox(height: 10),
      _button(
        cameraActive ? 'Desativar Câmera e Dedo' : 'Ativar Controle por Dedo',
        Icons.pan_tool_alt_rounded,
        cameraActive,
        _toggleCamera,
      ),
      const SizedBox(height: 10),
      _button(
        'Abrir Accessibility Service',
        Icons.accessibility_new_rounded,
        false,
        () async {
          await _native.openAccessibilitySettings();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _refreshAccessibility();
        },
      ),
    ],
  );
  Widget _button(
    String text,
    IconData icon,
    bool primary,
    VoidCallback action,
  ) => SizedBox(
    width: double.infinity,
    height: 51,
    child: FilledButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 19),
      label: Text(text),
      style: FilledButton.styleFrom(
        backgroundColor: primary
            ? const Color(0xFF19BBD9)
            : Colors.white.withValues(alpha: .07),
        foregroundColor: primary
            ? const Color(0xFF02131B)
            : const Color(0xFFBCEFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _calibrationCard() => Card(
    color: Colors.white.withValues(alpha: .04),
    child: ListTile(
      leading: const Icon(
        Icons.center_focus_strong_rounded,
        color: Color(0xFF8DEBFF),
      ),
      title: const Text('Calibração'),
      subtitle: const Text('Mapeamento câmera → tela'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CalibrationScreen()),
      ),
    ),
  );

  Widget _settingsSheet() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configurações',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'O JARVIS usa apenas permissões necessárias: câmera e microfone. O Accessibility Service é opcional e deve ser ativado manualmente pelo usuário.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Permissões do aplicativo'),
            onTap: () async {
              await openAppSettings();
              if (mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

class _Cursor extends StatelessWidget {
  const _Cursor();
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF5DEBFF), width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF25D9FF).withValues(alpha: .7),
          blurRadius: 14,
        ),
      ],
    ),
    child: const Center(
      child: Icon(Icons.add, size: 13, color: Color(0xFFB8F8FF)),
    ),
  );
}

class VisualizerPainter extends CustomPainter {
  VisualizerPainter(this.progress, this.active);
  final double progress;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;
    for (var i = 0; i < 5; i++) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 2 : 1
        ..color = const Color(0xFF25D9FF)
            .withValues(alpha: (active ? .28 : .1) - i * .035);
      canvas.drawCircle(c, r - i * 20 + (active ? pulse * 4 : 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter old) =>
      old.progress != progress || old.active != active;
}

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});
  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int points = 0;
  final samples = <Offset>[];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calibração')),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mapeie a câmera para a tela',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Toque nos alvos em sequência. O procedimento serve como base para ajustar a área de controle.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: GestureDetector(
              onTapDown: (d) {
                setState(() {
                  samples.add(d.localPosition);
                  points = samples.length;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF081827),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Icon(
                    points >= 5 ? Icons.check_circle : Icons.gps_fixed,
                    size: 58,
                    color: points >= 5
                        ? const Color(0xFF51E6B0)
                        : const Color(0xFF25D9FF),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            points >= 5
                ? 'Calibração concluída.'
                : 'Pontos coletados: $points/5',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: points >= 5 ? () => Navigator.pop(context) : null,
            child: const Text('Salvar calibração'),
          ),
        ],
      ),
    ),
  );
}
