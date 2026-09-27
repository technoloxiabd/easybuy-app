import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'common.dart';

/// An endlessly scrolling product grid for a search, a category or the home
/// feed. Fetches the next page as the customer nears the end.
class ProductGrid extends ConsumerStatefulWidget {
  const ProductGrid({super.key, this.query, this.category, this.sort, this.header});
  final String? query;
  final int? category;
  final String? sort;
  final Widget? header;

  @override
  ConsumerState<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<ProductGrid> {
  final _items = <ProductCard>[];
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProductGrid old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query || old.category != widget.category || old.sort != widget.sort) _reset();
  }

  Future<void> _reset() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _done = false;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final page = await ref.read(apiProvider).products(query: widget.query, category: widget.category, sort: widget.sort, cursor: _cursor);
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reset,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) _load();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            if (_items.isEmpty && _error != null)
              SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _reset))
            else if (_items.isEmpty && _done)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.search_off_rounded, title: 'No products found', body: 'Try other words, or browse the categories.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => ProductTile(product: _items[i]),
                ),
              ),
            if (_loading) const SliverToBoxAdapter(child: LoadingView()),
            if (_items.isNotEmpty && _error != null && !_loading)
              SliverToBoxAdapter(child: TextButton(onPressed: _load, child: const Text('Load more'))),
          ],
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 1, child: NetImage(product.imageUrl, radius: 0)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.3)),
                const Spacer(),
                Text(Money.bdt(product.unitPrice), style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  [
                    'Min ${product.minQuantity} pcs',
                    if (product.saleCount > 0) '${Money.count(product.saleCount)} sold',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
