import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/product_grid.dart';

// ------------------------------------------------------------------ search

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initial});
  final String? initial;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _query;
  String _sort = '';
  List<String> _suggestions = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = widget.initial;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    setState(() => _query = null);
    if (text.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final s = await ref.read(apiProvider).suggest(text.trim());
        if (mounted && _query == null) setState(() => _suggestions = s);
      } catch (_) {
        // Suggestions are a convenience; typing still works without them.
      }
    });
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _controller.text = text.trim();
    setState(() {
      _query = text.trim();
      _suggestions = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: widget.initial == null,
          textInputAction: TextInputAction.search,
          onChanged: _typed,
          onSubmitted: _submit,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            suffixIcon: const Icon(Icons.search, color: Brand.blue),
          ),
        ),
        actions: [
          if (_query != null)
            PopupMenuButton<String>(
              tooltip: 'Sort',
              icon: const Icon(Icons.sort),
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: '', child: Text('Best match')),
                PopupMenuItem(value: 'price_asc', child: Text('Price: low to high')),
                PopupMenuItem(value: 'price_desc', child: Text('Price: high to low')),
                PopupMenuItem(value: 'newest', child: Text('Newest')),
              ],
            ),
        ],
      ),
      body: _query != null
          ? ProductGrid(listing: ListingQuery(query: _query, sort: _sort.isEmpty ? null : _sort))
          : ListView(children: [
              for (final s in _suggestions)
                ListTile(leading: const Icon(Icons.search), title: Text(s), onTap: () => _submit(s)),
            ]),
    );
  }
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
