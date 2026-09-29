import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'image_search_screen.dart' show startImageSearch;

// ------------------------------------------------------------------ search

final searchTilesProvider = FutureProvider<List<SearchTile>>((ref) => ref.read(apiProvider).searchTiles());

/// This phone's recent searches -- the website keeps them in the browser
/// (easybuy.recent-searches, 8 newest, no repeats) and so does the app.
/// What one shopper typed is never sent anywhere.
class RecentSearches {
  static const _key = 'easybuy.recent-searches';
  static const _max = 8;

  static Future<List<String>> read() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> remember(String term) async {
    term = term.trim();
    if (term.length < 2) return;
    final kept = (await read()).where((t) => t.toLowerCase() != term.toLowerCase()).toList()..insert(0, term);
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, kept.take(_max).toList());
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

/// The website's search panel: the tile rail (popular searches with a
/// picture, then categories), this phone's Recent Searches, and -- once two
/// letters are typed -- the type-ahead in their place. Searching opens the
/// results as the website does: the Shop listing, with its sort and filters.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initial});
  final String? initial;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initial);
  List<String> _suggestions = const [];
  List<String> _recents = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    RecentSearches.read().then((r) {
      if (mounted) setState(() => _recents = r);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final s = await ref.read(apiProvider).suggest(text.trim());
        if (mounted && _controller.text.trim().length >= 2) setState(() => _suggestions = s);
      } catch (_) {
        // Suggestions are a convenience; typing still works without them.
      }
    });
  }

  /// A typed search is remembered; a tile or a recent chip just opens.
  Future<void> _search(String term, {bool remember = true}) async {
    term = term.trim();
    if (term.isEmpty) return;
    if (remember) await RecentSearches.remember(term);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    context.pushReplacement('/search/results?q=${Uri.encodeQueryComponent(term)}');
  }

  @override
  Widget build(BuildContext context) {
    final typing = _controller.text.trim().length >= 2 && _suggestions.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _typed,
          onSubmitted: _search,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            suffixIcon: IconButton(icon: const Icon(Icons.search, color: Brand.blue), onPressed: () => _search(_controller.text)),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 12),
            child: Material(
              color: Brand.blue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => startImageSearch(context),
                child: const SizedBox(width: 42, height: 42, child: Icon(Icons.photo_camera_outlined, color: Colors.white, size: 21)),
              ),
            ),
          ),
        ],
      ),
      body: typing ? _suggestionList() : _panel(),
    );
  }

  Widget _suggestionList() => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final s in _suggestions)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _search(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  Icon(Icons.search, size: 17, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 15, color: Color(0xFF374151)))),
                ]),
              ),
            ),
        ],
      );

  Widget _panel() {
    final tiles = ref.watch(searchTilesProvider).value ?? const <SearchTile>[];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
      if (tiles.isNotEmpty)
        LayoutBuilder(builder: (context, box) {
          // Four tiles and the edge of a fifth, as on the website's phone
          // view: the half tile says "swipe".
          final w = (box.maxWidth - 3 * 12) / 4.45;
          return SizedBox(
            height: w + 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _Tile(tile: tiles[i], width: w, onSearch: (q) => _search(q, remember: false)),
            ),
          );
        }),
      if (_recents.isNotEmpty)
        Container(
          margin: EdgeInsets.only(top: tiles.isEmpty ? 0 : 16),
          padding: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Recent Searches', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.blue))),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500, visualDensity: VisualDensity.compact),
                onPressed: () async {
                  await RecentSearches.clear();
                  if (mounted) setState(() => _recents = const []);
                },
                child: const Text('Clear', style: TextStyle(fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final term in _recents)
                Material(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _search(term, remember: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(term, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.width, required this.onSearch});
  final SearchTile tile;
  final double width;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => tile.categoryId != null ? context.push('/category/${tile.categoryId}') : onSearch(tile.query ?? tile.label),
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: width,
                height: width,
                color: const Color(0xFFF3F4F6),
                child: tile.imageUrl != null
                    ? NetImage(tile.imageUrl, radius: 0)
                    : Icon(Icons.search, size: 28, color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 8),
            Text(tile.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937), height: 1.2)),
          ]),
        ),
      );
}

/// A − n + control. Tapping the number lets the customer type one.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 100000});
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  Future<void> _type(BuildContext context) async {
    final controller = TextEditingController(text: '$value');
    final typed = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantity'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)), child: const Text('OK')),
        ],
      ),
    );
    if (typed != null) onChanged(typed.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(visualDensity: VisualDensity.compact, onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove, size: 18)),
          InkWell(
            onTap: () => _type(context),
            child: SizedBox(width: 44, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            // From zero, the first tap jumps straight to the minimum.
            onPressed: value < max ? () => onChanged(value == 0 && min == 0 ? 1 : value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ]),
      );
}
