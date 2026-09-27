import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/product_grid.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.read(apiProvider).categories());

// ------------------------------------------------------------------ home

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const _SearchField(),
        actions: [
          IconButton(tooltip: 'Messages', onPressed: () => context.push('/chat'), icon: const Icon(Icons.chat_bubble_outline)),
        ],
      ),
      body: ProductGrid(
        header: categories.isEmpty
            ? null
            : SizedBox(
                height: 104,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _CategoryBubble(category: categories[i]),
                ),
              ),
      ),
    );
  }
}

/// Looks like a search box; opens the search screen with suggestions.
class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/search'),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Icon(Icons.search, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text('Search products', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          ]),
        ),
      );
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/category/${category.id}?name=${Uri.encodeComponent(category.name)}'),
        child: SizedBox(
          width: 72,
          child: Column(children: [
            SizedBox(width: 56, height: 56, child: NetImage(category.imageUrl, radius: 28)),
            const SizedBox(height: 6),
            Text(category.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.15)),
          ]),
        ),
      );
}

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
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search products',
            hintStyle: TextStyle(color: Colors.white70),
            filled: false,
            border: InputBorder.none,
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
          ? ProductGrid(query: _query, sort: _sort.isEmpty ? null : _sort)
          : ListView(children: [
              for (final s in _suggestions)
                ListTile(leading: const Icon(Icons.search), title: Text(s), onTap: () => _submit(s)),
            ]),
    );
  }
}

// ------------------------------------------------------------------ categories

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = list[i];
            void open(Category x) => context.push('/category/${x.id}?name=${Uri.encodeComponent(x.name)}');
            return Card(
              child: c.children.isEmpty
                  ? ListTile(leading: SizedBox(width: 44, height: 44, child: NetImage(c.imageUrl)), title: Text(c.name), onTap: () => open(c))
                  : ExpansionTile(
                      leading: SizedBox(width: 44, height: 44, child: NetImage(c.imageUrl)),
                      title: Text(c.name),
                      shape: const Border(),
                      children: [
                        ListTile(title: Text('All ${c.name}'), onTap: () => open(c)),
                        for (final child in c.children) ListTile(title: Text(child.name), onTap: () => open(child)),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class CategoryProductsScreen extends StatelessWidget {
  const CategoryProductsScreen({super.key, required this.id, required this.name});
  final int id;
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name), actions: [IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search))]),
        body: ProductGrid(category: id),
      );
}

// ------------------------------------------------------------------ product

final productProvider = FutureProvider.family<ProductDetail, int>((ref, id) => ref.read(apiProvider).product(id));

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          IconButton(tooltip: 'Ask about this product', onPressed: () => context.push('/chat?product=$id'), icon: const Icon(Icons.chat_bubble_outline)),
          IconButton(tooltip: 'Cart', onPressed: () => context.go('/cart'), icon: const Icon(Icons.shopping_cart_outlined)),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(productProvider(id))),
        data: (p) => _ProductBody(product: p),
      ),
    );
  }
}

class _ProductBody extends ConsumerStatefulWidget {
  const _ProductBody({required this.product});
  final ProductDetail product;

