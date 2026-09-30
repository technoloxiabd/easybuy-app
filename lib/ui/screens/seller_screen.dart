import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/json.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/product_grid.dart';

/// A seller's store, the website's /seller/{id} (catalog/seller.blade.php):
/// their initial on a brand tile, name, score chips, then everything of
/// theirs in our catalogue, best sellers first (owner, 1 Oct 2026: the
/// product page had no way to reach the seller).
///
/// Opened from a product, [preview] is the seller the product page already
/// has, so the header shows at once while the store loads.
class SellerScreen extends ConsumerStatefulWidget {
  const SellerScreen({super.key, required this.id, this.preview});
  final int id;
  final Json? preview;

  @override
  ConsumerState<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends ConsumerState<SellerScreen> {
  late Json? _seller = widget.preview;
  Object? _error;
  Timer? _stocking;
  int _checks = 0;

  /// Bumped when more products have landed, to reload the grid.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stocking?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final seller = await ref.read(apiProvider).seller(widget.id);
      if (!mounted) return;
      setState(() {
        _seller = seller;
        _error = null;
      });
      // Their catalogue is being brought in: look again every 15 seconds,
      // for about three minutes, as the website's page refreshes itself.
      if (boolean(seller['stocking']) && _stocking == null) {
        _stocking = Timer.periodic(const Duration(seconds: 15), (_) => _recheck());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _recheck() async {
    if (++_checks > 12) {
      _stocking?.cancel();
      return;
    }
    try {
      final seller = await ref.read(apiProvider).seller(widget.id);
      if (!mounted) return;
      final more = integer(seller['products']) != integer(_seller?['products']);
      setState(() {
        _seller = seller;
        if (more) _generation++;
      });
      if (!boolean(seller['stocking'])) _stocking?.cancel();
    } catch (_) {
      // Tried again on the next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _seller;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView(),
      );
    }
    final stocking = boolean(s['stocking']);
    return Scaffold(
      backgroundColor: Brand.page,
      body: SafeArea(
        bottom: false,
        child: ProductGrid(
          key: ValueKey(_generation),
          listing: ListingQuery(seller: widget.id),
          onRefresh: _load,
          headers: [
            SliverToBoxAdapter(child: _SellerHeader(seller: s)),
            if (stocking)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _StockingNote(),
                ),
              ),
          ],
          empty: const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No products from this seller yet.',
            body: 'Their catalogue is loading — new products appear here automatically.',
          ),
        ),
      ),
    );
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.seller});
  final Json seller;

  @override
  Widget build(BuildContext context) {
    final name = str(seller['name']).trim();
    final chinese = RegExp(r'[一-鿿]').hasMatch(name);
    final count = NumberFormat('#,##0');
    final sales = integer(seller['total_sales']);
    final products = integer(seller['products']);
    final factory = seller['is_super_factory'] == true ? 'Super factory' : (seller['is_factory'] == true ? 'Factory' : null);

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (context.canPop()) ...[
          Material(
            color: Brand.page,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.pop(),
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left, size: 28)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // Storefront mark: the seller's initial on a brand tile.
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Brand.blue, borderRadius: BorderRadius.circular(12)),
          child: Text(
            name.isEmpty ? 'S' : name.characters.first,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? 'Seller store' : name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, color: Brand.ink)),
            if (chinese)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text("The seller's name is shown in Chinese, as they did not publish the English name.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (seller['rating'] != null) _Chip(icon: Icons.star_rounded, label: 'Rating', value: '${seller['rating']}'),
              if (seller['years'] != null) _Chip(icon: Icons.emoji_events_outlined, label: 'Level', value: '${seller['years']} yrs'),
              if (sales > 0) _Chip(icon: Icons.shopping_cart_outlined, label: 'Sales', value: count.format(sales)),
              if (products > 0) _Chip(icon: Icons.inventory_2_outlined, label: 'Products', value: count.format(products)),
              if (factory != null) _Chip(icon: Icons.factory_outlined, value: factory),
              if (seller['location'] != null) _Chip(icon: Icons.location_on_outlined, label: '${seller['location']}'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// The website's seller score chip: white bordered pill, a brand-blue icon,
/// a grey label and a bold brand-blue figure.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, this.label, this.value});
  final IconData icon;
  final String? label;
  final String? value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Brand.blue),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
          ],
          if (value != null) ...[
            const SizedBox(width: 6),
            Text(value!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Brand.blue)),
          ],
        ]),
      );
}

class _StockingNote extends StatelessWidget {
  const _StockingNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Brand.blue)),
          SizedBox(width: 12),
          Expanded(
            child: Text("Seller's catalogue loading — new products appear below automatically.",
                style: TextStyle(fontSize: 13.5, color: Brand.blue)),
          ),
        ]),
      );
}
