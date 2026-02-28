import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_openai/langchain_openai.dart' as lco;

import 'package:design_ai/openai_config.dart';

class LangChainUiJsonGenerator {
  LangChainUiJsonGenerator({
    this.catalogs = const <Catalog>[],
    this.systemPrompt,
  });

  final List<Catalog> catalogs;
  final String? systemPrompt;

  Future<Map<String, Object?>> generateUiJson(String userText) async {
    if (Openai.apiKey.trim().isEmpty) {
      throw StateError('Openai.apiKey пустой. Укажи ключ перед запуском приложения.');
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

    final instruction = systemPrompt ?? _buildDefaultPrompt(userText);

    debugPrint('=== PROMPT ===\n$instruction\n============');

    final response = await llm.call([lc.ChatMessage.humanText(instruction)]);

    final responseText = response.content.toString().trim();
    debugPrint('=== RESPONSE ===\n$responseText\n============');

    return _safeParseJson(responseText);
  }

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

  Map<String, Object?> _safeParseJson(String raw) {
    try {
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