  @override
  ConsumerState<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends ConsumerState<_ProductBody> {
  /// sku_id -> pieces, for a product with several options.
  final _perVariant = <String, int>{};
  late int _single = widget.product.minQuantity;
  String? _lineTotal;
  String? _unitPrice;
  Timer? _debounce;

  ProductDetail get p => widget.product;
  bool get _hasOptions => p.variants.length > 1;
  int get _pieces => _hasOptions ? _perVariant.values.fold(0, (a, b) => a + b) : _single;

  @override
  void initState() {
    super.initState();
    _quote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// The server prices the quantity (tiers count every option together).
  void _quote() {
    _debounce?.cancel();
    final qty = _pieces;
    if (qty < p.minQuantity || (_hasOptions && p.variantsPricedSeparately)) {
      setState(() => _lineTotal = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await ref.read(apiProvider).price(p.id, qty, skuId: _hasOptions ? null : p.variants.firstOrNull?.skuId);
        if (mounted && qty == _pieces) {
          setState(() {
            _lineTotal = '${r['line_total_bdt']}';
            _unitPrice = '${r['unit_price_bdt']}';
          });
        }
      } catch (_) {
        if (mounted) setState(() => _lineTotal = null);
      }
    });
  }

  Future<void> _add({required bool buyNow}) async {
    final cart = ref.read(cartProvider.notifier);
    if (_hasOptions) {
      final chosen = Map.fromEntries(_perVariant.entries.where((e) => e.value > 0));
      if (chosen.isEmpty) throw ApiError(code: 'no_option', message: 'Choose at least one option.');
      await cart.add(p.id, variants: chosen);
    } else {
      await cart.add(p.id, skuId: p.variants.firstOrNull?.skuId, quantity: _single);
    }
    if (!mounted) return;
    if (buyNow) {
      context.push('/checkout');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Added to cart'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'View cart', onPressed: () => context.go('/cart')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final belowMin = _pieces < p.minQuantity;
    return Column(children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          _Gallery(images: p.images),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.isSoldOut) ...[const NoticeBox('Sold out — this item is not available right now.', tone: NoticeTone.danger), const SizedBox(height: 12)],
              Text(p.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Money.bdt(_unitPrice ?? p.unitPrice), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.orange)),
                const Text(' / pc', style: TextStyle(color: Colors.grey)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Pill('Min ${p.minQuantity} pcs${p.minQuantityIsSupplier ? ' (supplier)' : ''}'),
                if (p.saleCount > 0) _Pill('${Money.count(p.saleCount)} sold'),
                if (p.isFactory) const _Pill('Factory'),
                if (p.estimatedWeightKg != null) _Pill('≈ ${Money.kg(p.estimatedWeightKg)}'),
              ]),
              if (p.priceTiers.length > 1) ...[
                const SizedBox(height: 16),
                const Text('Wholesale price', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final t in p.priceTiers)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(children: [
                          Text(Money.bdt(t.unitPrice), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.orange)),
                          Text(t.maxQuantity == null ? '≥ ${t.minQuantity} pcs' : '${t.minQuantity}–${t.maxQuantity} pcs', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ]),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 18),
              if (_hasOptions) ...[
                Text('Choose quantities (${p.variants.length} options)', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('The minimum counts all options together.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                for (final v in p.variants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          SizedBox(width: 48, height: 48, child: NetImage(v.imageUrl, radius: 8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(v.label.isEmpty ? v.skuId : v.label, style: const TextStyle(fontSize: 13)),
                              if (p.variantsPricedSeparately) Text(Money.bdt(v.unitPrice), style: const TextStyle(fontSize: 12, color: Brand.orange, fontWeight: FontWeight.w700)),
                              if (v.stock != null) Text('${v.stock} in stock', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ]),
                          ),
                          QtyStepper(
                            value: _perVariant[v.skuId] ?? 0,
                            min: 0,
                            onChanged: (n) {
                              setState(() => _perVariant[v.skuId] = n);
                              _quote();
                            },
                          ),
                        ]),
                      ),
                    ),
                  ),
              ] else ...[
                Row(children: [
                  const Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.w700))),
                  QtyStepper(
                    value: _single,
                    min: p.minQuantity,
                    onChanged: (n) {
                      setState(() => _single = n);
                      _quote();
                    },
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              const NoticeBox(
                'Shipping from China is charged later, by the actual weight of your parcel when it reaches Dhaka.',
                tone: NoticeTone.info,
              ),
            ]),
          ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('$_pieces pcs', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (belowMin)
                Text('Minimum ${p.minQuantity} pcs', style: const TextStyle(color: Brand.warning, fontSize: 12))
              else if (_lineTotal != null)
                Text(Money.bdt(_lineTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: BusyButton(label: 'Add to cart', outlined: true, onPressed: p.isSoldOut || _pieces == 0 ? null : () => _add(buyNow: false))),
              const SizedBox(width: 10),
              Expanded(child: BusyButton(label: 'Buy now', onPressed: p.isSoldOut || _pieces == 0 ? null : () => _add(buyNow: true))),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});
  final List<String> images;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const AspectRatio(aspectRatio: 1, child: NetImage(null, radius: 0));
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Container(color: Colors.white, child: NetImage(widget.images[i], fit: BoxFit.contain, radius: 0)),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Text('${_index + 1} / ${widget.images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Brand.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Brand.blue, fontWeight: FontWeight.w600)),
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
