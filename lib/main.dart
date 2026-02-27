import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'langchain_genui_generator.dart';
import 'ui_tools_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI + LangChain.dart Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AppHomePage(),
    );
  }
}

class AppHomePage extends StatefulWidget {
  const AppHomePage({super.key});

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [DemoPage(), UiToolsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'GenUI Demo',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            label: 'UI Tools',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();

    _catalog = _buildCatalog();
    _processor = A2uiMessageProcessor(catalogs: [_catalog]);
    _generator = LangChainGenUiContentGenerator(catalogId: _catalogId);

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

    // В genui есть UserMessage(List<MessagePart>) и UserMessage.text(String).
    await _conversation.sendRequest(UserMessage.text(text));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceNotifier = _conversation.surface(_surfaceId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GenUI + LangChain.dart'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UiToolsScreen()),
              );
            },
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('UI Tools'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<UiDefinition?>(
              valueListenable: surfaceNotifier,
              builder: (context, def, _) {
                if (def == null) {
                  return const Center(
                    child: Text(
                      'Отправь сообщение — модель создаст UI (карточку) через GenUI.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return GenUiSurface(surfaceId: _surfaceId, host: _processor);
              },
            ),
          ),
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Ошибка: $_lastError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_lastTextResponse != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _lastTextResponse!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText:
                          'Например: "Сделай краткий план путешествия в Токио на 3 дня"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: _conversation.isProcessing,
                  builder: (context, busy, _) {
                    return FilledButton(
                      onPressed: busy ? null : _send,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send'),
                    );
                  },
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
