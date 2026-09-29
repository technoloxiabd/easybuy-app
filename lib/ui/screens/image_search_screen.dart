import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';
import '../widgets/tab_bar.dart';

/// The camera button: pick a photo, then search with it. [replace] swaps the
/// current results page for the new one instead of stacking another.
Future<void> startImageSearch(BuildContext context, {bool replace = false}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Search by image', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Brand.blue)),
          const SizedBox(height: 4),
          const Text('A clear photo of a single item works best.', style: TextStyle(color: Brand.grayText)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Brand.blue, minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take a photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
        ]),
      ),
    ),
  );
  if (source == null) return;

  // The server shrinks every photo to 400px before searching; sending more
  // than this only costs the shopper's data. JPEG either way (iOS HEIC too).
  final shot = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
  if (shot == null || !context.mounted) return;
  replace ? context.pushReplacement('/search/image', extra: shot.path) : context.push('/search/image', extra: shot.path);
}

const _sorts = {'': 'Best match', 'price_asc': 'Price: low to high', 'price_desc': 'Price: high to low', 'sales': 'Most sold'};

/// The website's image results page (search/image.blade.php): the photo,
/// a wait message that owns up when the supplier is slow, the matches in
/// the ordinary grid, sort, "Show more", and the crop refinement.
class ImageSearchScreen extends ConsumerStatefulWidget {
  const ImageSearchScreen({super.key, required this.path});

  /// The local photo; null when the screen was opened without one.
  final String? path;

  @override
  ConsumerState<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends ConsumerState<ImageSearchScreen> {
  String? _upload;
  List<ProductCard>? _items;
  int? _next;
  String _sort = '';
  Object? _error;
  bool _loadingMore = false;
  String _wait = 'Searching for similar products… this usually takes 5–10 seconds.';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.path != null) _search();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The website's escalating wait text: a normal 9s search must not look stuck.
  void _startTicker() {
    final started = DateTime.now();
    const stages = [
      (20, 'Still working. Thanks for your patience…'),
      (10, 'Almost there — this one is taking a little longer than usual…'),
      (5, 'Still searching — comparing your photo against millions of products…'),
    ];
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(started).inSeconds;
      for (final (after, text) in stages) {
        if (elapsed >= after) {
          if (mounted && _wait != text) setState(() => _wait = text);
          return;
        }
      }
    });
  }

  Future<void> _search() async {
    setState(() {
      _items = null;
      _error = null;
      _next = null;
      _wait = 'Searching for similar products… this usually takes 5–10 seconds.';
    });
    _startTicker();
    try {
      final api = ref.read(apiProvider);
      _upload ??= await api.uploadSearchImage(widget.path!);
      final r = await api.imageMatches(_upload!, sort: _sort.isEmpty ? null : _sort);
      if (mounted) {
        setState(() {
          _items = r.products;
          _next = r.nextPage;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _ticker?.cancel();
    }
  }

  Future<void> _more() async {
    if (_next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await ref.read(apiProvider).imageMatches(_upload!, page: _next, sort: _sort.isEmpty ? null : _sort);
      if (!mounted) return;
      final seen = {for (final p in _items!) p.id};
      setState(() {
        _items = [..._items!, ...r.products.where((p) => seen.add(p.id))];
        _next = r.nextPage;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _crop() async {
    final cropped = await Navigator.of(context).push<String>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => CropScreen(path: widget.path!)),
    );
    if (cropped != null && mounted) context.pushReplacement('/search/image', extra: cropped);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final searching = widget.path != null && items == null && _error == null;

    return Scaffold(
      appBar: const SiteHeader(),
      bottomNavigationBar: const PageTabBar(current: null),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _header(searching)),
        if (widget.path == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'Search by image',
              body: 'Take or choose a photo of the item you want.',
              action: FilledButton(onPressed: () => startImageSearch(context, replace: true), child: const Text('Choose a photo')),
            ),
          )
        else if (_error != null)
          SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _search))
        else if (searching)
          const _SkeletonGrid()
        else if (items!.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(icon: Icons.image_search_outlined, title: 'No visually similar products found.', body: 'Try a clearer photo, or search by keyword.'),
          )
        else ...[
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: ProductCardGrid(products: items)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: _next == null
                  ? const SizedBox.shrink()
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _loadingMore ? null : _more,
                      child: _loadingMore
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Show more results', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _header(bool searching) => WebCard(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (context.canPop()) ...[
              Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.pop(),
                  child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left, size: 28)),
                ),
              ),
              const SizedBox(width: 14),
            ],
            const Expanded(
              child: Text('Search by image', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Brand.blue, letterSpacing: -0.3)),
            ),
          ]),
          if (widget.path != null) ...[
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(widget.path!), width: 96, height: 96, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: searching
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Brand.blue)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_wait, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14.5, height: 1.4))),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_items != null)
                          Text('${_items!.length}${_next != null ? '+' : ''} similar products',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                        const SizedBox(height: 8),
                        // 1688's index locks onto ONE subject; boxing the
                        // item is the single best fix for poor matches.
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Brand.blue, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 12)),
                          onPressed: _crop,
                          icon: const Icon(Icons.crop, size: 18),
                          label: const Text('Wrong matches? Crop to the item', style: TextStyle(fontSize: 13.5)),
                        ),
                      ]),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => startImageSearch(context, replace: true),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: Text(widget.path == null ? 'Choose a photo' : 'New photo'),
              ),
            ),
            if (_items != null && _items!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD1D5DB))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _sort,
                      style: const TextStyle(fontFamily: 'InstrumentSans', fontSize: 15, color: Brand.ink),
                      items: [for (final e in _sorts.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                      onChanged: (v) {
                        if (v == null || v == _sort) return;
                        // Re-sorts the same cached matches on the server: no new search.
                        setState(() => _sort = v);
                        _search();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      );
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.66),
          itemCount: 6,
          itemBuilder: (_, _) => Container(decoration: BoxDecoration(color: const Color(0xFFE9ECEF), borderRadius: BorderRadius.circular(14))),
        ),
      );
}

