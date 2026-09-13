import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jarvis/main.dart';

Future<void> scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('renderiza a tela principal completa do JARVIS', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const JarvisApp());

    expect(find.text('JARVIS'), findsOneWidget);
    expect(find.text('Olá. Como posso ajudar?'), findsOneWidget);
    expect(find.text('CÂMERA INATIVA'), findsOneWidget);

    await scrollToText(tester, 'Ativar Assistente');
    expect(find.text('Ativar Assistente'), findsOneWidget);
    expect(find.text('Ativar Controle por Dedo'), findsOneWidget);
    expect(find.text('Abrir Accessibility Service'), findsOneWidget);
  });

  testWidgets('expõe a entrada de calibração', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    await scrollToText(tester, 'Calibração');

    expect(find.text('Calibração'), findsOneWidget);
    expect(find.text('Mapeamento câmera → tela'), findsOneWidget);
  });
}
