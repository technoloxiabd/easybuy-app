import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../screens/image_search_screen.dart' show startImageSearch;
import 'common.dart';

/// The website's phone header: the easyBUY logo, a rounded search pill, and
/// the blue camera button. Tapping the pill opens search.
class SiteHeader extends StatelessWidget implements PreferredSizeWidget {
  const SiteHeader({super.key, this.leading});
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(children: [
          ?leading,
          Image.asset('assets/logo.png', height: 30),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/search'),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(children: [
                  Expanded(child: Text('Search', style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w400))),
                  const Icon(Icons.search, color: Brand.blue, size: 22),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The website's camera button: search 1688 by photo.
          Tooltip(
            message: 'Search by image',
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
        ]),
      );
}

/// A white rounded card, the website's `rounded-2xl bg-white shadow-sm`.
class WebCard extends StatelessWidget {
  const WebCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: child,
      );
}

/// The website's section header: orange kicker bar, heavy title, and an
/// optional blue "View all ›".
class KickerHeader extends StatelessWidget {
  const KickerHeader({super.key, required this.title, this.subtitle, this.onViewAll, this.large = false, this.light = false});
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  final bool large;
  final bool light;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 6, height: large ? 34 : 28, decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: large ? 21 : 19, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2, color: light ? Colors.white : Brand.ink)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: TextStyle(fontSize: 13, color: light ? Colors.white70 : Brand.grayText)),
              ),
          ]),
        ),
        if (onViewAll != null)
          InkWell(
            onTap: onViewAll,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View all', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: light ? Colors.white : Brand.blue)),
                Icon(Icons.chevron_right, size: 20, color: light ? Colors.white : Brand.blue),
              ]),
            ),
          ),
      ]);
}

/// "23k sold", "1.4M sold" -- the website's compact figure.
String compactCount(int n) {
  if (n >= 1000000) return '${_trim((n / 1000000).toStringAsFixed(1))}M';
  if (n >= 1000) return '${n >= 10000 ? (n / 1000).round() : _trim((n / 1000).toStringAsFixed(1))}k';
  return '$n';
}

String _trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

/// "4.5", "4" -- a rating as the website prints it.
String ratingLabel(String rating) => _trim(double.tryParse(rating)?.toStringAsFixed(1) ?? rating);

/// The sold / rating metrics beside a card's price.
class ProductMetrics extends StatelessWidget {
  const ProductMetrics({super.key, required this.saleCount, this.rating});
  final int saleCount;
  final String? rating;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, color: Brand.grayText, fontWeight: FontWeight.w600);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (saleCount > 0) ...[
        const Icon(Icons.local_fire_department, size: 13, color: Brand.orange),
        const SizedBox(width: 2),
        Text('${compactCount(saleCount)} sold', style: style),
      ],
      if (saleCount > 0 && rating != null) const SizedBox(width: 8),
      if (rating != null) ...[
        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
        const SizedBox(width: 1),
        Text(ratingLabel(rating!), style: style),
      ],
    ]);
  }
}

/// The website's product card (components/product-card): square photo with
/// the campaign and Factory badges, the orange price with sold and rating
/// beside it, and a two-line title.
class WebProductCard extends StatelessWidget {
  const WebProductCard({super.key, required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final badge = p.isSuperFactory ? 'Super Factory' : (p.isFactory ? 'Factory' : null);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 0.6,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        onTap: () => context.push('/product/${p.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(p.imageUrl, radius: 0),
              if (p.campaignLabel != null)
                Positioned(left: 8, top: 8, child: _Badge(p.campaignLabel!, filled: true)),
              if (badge != null) Positioned(right: 8, top: 8, child: _Badge(badge)),
            ]),
          ),
          // The text block takes what the grid row leaves: when price and
          // metrics wrap onto two lines (narrow cards, large text settings)
          // the title gives way and ellipsizes instead of overflowing.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _Price(product: p),
                    ProductMetrics(saleCount: p.saleCount, rating: p.rating),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.3, color: Color(0xFF1F2937))),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p.onPricingHold) {
      return const Text('Price under review', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Brand.grayText));
    }
    final from = p.priceFrom ? 'from ' : '';
    const big = TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Brand.orange, letterSpacing: -0.3);
    if (p.campaignPrice != null) {
      return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(Money.bdt(p.campaignPrice), style: big),
        const SizedBox(width: 4),
        Text('$from${Money.bdt(p.unitPrice)}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
      ]);
    }
    return Text('$from${Money.bdt(p.unitPrice)}', style: big);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.filled = false});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? Brand.blue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: filled ? Colors.white : Brand.blue)),
      );
}

/// Two-column grid of web product cards, sized like the website's
/// (`grid-cols-2 gap-3`), as a sliver.
class ProductCardGrid extends StatelessWidget {
  const ProductCardGrid({super.key, required this.products});
  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(builder: (context, constraints) {
        // Two columns on phones, three on wide screens; each card is its
        // square photo plus the price/metrics/title block beneath it.
        final width = constraints.crossAxisExtent;
        final columns = width >= 600 ? 3 : 2;
        final card = (width - 12 * (columns - 1)) / columns;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: card + 122 * textScale,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => WebProductCard(product: products[i]),
        );
      });
}
