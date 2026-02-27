## Пример “как это будет выглядеть” (архитектура)

**Документ** → список `Slide` (6–10) → у каждого слайда список `Layer` (фон/картинка/текст/иконка/плашка) → редактор показывает текущий `Slide` → экспорт рендерит каждый слайд в PNG → (опционально) пакует в ZIP или PDF.

---

# 1) Canvas и слои (основа)

**Встроенные виджеты Flutter (для WEB отлично):**

* `Stack` + `Positioned` — слои на слайде (фон, фото, плашки, тексты).
* `InteractiveViewer` — зум/пан всего холста (как “рабочая область”).
* `CustomPaint` — если хочешь стрелки/фигуры/линии на Canvas (инфографика часто требует).

---

# 2) Перемещение/ресайз/поворот слоёв (как Canva)

Чтобы не писать весь UX “с нуля”, бери:

* **flutter_box_transform** — очень удобный для drag+resize рамки/ручек и трансформаций (подходит под редактор “слоя”). ([Dart packages][1])

---

# 3) Импорт ассетов пользователя (картинки/иконки/шаблоны)

Для web-only это важно:

* **file_picker** — выбор файлов в браузере (картинки/SVG/шрифты/шаблоны), работает на Web. ([Dart packages][2])
  ⚠️ На web обычно работаешь **с bytes**, а не с “путём файла” (это нормальная специфика браузера).

---

# 4) SVG/иконки (для инфографики must-have)

* **flutter_svg** — отображение SVG (иконки, пиктограммы, стрелки). ([Dart packages][3])

---

# 5) Шрифты и текст

* **google_fonts** — быстро подключать шрифты, удобно для “маркетплейсных” заголовков/акцентов. ([Dart packages][4])
  Плюс в changelog прямо отмечали улучшения для web-форматов шрифтов (WOFF/WOFF2). ([Dart packages][5])

---

# 6) Экспорт каждого слайда в PNG (самая важная часть на WEB)

Есть 2 ключевых момента:

### 6.1 Чем снимать виджет в изображение

* **screenshot** — обёртка над `RenderRepaintBoundary`, умеет захват виджета в image bytes. ([Dart packages][6])

### 6.2 ВАЖНО про Flutter Web renderer

На Web `toImage()` **зависит от рендерера**: исторически в HTML renderer были ограничения, а на CanvasKit работает заметно лучше (и даже в issue Flutter это прямо обсуждается). ([GitHub][7])
И в официальных доках Flutter подробно описаны web-рендереры (CanvasKit / skwasm и т.д.) — для графического редактора это критично. ([Flutter][8])

**Практический совет:** для редактора инфографики на web почти всегда выбирают **CanvasKit / skwasm**, чтобы экспорт/эффекты/трансформации были стабильнее.

---

# 7) Экспорт “пачкой”: ZIP или PDF

## Вариант A: ZIP из PNG (обычно идеален для маркетплейсов)

* **archive** (Dart) — создаёшь ZIP прямо в web (без платформенных плагинов), кладёшь туда `slide_01.png ... slide_10.png`. ([Dart packages][9])

## Вариант B: один PDF со слайдами

* **pdf** + **printing** — генерация PDF и печать/скачивание/шаринг, включая web. ([Dart packages][10])

---

# 8) “Скачать файл” в браузере (PNG/ZIP/PDF)

На web “сохранить в галерею” не нужно (это mobile-история). Тебе нужен download/save dialog:

* **file_saver** — сохранение байтов как файла на разных платформах, включая Web. ([Dart packages][11])

---

## Рекомендованный набор пакетов (минимально достаточный стек WEB-only)

1. `flutter_box_transform` — трансформации слоёв ([Dart packages][1])
2. `file_picker` — загрузка картинок/SVG/шрифтов пользователем ([Dart packages][2])
3. `flutter_svg` — иконки/вектор ([Dart packages][3])
4. `google_fonts` — типографика ([Dart packages][4])
5. `screenshot` (или чистый `RepaintBoundary`) — PNG каждого слайда ([Dart packages][6])
6. `archive` — ZIP пачки PNG ([Dart packages][9])
7. `file_saver` — скачать PNG/ZIP/PDF ([Dart packages][11])
   (опционально) `pdf` + `printing` — если нужен PDF-экспорт ([Dart packages][10])

---

## 2 момента

1. **Сразу делай “модель документа”** (Slides → Layers), а UI пусть просто отражает её. Иначе экспорт/undo/redo/копирование слоёв станет болью.
2. **Web renderer**: для редактора целись в CanvasKit/skwasm, иначе можешь упереться в ограничения `toImage()` на HTML renderer. ([GitHub][7])

---


[1]: https://pub.dev/packages/flutter_box_transform "flutter_box_transform | Flutter package"
[2]: https://pub.dev/packages/file_picker "file_picker | Flutter package"
[3]: https://pub.dev/packages/flutter_svg "flutter_svg | Flutter package"
[4]: https://pub.dev/packages/google_fonts "google_fonts | Flutter package"
[5]: https://pub.dev/packages/google_fonts/changelog "google_fonts changelog | Flutter package"
[6]: https://pub.dev/packages/screenshot "screenshot | Flutter package"
[7]: https://github.com/flutter/flutter/issues/102636 "(web) (html-renderer) implement toImage · Issue #102636"
[8]: https://docs.flutter.dev/platform-integration/web/renderers "Web renderers"
[9]: https://pub.dev/packages/archive "archive | Dart package"
[10]: https://pub.dev/packages/printing "printing | Flutter package"
[11]: https://pub.dev/packages/file_saver "file_saver | Flutter package"
