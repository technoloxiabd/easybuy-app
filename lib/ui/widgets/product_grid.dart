import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import 'common.dart';
import 'site.dart';

/// What a listing asks for: the website's category/search/shop query.
class ListingQuery {
  const ListingQuery({this.query, this.category, this.sort, this.minPrice, this.maxPrice, this.factoryOnly = false, this.seller});
  final String? query;
  final int? category;
  final String? sort;
  final String? minPrice;
  final String? maxPrice;
  final bool factoryOnly;

  /// One seller's store: their products, best sellers first.
  final int? seller;

  ListingQuery copyWith({String? sort, String? minPrice, String? maxPrice, bool? factoryOnly, bool clearPrices = false}) => ListingQuery(
        query: query,
        category: category,
        sort: sort ?? this.sort,
        minPrice: clearPrices ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrices ? null : (maxPrice ?? this.maxPrice),
        factoryOnly: factoryOnly ?? this.factoryOnly,
        seller: seller,
      );

  bool get hasFilters => (minPrice ?? '').isNotEmpty || (maxPrice ?? '').isNotEmpty || factoryOnly;

  @override
  bool operator ==(Object other) =>
      other is ListingQuery && other.query == query && other.category == category && other.sort == sort &&
      other.minPrice == minPrice && other.maxPrice == maxPrice && other.factoryOnly == factoryOnly && other.seller == seller;

  @override
  int get hashCode => Object.hash(query, category, sort, minPrice, maxPrice, factoryOnly, seller);
}

/// An endlessly scrolling grid of the website's product cards, with any
/// header slivers above it. Fetches the next page near the end.
class ProductGrid extends ConsumerStatefulWidget {
  const ProductGrid({super.key, required this.listing, this.headers = const [], this.footer, this.onRefresh, this.empty});
  final ListingQuery listing;
  final List<Widget> headers;

  /// Below the last product, once there are no more pages to fetch.
  final Widget? footer;
  final Future<void> Function()? onRefresh;

  /// In place of "No products found" when there is nothing to list.
  final Widget? empty;

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
    if (old.listing != widget.listing) _reset();
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
    final q = widget.listing;
    try {
      final api = ref.read(apiProvider);
      final page = q.seller != null
          ? await api.sellerProducts(q.seller!, cursor: _cursor)
          : await api.products(
              query: q.query, category: q.category, sort: q.sort, cursor: _cursor,
              minPrice: q.minPrice, maxPrice: q.maxPrice, factoryOnly: q.factoryOnly,
            );
      if (!mounted || q != widget.listing) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {
          await widget.onRefresh?.call();
          await _reset();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 700) _load();
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ...widget.headers,
              if (_items.isEmpty && _error != null)
                SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _reset))
              else if (_items.isEmpty && _done)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: widget.empty ?? const EmptyState(icon: Icons.search_off_rounded, title: 'No products found', body: 'Try other words, or browse the categories.'),
                )
              else
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), sliver: ProductCardGrid(products: _items)),
              if (_loading) const SliverToBoxAdapter(child: LoadingView()),
              if (_items.isNotEmpty && _error != null && !_loading)
                SliverToBoxAdapter(child: TextButton(onPressed: _load, child: const Text('Load more'))),
              if (_done && widget.footer != null) SliverToBoxAdapter(child: widget.footer),
            ],
          ),
        ),
      );
}