/// The website's crop-before-search overlay: drag a box around the item.
/// Pops with the cropped photo's path, the whole photo's for "Use full
/// photo", or nothing on cancel. The crop happens on the phone.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.path});
  final String path;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _image;

  /// The box, in the displayed photo's coordinates.
  Rect? _box;
  Offset? _dragFrom;
  bool _moving = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final codec = await ui.instantiateImageCodec(await File(widget.path).readAsBytes());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  Future<void> _done(Size shown) async {
    final image = _image!;
    final box = _box!;
    setState(() => _busy = true);
    final scale = image.width / shown.width;
    final src = Rect.fromLTRB(box.left * scale, box.top * scale, box.right * scale, box.bottom * scale)
        .intersect(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

    // At most 800px on the long side: the server searches at 400.
    final shrink = math.min(1.0, 800 / math.max(src.width, src.height));
    final w = math.max(1, (src.width * shrink).round());
    final h = math.max(1, (src.height * shrink).round());
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(image, src, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..filterQuality = FilterQuality.high);
    final cropped = await recorder.endRecording().toImage(w, h);
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${Directory.systemTemp.path}/crop-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png!.buffer.asUint8List());
    if (mounted) Navigator.pop(context, file.path);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, title: const Text('Crop to the item', style: TextStyle(color: Colors.white))),
      body: SafeArea(
        child: image == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : LayoutBuilder(builder: (context, box) {
                // The photo, fitted into the space above the buttons.
                final room = Size(box.maxWidth - 32, box.maxHeight - 150);
                final fit = math.min(room.width / image.width, room.height / image.height);
                final shown = Size(image.width * fit, image.height * fit);
                Rect clamp(Rect r) => Rect.fromLTRB(
                      r.left.clamp(0, shown.width), r.top.clamp(0, shown.height),
                      r.right.clamp(0, shown.width), r.bottom.clamp(0, shown.height),
                    );
                final ok = _box != null && _box!.width > 12 && _box!.height > 12;

                return Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Text('Drag a box around the item you want to find', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox.fromSize(
                        size: shown,
                        child: GestureDetector(
                          onPanStart: (d) {
                            _moving = _box?.contains(d.localPosition) ?? false;
                            _dragFrom = d.localPosition;
                            if (!_moving) setState(() => _box = Rect.fromPoints(d.localPosition, d.localPosition));
                          },
                          onPanUpdate: (d) => setState(() {
                            if (_moving) {
                              final moved = _box!.shift(d.delta);
                              final dx = moved.left < 0 ? -moved.left : (moved.right > shown.width ? shown.width - moved.right : 0.0);
                              final dy = moved.top < 0 ? -moved.top : (moved.bottom > shown.height ? shown.height - moved.bottom : 0.0);
                              _box = moved.shift(Offset(dx, dy));
                            } else {
                              _box = clamp(Rect.fromPoints(_dragFrom!, d.localPosition));
                            }
                          }),
                          child: Stack(fit: StackFit.expand, children: [
                            RawImage(image: image, fit: BoxFit.fill),
                            if (_box != null) CustomPaint(painter: _CropPainter(_box!)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(0, 48)),
                          onPressed: _busy ? null : () => Navigator.pop(context, widget.path),
                          child: const Text('Use full photo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Brand.orange, minimumSize: const Size(0, 48)),
                          onPressed: ok && !_busy ? () => _done(shown) : null,
                          child: _busy
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Search this area'),
                        ),
                      ),
                    ]),
                  ),
                ]);
              }),
      ),
    );
  }
}

/// Dims everything outside the box and draws its dashed-looking edge.
class _CropPainter extends CustomPainter {
  _CropPainter(this.box);
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(box);
    canvas.drawPath(outside, Paint()..color = const Color(0x8C000000));
    canvas.drawRect(box, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Corner handles, so the box reads as something to drag.
    const l = 14.0;
    final handle = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    for (final (c, dx, dy) in [(box.topLeft, 1.0, 1.0), (box.topRight, -1.0, 1.0), (box.bottomLeft, 1.0, -1.0), (box.bottomRight, -1.0, -1.0)]) {
      canvas.drawLine(c, c + Offset(l * dx, 0), handle);
      canvas.drawLine(c, c + Offset(0, l * dy), handle);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.box != box;
}
