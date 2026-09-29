import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../state/wishlist.dart';

/// The website's phone tab bar: white, hairline top, the active tab orange
/// with a short orange dash above it. The website shows it on every page but
/// the product page, so pages opened over the tabs (a category, search
/// results, videos) carry it too -- see [PageTabBar].
class SiteTabBar extends ConsumerWidget {
  const SiteTabBar({super.key, required this.current, required this.onTap});

  /// The highlighted tab, or null for none.
  final int? current;
  final ValueChanged<int> onTap;

  static const tabs = [
    (Icons.home_outlined, 'Home', '/'),
    (Icons.menu, 'Categories', '/categories'),
    (Icons.shopping_cart_outlined, 'Cart', '/cart'),
    (Icons.favorite_border, 'Wishlist', '/wishlist'),
    (Icons.storefront_outlined, 'Shop', '/shop'),
    (Icons.person_outline, 'Account', '/account'),
  ];

  /// The website's highlight for a category page or search results: Shop
  /// (its tab lights up for every catalog.* route).
  static const shop = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final saved = ref.watch(wishlistProvider).length;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (final (i, (icon, label, _)) in tabs.indexed)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                    if (i == current)
                      Positioned(top: -9, child: Container(width: 32, height: 2.5, decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(2)))),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Badge(
                        isLabelVisible: (i == 2 && cartCount > 0) || (i == 3 && saved > 0),
                        backgroundColor: Brand.orange,
                        label: Text('${i == 2 ? cartCount : saved}'),
                        child: Icon(icon, size: 24, color: i == current ? Brand.orange : const Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 2),
                      Text(label,
                          maxLines: 1,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: i == current ? Brand.orange : const Color(0xFF4B5563))),
                    ]),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// The tab bar on a page pushed over the tabs: a tap goes to that tab,
/// leaving this page, as a tap on the website's bar loads that page.
class PageTabBar extends StatelessWidget {
  const PageTabBar({super.key, this.current = SiteTabBar.shop});
  final int? current;

  @override
  Widget build(BuildContext context) => SiteTabBar(
        current: current,
        onTap: (i) => context.go(SiteTabBar.tabs[i].$3),
      );
}
