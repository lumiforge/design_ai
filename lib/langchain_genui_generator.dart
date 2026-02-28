import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_openai/langchain_openai.dart' as lco;

import 'openai_config.dart';

class LangChainGenUiContentGenerator implements ContentGenerator {
  LangChainGenUiContentGenerator({
    required this.catalogId,
    this.surfaceId,
    this.catalogs = const <Catalog>[],
    this.systemPrompt,
  });

  final String catalogId;
  final String? surfaceId;
  final List<Catalog> catalogs;
  final String? systemPrompt;

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

  Catalog? _getCatalog() {
    try {
      return catalogs.isNotEmpty ? catalogs.first : null;
    } catch (_) {
      return null;
    }
  }

  String _buildDefaultPrompt(String userText) {
    final catalog = _getCatalog();
    if (catalog == null) {
      return '''
        You are a UI layout generator for a marketplace product card builder.
        You MUST generate only valid JSON.
        You MUST use ONLY the allowed component types.
        You MUST NOT invent new component names.
        You MUST NOT use absolute positioning.
        You MUST select layoutVariant instead of coordinates.

        Allowed components:
        - MarketplaceCanvas
        - BackgroundLayer
        - ProductImageLayer
        - TitleText
        - SubtitleText
        - FeatureBullets
        - BadgePill
        - PriceBlock
        - CTASticker
        - CompositionGrid

        Available layoutVariant values:
        v1, v2, v3, v4, v5, v6

        Text limits:
        - title: max 70 chars
        - subtitle: max 90 chars
        - bullet: max 40 chars
        - badge: max 20 chars

        If strictMode = true:
        - Avoid marketing exaggerations
        - Avoid words like: лучший, №1, супер, гарантия 100%, акция сегодня
        - Keep text neutral and informative

        Output format:
        {
          "preset": "wb_main | ozon_main",
          "layoutVariant": "vX",
          "tokens": {
            "accentColor": "#RRGGBB",
            "backgroundType": "solid | gradient"
          },
          "layers": []
        }
      ''';
    }

    final widgetNames = catalog.items.map((item) => item.name).toList();
    final widgetsStr = widgetNames.map((w) => '"$w"').join(' | ');

    return '''
          
        Ты генерируешь UI для Flutter GenUI. Верни СТРОГО валидный JSON (без markdown, без пояснений).

        Доступные виджеты: $widgetsStr

        Формат:
        {
          "widget": $widgetsStr,
          "props": { ... }
        }

        Выбери подходящий виджет на основе запроса пользователя и заполни props согласно схеме виджета.

        Запрос пользователя:
        $userText
    ''';
  }

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

      if (Openai.apiKey.trim().isEmpty) {
        _errorController.add(
          ContentGeneratorError(
            'Openai.apiKey пустой. Укажи ключ перед запуском приложения.',
            StackTrace.current,
          ),
        );
        return;
      }

      debugPrint('LLM baseUrl=${Openai.baseUrl}');

      final llm = lco.ChatOpenAI(
        apiKey: Openai.apiKey,
        baseUrl: Openai.baseUrl,
        defaultOptions: const lco.ChatOpenAIOptions(
          model: 'gpt-4o-mini',
          temperature: 0.7,
        ),
      );

      // Используем системный промпт или строим по умолчанию
      final instruction = systemPrompt ?? _buildDefaultPrompt(userText);

      debugPrint('=== PROMPT ===\n$instruction\n============');

      final response = await llm.call([lc.ChatMessage.humanText(instruction)]);

      final responseText = response.content.toString().trim();
      debugPrint('=== RESPONSE ===\n$responseText\n============');

      final Map<String, Object?> ui = _safeParseJson(responseText);

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

      // Текстовый фолбэк
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

  Map<String, Object?> _safeParseJson(String raw) {
    try {
      // Пытаемся найти JSON в ответе
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }

      return <String, Object?>{};
    } catch (e) {
      debugPrint('JSON parse error: $e, raw=$raw');
      return <String, Object?>{};
    }
  }
}
