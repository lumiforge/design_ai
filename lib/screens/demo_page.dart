import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'package:design_ai/genui/langchain_genui_content_generator.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const _catalogId = 'demoCatalog';
  static const _surfaceId = 'main';

  late final Catalog _catalog;
  late final A2uiMessageProcessor _processor;
  late final GenUiConversation _conversation;
  late final LangChainGenUiContentGenerator _generator;

  final _input = TextEditingController();
  String? _lastError;
  String? _lastTextResponse;
  final List<String> _history = [];
  String? _selectedWidget;

  @override
  void initState() {
    super.initState();

    _catalog = _buildCatalog();
    _processor = A2uiMessageProcessor(catalogs: [_catalog]);
    _generator = LangChainGenUiContentGenerator(
      catalogId: _catalogId,
      surfaceId: _surfaceId,
      catalogs: [_catalog],
    );

    _conversation = GenUiConversation(
      contentGenerator: _generator,
      a2uiMessageProcessor: _processor,
      onError: (e) => setState(() => _lastError = e.error.toString()),
      onTextResponse: (t) => setState(() => _lastTextResponse = t),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _conversation.dispose();
    super.dispose();
  }

  Catalog _buildCatalog() {
    final messageSchema = S.object(
      properties: {
        'title': S.string(description: 'Заголовок'),
        'body': S.string(description: 'Текст'),
      },
      required: ['title', 'body'],
      additionalProperties: false,
    );

    final bulletsSchema = S.object(
      properties: {
        'title': S.string(description: 'Заголовок'),
        'items': S.list(
          description: 'Список пунктов',
          items: S.string(description: 'Пункт списка'),
        ),
      },
      required: ['title', 'items'],
      additionalProperties: false,
    );

    final statusSchema = S.object(
      properties: {
        'label': S.string(description: 'Короткая подпись'),
        'status': S.string(description: 'ok | warning | error'),
        'details': S.string(description: 'Подробности'),
      },
      required: ['label', 'status', 'details'],
      additionalProperties: false,
    );

    final mathSchema = S.object(
      properties: {
        'title': S.string(description: 'Заголовок'),
        'a': S.number(description: 'Первое число'),
        'b': S.number(description: 'Второе число'),
        'result': S.number(description: 'Сумма'),
      },
      required: ['title', 'a', 'b', 'result'],
      additionalProperties: false,
    );

    final messageCard = CatalogItem(
      name: 'MessageCard',
      dataSchema: messageSchema,
      widgetBuilder: (ctx) {
        final Object raw = ctx.data;
        final Map<String, Object?> data = raw is Map
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : <String, Object?>{};
        return _MessageCard(
          title: (data['title'] ?? '').toString(),
          body: (data['body'] ?? '').toString(),
        );
      },
    );

    final bulletsCard = CatalogItem(
      name: 'BulletsCard',
      dataSchema: bulletsSchema,
      widgetBuilder: (ctx) {
        final Object raw = ctx.data;
        final Map<String, Object?> data = raw is Map
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : <String, Object?>{};
        final itemsRaw = data['items'];
        final List<String> items = itemsRaw is List
            ? itemsRaw.map((e) => e.toString()).toList()
            : const <String>[];

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['title'] ?? '').toString(),
                  style: Theme.of(ctx.buildContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(
                              ctx.buildContext,
                            ).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    final statusBadgeCard = CatalogItem(
      name: 'StatusBadgeCard',
      dataSchema: statusSchema,
      widgetBuilder: (ctx) {
        final Object raw = ctx.data;
        final Map<String, Object?> data = raw is Map
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : <String, Object?>{};

        final status = (data['status'] ?? 'ok').toString();
        final icon = switch (status) {
          'error' => Icons.error_outline,
          'warning' => Icons.warning_amber_outlined,
          _ => Icons.check_circle_outline,
        };

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['label'] ?? '').toString(),
                        style: Theme.of(ctx.buildContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (data['details'] ?? '').toString(),
                        style: Theme.of(ctx.buildContext).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final mathResultCard = CatalogItem(
      name: 'MathResultCard',
      dataSchema: mathSchema,
      widgetBuilder: (ctx) {
        final Object raw = ctx.data;
        final Map<String, Object?> data = raw is Map
            ? raw.map((k, v) => MapEntry(k.toString(), v))
            : <String, Object?>{};

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['title'] ?? 'Результат').toString(),
                  style: Theme.of(ctx.buildContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${data['a']} + ${data['b']} = ${data['result']}',
                  style: Theme.of(ctx.buildContext).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        );
      },
    );

    return Catalog([
      messageCard,
      bulletsCard,
      statusBadgeCard,
      mathResultCard,
    ], catalogId: _catalogId);
  }

  Future<void> _send() async {
    setState(() {
      _lastError = null;
      _lastTextResponse = null;
    });

    final text = _input.text.trim();
    if (text.isEmpty) return;

    _input.clear();

    // Добавляем в историю
    setState(() {
      _history.add(text);
    });

    // В genui есть UserMessage(List<MessagePart>) и UserMessage.text(String).
    await _conversation.sendRequest(UserMessage.text(text));

    // Обновляем выбранный виджет из последнего ответа
    if (_lastTextResponse != null) {
      setState(() {
        final match = RegExp(r'виджет: (\w+)').firstMatch(_lastTextResponse!);
        if (match != null) {
          _selectedWidget = match.group(1);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceNotifier = _conversation.surface(_surfaceId);

    return Scaffold(
      body: Column(
        children: [
          // === TOP BAR ===
          Container(
            height: 56,
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.palette, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  'Design AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _selectedWidget ?? 'No widget selected',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          // === MAIN CONTENT ===
          Expanded(
            child: Row(
              children: [
                // === LEFT SIDEBAR (History) ===
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(right: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: const Text(
                          'История генерирования',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _history.isEmpty
                            ? Center(
                                child: Text(
                                  'История пуста',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _history.length,
                                itemBuilder: (ctx, idx) {
                                  final item =
                                      _history[_history.length - 1 - idx];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      item,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onTap: () {
                                      // Можно добавить функцию для повтора
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                // === CENTER CANVAS ===
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<UiDefinition?>(
                            valueListenable: surfaceNotifier,
                            builder: (context, def, _) {
                              if (def == null) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Введи запрос — модель создаст UI',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: GenUiSurface(
                                    surfaceId: _surfaceId,
                                    host: _processor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Input bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  decoration: InputDecoration(
                                    hintText: 'Ejemplo: "Plan viaje a Tokio"',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ValueListenableBuilder<bool>(
                                valueListenable: _conversation.isProcessing,
                                builder: (context, busy, _) {
                                  return FilledButton.icon(
                                    onPressed: busy ? null : _send,
                                    icon: busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    label: const Text('Отправить'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // === RIGHT SIDEBAR (Properties) ===
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(left: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: const Text(
                          'Информация',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_lastError != null)
                                Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ошибка',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _lastError!,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_lastTextResponse != null)
                                Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Статус',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _lastTextResponse!,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_selectedWidget != null)
                                Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Компонент',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _selectedWidget!,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
