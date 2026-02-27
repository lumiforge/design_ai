import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_openai/langchain_openai.dart' as lco;

import 'openai_config.dart';

class LangChainGenUiContentGenerator implements ContentGenerator {
  LangChainGenUiContentGenerator({required this.catalogId});

  final String catalogId;

  final _a2uiController = StreamController<A2uiMessage>.broadcast();
  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<ContentGeneratorError>.broadcast();
  final _isProcessing = ValueNotifier<bool>(false);

  bool _started = false;

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
          temperature: 0.2,
        ),
      );

      // TOOL: сложение a+b
      final addTool =
          lc.Tool.fromFunction<Map<String, Object?>, Map<String, Object?>>(
            name: 'add',
            description: '''
                  Складывает два числа.
                  Используй, когда пользователь просит посчитать сумму.
                  Вход: { "a": number, "b": number }
                  Выход: { "result": number }
            ''',
            inputJsonSchema: const <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'a': <String, Object?>{'type': 'number'},
                'b': <String, Object?>{'type': 'number'},
              },
              'required': <String>['a', 'b'],
              'additionalProperties': false,
            },
            getInputFromJson: (json) {
              final a = json['a'];
              final b = json['b'];
              debugPrint('a=$a, b=$b');
              if (a is num && b is num) {
                return <String, Object?>{'a': a, 'b': b};
              }
              throw lc.ToolException(
                message: 'Некорректные аргументы: ожидаются числа a и b.',
              );
            },
            func: (input) {
              final a = input['a'] as num;
              final b = input['b'] as num;
              return <String, Object?>{'result': a + b, 'a': a, 'b': b};
            },
          );

      // Агент
      final agent = lc.ToolsAgent.fromLLMAndTools(llm: llm, tools: [addTool]);
      final executor = lc.AgentExecutor(agent: agent);

      // ВАЖНО: заставляем модель выбирать widget из фиксированного набора
      final String instruction =
          '''
Ты генерируешь UI для Flutter GenUI. Верни СТРОГО валидный JSON (без markdown, без пояснений).

Формат:
{
  "widget": "MessageCard" | "BulletsCard" | "StatusBadgeCard" | "MathResultCard",
  "props": { ... }
}

Правила выбора:
- Если запрос про сложение/сумму/арифметику: используй инструмент add и верни widget="MathResultCard" с props:
  { "a": number, "b": number, "result": number, "title": string }
- Если пользователь просит план/список/шаги/пункты: widget="BulletsCard" props:
  { "title": string, "items": [string, ...] }
- Если пользователь пишет про статус (ok/ошибка/предупреждение) или просит показать статус: widget="StatusBadgeCard" props:
  { "label": string, "status": "ok" | "warning" | "error", "details": string }
- Иначе: widget="MessageCard" props:
  { "title": string, "body": string }

Теперь обработай запрос пользователя:
$userText
''';

      final String agentText = (await executor.run(instruction)).trim();

      final Map<String, Object?> ui = _safeParseJson(agentText);

      final widget = (ui['widget'] ?? 'MessageCard').toString();
      final Object rawProps = ui['props'] ?? const <String, Object?>{};
      final Map<String, Object?> props = rawProps is Map
          ? rawProps.map((k, v) => MapEntry(k.toString(), v))
          : <String, Object?>{};

      const surfaceId = 'main';
      const rootId = 'root';

      if (!_started) {
        _started = true;
        _a2uiController.add(
          BeginRendering(
            surfaceId: surfaceId,
            root: rootId,
            catalogId: catalogId,
          ),
        );
      }

      // В GenUI CatalogItem выбирается по ключу: componentProperties[<CatalogItem.name>] = props
      _a2uiController.add(
        SurfaceUpdate(
          surfaceId: surfaceId,
          components: <Component>[
            Component(
              id: rootId,
              componentProperties: <String, Object?>{widget: props},
            ),
          ],
        ),
      );

      // Текстовый фолбэк
      final textFallback = switch (widget) {
        'BulletsCard' =>
          '${props['title'] ?? 'Список'}\n- ${(props['items'] as List?)?.join('\n- ') ?? ''}',
        'StatusBadgeCard' =>
          'Статус: ${props['status'] ?? ''}\n${props['label'] ?? ''}\n${props['details'] ?? ''}',
        'MathResultCard' =>
          '${props['title'] ?? 'Результат'}\n${props['a']} + ${props['b']} = ${props['result']}',
        _ => '${props['title'] ?? 'Ответ'}\n\n${props['body'] ?? ''}',
      };

      _textController.add(textFallback);
    } catch (e, st) {
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
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, Object?>{
        'widget': 'MessageCard',
        'props': <String, Object?>{'title': 'Ответ', 'body': raw},
      };
    } catch (_) {
      return <String, Object?>{
        'widget': 'MessageCard',
        'props': <String, Object?>{'title': 'Ответ', 'body': raw},
      };
    }
  }
}
