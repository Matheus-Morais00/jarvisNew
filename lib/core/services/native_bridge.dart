import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.jarvis.app/native');

  Future<bool> openApp(String name) async {
    return await _channel.invokeMethod<bool>('openApp', {'name': name}) ??
        false;
  }

  Future<bool> performAction(String action, {double? x, double? y}) async {
    return await _channel.invokeMethod<bool>('performAction', {
          'action': action,
          'x': ?x,
          'y': ?y,
        }) ??
        false;
  }

  Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  }

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');
}
