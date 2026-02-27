import 'package:flutter/material.dart';

class UiToolsScreen extends StatefulWidget {
  const UiToolsScreen({super.key});

  @override
  State<UiToolsScreen> createState() => _UiToolsScreenState();
}

class _UiToolsScreenState extends State<UiToolsScreen> {
  final List<_SlideModel> _slides = List.generate(
    6,
    (index) => _SlideModel.sample(index + 1),
  );

  int _currentSlide = 0;
  double _zoom = 1;

  _SlideModel get _active => _slides[_currentSlide];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Инфографика: Canvas + Layers'),
        actions: [
          IconButton(
            tooltip: 'Экспорт PNG',
            onPressed: () => _showStub('Экспорт PNG каждого слайда'),
            icon: const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: 'Экспорт ZIP',
            onPressed: () => _showStub('Пакетный экспорт ZIP'),
            icon: const Icon(Icons.archive_outlined),
          ),
          IconButton(
            tooltip: 'Экспорт PDF',
            onPressed: () => _showStub('Экспорт в PDF'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Слайды', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _slides.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final selected = index == _currentSlide;
                          return ListTile(
                            selected: selected,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            tileColor: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            title: Text('Slide ${index + 1}'),
                            subtitle: Text('${_slides[index].layers.length} layers'),
                            onTap: () => setState(() => _currentSlide = index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.tune),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Рабочая область: Stack + Positioned + InteractiveViewer',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: Slider(
                            min: 0.5,
                            max: 2,
                            divisions: 15,
                            value: _zoom,
                            onChanged: (value) => setState(() => _zoom = value),
                          ),
                        ),
                        Text('${(_zoom * 100).round()}%'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3,
                        scaleEnabled: true,
                        child: Transform.scale(
                          scale: _zoom,
                          child: Container(
                            width: 800,
                            height: 450,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                for (final layer in _active.layers)
                                  Positioned(
                                    left: layer.left,
                                    top: layer.top,
                                    width: layer.width,
                                    height: layer.height,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: layer.color,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.black12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          layer.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Layers', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _active.layers.length,
                        itemBuilder: (context, index) {
                          final layer = _active.layers[index];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: layer.color),
                            title: Text(layer.label),
                            subtitle: Text(layer.type),
                            dense: true,
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    const Text('Рекомендуемый WEB-only стек:'),
                    const SizedBox(height: 8),
                    const Text(
                      'flutter_box_transform\nfile_picker\nflutter_svg\ngoogle_fonts\nscreenshot\narchive\nfile_saver',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStub(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — будет подключен через соответствующие пакеты.')),
    );
  }
}

class _SlideModel {
  _SlideModel({required this.id, required this.layers});

  final int id;
  final List<_LayerModel> layers;

  factory _SlideModel.sample(int id) {
    return _SlideModel(
      id: id,
      layers: [
        _LayerModel(
          type: 'background',
          label: 'Background',
          left: 0,
          top: 0,
          width: 800,
          height: 450,
          color: Colors.blueGrey.shade50,
        ),
        _LayerModel(
          type: 'image',
          label: 'Image',
          left: 32,
          top: 90,
          width: 260,
          height: 260,
          color: Colors.indigo.shade100,
        ),
        _LayerModel(
          type: 'title',
          label: 'Title text',
          left: 320,
          top: 90,
          width: 430,
          height: 80,
          color: Colors.orange.shade100,
        ),
        _LayerModel(
          type: 'badge',
          label: 'Badge',
          left: 320,
          top: 190,
          width: 190,
          height: 48,
          color: Colors.green.shade100,
        ),
        _LayerModel(
          type: 'description',
          label: 'Description',
          left: 320,
          top: 250,
          width: 430,
          height: 100,
          color: Colors.white,
        ),
      ],
    );
  }
}

class _LayerModel {
  _LayerModel({
    required this.type,
    required this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.color,
  });

  final String type;
  final String label;
  final double left;
  final double top;
  final double width;
  final double height;
  final Color color;
}
