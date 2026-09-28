import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/wishlist.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.read(apiProvider).categories());

/// The website's phone categories browser: root categories in a left rail,
/// the chosen root's subcategories on the right ("All …" first).
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: const SiteHeader(),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
        data: (roots) {
          if (roots.isEmpty) return const EmptyState(icon: Icons.grid_view, title: 'No categories yet');
          final active = roots.firstWhere((c) => c.id == _active, orElse: () => roots.first);
          return Container(
            color: Colors.white,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                child: const Row(children: [
                  Text('Categories', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Brand.ink)),
                ]),
              ),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    width: 88,
                    color: const Color(0xFFF9FAFB),
                    child: ListView(children: [
                      for (final c in roots)
                        InkWell(
                          onTap: () => setState(() => _active = c.id),
                          child: Container(
                            color: c.id == active.id ? Colors.white : null,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                            child: Stack(clipBehavior: Clip.none, children: [
                              if (c.id == active.id)
                                Positioned(
                                  left: -4,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(width: 4, decoration: const BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.horizontal(right: Radius.circular(4)))),
                                ),
                              Center(
                                child: Column(children: [
                                  SizedBox(width: 28, height: 28, child: NetImage(c.imageUrl, radius: 4)),
                                  const SizedBox(height: 6),
                                  Text(c.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.15,
                                        fontWeight: c.id == active.id ? FontWeight.w700 : FontWeight.w400,
                                        color: c.id == active.id ? Brand.blue : const Color(0xFF4B5563),
                                      )),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                  Expanded(
                    child: ListView(children: [
                      InkWell(
                        onTap: () => context.push('/category/${active.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                          child: Row(children: [
                            Expanded(child: Text('All ${active.name}', style: const TextStyle(color: Brand.blue, fontWeight: FontWeight.w700, fontSize: 15))),
                            const Icon(Icons.chevron_right, color: Brand.blue, size: 20),
                          ]),
                        ),
                      ),
                      for (final child in active.children)
                        InkWell(
                          onTap: () => context.push('/category/${child.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            child: Row(children: [
                              Expanded(child: Text(child.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, color: Color(0xFF1F2937)))),
                              const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// The website's wishlist page: saved products on this phone.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wishlistProvider);
    return Scaffold(
      appBar: const SiteHeader(),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              const Text('Wishlist', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              if (items.isNotEmpty) Text('${items.length} saved', style: const TextStyle(color: Color(0xFF9CA3AF))),
              const Spacer(),
              if (items.isNotEmpty) TextButton(onPressed: () => ref.read(wishlistProvider.notifier).clear(), child: const Text('Clear all')),
            ]),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.favorite_border,
              title: 'Your wishlist is empty.',
              body: 'Tap the heart on a product to save it here.',
              action: FilledButton(onPressed: () => context.go('/shop'), child: const Text('Browse products')),
            ),
          )
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), sliver: ProductCardGrid(products: items)),
      ]),
    );
  }
}
