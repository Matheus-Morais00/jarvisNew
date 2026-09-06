# JARVIS para Android

Aplicativo Flutter de assistente virtual com comandos de voz, síntese de voz, câmera, cursor de controle, abertura dinâmica de aplicativos e integração opcional com o Accessibility Service do Android.

## Requisitos

Instale Flutter estável, Dart compatível, Android Studio, Android SDK, Android SDK Platform, Android SDK Build-Tools e um dispositivo Android ou emulador com câmera e microfone.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

O APK será criado em `build/app/outputs/flutter-apk/app-release.apk`.

Para executar diretamente em um dispositivo:

```bash
flutter run
```

## Funcionalidades implementadas

A tela principal apresenta o visualizador futurista, estados do microfone, câmera, controle por dedo e Accessibility Service. O reconhecimento de voz entende comandos em português para abrir aplicativos, voltar, ir para Home, rolar, tocar e fechar. A resposta é emitida por síntese de voz em português do Brasil.

A abertura de aplicativos é dinâmica: o código Kotlin pesquisa os aplicativos instalados pelo nome exibido e usa o launcher oficial do Android para abrir o resultado mais próximo. Nenhum pacote de aplicativo específico é fixado no código.

A câmera frontal pode ser ativada com permissão explícita. A área de controle apresenta um cursor virtual suavizado e uma camada de interação para validar movimentação, toque, swipe e scroll. A tela de calibração coleta cinco pontos para servir de base ao mapeamento câmera–tela.

## Accessibility Service

O serviço é opcional e não é ativado automaticamente. O usuário precisa tocar em **Abrir Accessibility Service** e habilitar manualmente o JARVIS nas configurações do Android. As ações nativas utilizam apenas APIs oficiais: `GLOBAL_ACTION_BACK`, `GLOBAL_ACTION_HOME` e `dispatchGesture`.

O Android pode bloquear ou limitar gestos em determinados aplicativos, telas protegidas, campos seguros ou versões específicas do sistema. O serviço não tenta contornar essas proteções.

## Permissões

O aplicativo solicita somente `CAMERA` e `RECORD_AUDIO` em tempo de execução. A declaração `QUERY_ALL_PACKAGES` é usada para permitir a pesquisa dinâmica de aplicativos instalados, mas pode exigir justificativa adicional caso o aplicativo seja publicado na Google Play. O Accessibility Service exige ativação manual e consentimento explícito do usuário.

## Estrutura

```text
lib/
  main.dart
  core/models/gesture_state.dart
  core/services/native_bridge.dart
  core/services/speech_service.dart
  core/services/tts_service.dart
android/app/src/main/kotlin/com/jarvis/app/jarvis/
  MainActivity.kt
  AppLauncher.kt
  JarvisAccessibilityService.kt
android/app/src/main/res/xml/
  jarvis_accessibility_config.xml
```

## Validação realizada

`flutter analyze` e `flutter test` foram executados com sucesso no ambiente de desenvolvimento. A geração do APK não foi executada nesta máquina porque o Android SDK não está instalado no ambiente; em uma máquina com o Android SDK configurado, o comando de build acima gera o APK normalmente.

## Observação sobre rastreamento de mão

A arquitetura deixa a câmera, o pipeline de coordenadas, o filtro e o controlador nativo separados. A camada visual já possui cursor, estados e gestos. Para produção, o detector de landmarks da mão deve ser conectado ao ponto de entrada de coordenadas da camada de câmera usando um modelo MediaPipe/TFLite compatível com a versão Android escolhida e distribuído como asset do aplicativo. Essa dependência requer um modelo de landmarks e calibração de desempenho específicos do dispositivo; ela não é inventada nem substituída por uma API inexistente neste pacote.

## Build automático pelo GitHub Actions

O arquivo `.github/workflows/android.yml` configura o build automático. Depois de enviar o projeto para um repositório GitHub, cada push na branch `main` ou `master`, cada pull request e cada execução manual em **Actions → JARVIS Android Build → Run workflow** fará o seguinte:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Ao final, o APK estará disponível na execução do workflow, em **Summary → Artifacts**, com o nome `jarvis-apk-N`. O artefato permanece disponível por 30 dias.

Para publicar:

```bash
git init
git add .
git commit -m "Initial JARVIS Android project"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

O workflow utiliza Java 17, Flutter estável e o Android SDK fornecido pelo runner Ubuntu do GitHub. O build gerado usa a configuração de assinatura debug existente no projeto, adequada para testes e distribuição interna. Para publicar na Google Play, será necessário adicionar uma chave de assinatura Android protegida em GitHub Secrets e configurar uma etapa de assinatura release.
