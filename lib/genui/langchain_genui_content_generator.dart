import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import 'package:design_ai/langchain/ui_json_generator.dart';

class LangChainGenUiContentGenerator implements ContentGenerator {
  LangChainGenUiContentGenerator({
    required this.catalogId,
    this.surfaceId,
    this.catalogs = const <Catalog>[],
    this.systemPrompt,
  }) : _uiJsonGenerator =
           LangChainUiJsonGenerator(catalogs: catalogs, systemPrompt: systemPrompt);

  final String catalogId;
  final String? surfaceId;
  final List<Catalog> catalogs;
  final String? systemPrompt;
  final LangChainUiJsonGenerator _uiJsonGenerator;

  final _a2uiController = StreamController<A2uiMessage>.broadcast();
  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<ContentGeneratorError>.broadcast();
  final _isProcessing = ValueNotifier<bool>(false);

  bool _started = false;
  String? _currentSurfaceId;

  @override
  Stream<A2uiMessage> get a2uiMessageStream => _a2uiController.stream;

  @override
  Stream<String> get textResponseStream => _textController.stream;

  @override
  Stream<ContentGeneratorError> get errorStream => _errorController.stream;

  @override
  ValueListenable<bool> get isProcessing => _isProcessing;

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
    A2UiClientCapabilities? clientCapabilities,
  }) async {
    if (_isProcessing.value) return;
    _isProcessing.value = true;

    try {
      final userText = _extractUserText(message).trim();
      if (userText.isEmpty) {
        _errorController.add(
          ContentGeneratorError(
            'Пустой ввод: нечего отправлять в модель.',
            StackTrace.current,
          ),
        );
        return;
      }

      final Map<String, Object?> ui = await _uiJsonGenerator.generateUiJson(userText);

      final widget = (ui['widget'] ?? 'MessageCard').toString();
      final Object rawProps = ui['props'] ?? const <String, Object?>{};
      final Map<String, Object?> props = rawProps is Map
          ? rawProps.map((k, v) => MapEntry(k.toString(), v))
          : <String, Object?>{};

      _currentSurfaceId ??=
          surfaceId ?? 'main-${DateTime.now().millisecondsSinceEpoch}';
      final currentSurfaceId = _currentSurfaceId!;
      const rootId = 'root';

      if (!_started) {
        _started = true;
        _a2uiController.add(
          BeginRendering(
            surfaceId: currentSurfaceId,
            root: rootId,
            catalogId: catalogId,
          ),
        );
      }

      _a2uiController.add(
        SurfaceUpdate(
          surfaceId: currentSurfaceId,
          components: <Component>[
            Component(
              id: rootId,
              componentProperties: <String, Object?>{widget: props},
            ),
          ],
        ),
      );

      _textController.add('✅ Создан виджет: $widget');
    } catch (e, st) {
      debugPrint('❌ ОШИБКА: $e\n$st');
      _errorController.add(ContentGeneratorError('Ошибка генерации: $e', st));
    } finally {
      _isProcessing.value = false;
    }
  }

  @override
  void dispose() {
    _isProcessing.dispose();
    _a2uiController.close();
    _textController.close();
    _errorController.close();
  }

  String _extractUserText(ChatMessage message) {
    if (message is UserMessage) {
      final buf = StringBuffer();
      for (final part in message.parts) {
        if (part is TextPart) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(part.text);
        }
      }
      return buf.toString();
    }
    return message.toString();
  }
}
