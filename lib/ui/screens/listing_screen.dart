import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/footer.dart';
import '../widgets/product_grid.dart';
import '../widgets/site.dart';
import '../widgets/tab_bar.dart';

final categoryInfoProvider = FutureProvider.autoDispose.family<CategoryInfo, int>((ref, id) => ref.read(apiProvider).category(id));
final highlightsProvider = FutureProvider.autoDispose.family<List<Highlight>, int?>((ref, id) => ref.read(apiProvider).highlights(category: id));

const _sorts = {'': 'Most popular', 'newest': 'Newest', 'price_asc': 'Price: low to high', 'price_desc': 'Price: high to low'};

/// The website's category page (and, without a category, its Shop page):
/// header card with sort and filters, subcategory chips, the Recommended
/// rail, then the product grid.
class ListingScreen extends ConsumerStatefulWidget {
  const ListingScreen({super.key, this.categoryId, this.query});
  final int? categoryId;
  final String? query;

  @override
  ConsumerState<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends ConsumerState<ListingScreen> {
  late ListingQuery _listing = ListingQuery(category: widget.categoryId, query: widget.query);

  @override
  Widget build(BuildContext context) {
    final id = widget.categoryId;
    final info = id == null ? null : ref.watch(categoryInfoProvider(id)).value;
    final title = id == null ? (widget.query != null ? '“${widget.query}”' : 'All products') : (info?.name ?? '');

    return Scaffold(
      appBar: const SiteHeader(),
      // Opened over the tabs (a category, a search): the website keeps its
      // tab bar on these pages, with Shop lit. The Shop tab itself is in the
      // tab shell and already has one.
      bottomNavigationBar: id != null || widget.query != null ? const PageTabBar() : null,
      body: ProductGrid(
        listing: _listing,
        // The website's catalogue pages end in its footer too.
        footer: const SiteFooter(),
        onRefresh: () async {
          if (id != null) ref.invalidate(categoryInfoProvider(id));
          ref.invalidate(highlightsProvider(id));
        },
        headers: [
          SliverToBoxAdapter(
            child: WebCard(
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
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      if (info?.parentName != null)
                        TextSpan(
                          text: '${info!.parentName} › ',
                          style: const TextStyle(color: Brand.grayText, fontWeight: FontWeight.w600),
                        ),
                      TextSpan(text: title),
                      if (info != null)
                        TextSpan(
                          text: '  ${NumberFormat('#,##0').format(info.itemCount)} items',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF9CA3AF)),
                        ),
                    ]), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Brand.blue, letterSpacing: -0.3)),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD1D5DB))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _listing.sort ?? '',
                          style: const TextStyle(fontFamily: 'InstrumentSans', fontSize: 16, color: Brand.ink),
                          items: [for (final e in _sorts.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                          onChanged: (v) => setState(() => _listing = ListingQuery(
                                query: _listing.query, category: _listing.category, sort: (v ?? '').isEmpty ? null : v,
                                minPrice: _listing.minPrice, maxPrice: _listing.maxPrice, factoryOnly: _listing.factoryOnly,
                              )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Brand.blue, minimumSize: const Size(120, 44)),
                      onPressed: _filters,
                      icon: Badge(isLabelVisible: _listing.hasFilters, smallSize: 8, child: const Icon(Icons.tune, size: 20)),
                      label: const Text('Filters'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          if (info != null && info.chips.isNotEmpty) SliverToBoxAdapter(child: _Chips(chips: info.chips)),
          if (widget.query == null) SliverToBoxAdapter(child: _Recommended(categoryId: id)),
        ],
      ),
    );
  }

  Future<void> _filters() async {
    final min = TextEditingController(text: _listing.minPrice ?? '');
    final max = TextEditingController(text: _listing.maxPrice ?? '');
    var factory = _listing.factoryOnly;
    final result = await showModalBottomSheet<ListingQuery>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Filters', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const Text('Price (৳ per piece)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Min'))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–')),
              Expanded(child: TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Max'))),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: factory,
              onChanged: (v) => setSheet(() => factory = v),
              title: const Text('Factory suppliers only'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, _listing.copyWith(factoryOnly: false, clearPrices: true)),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.blue),
                  onPressed: () => Navigator.pop(ctx, ListingQuery(
                    query: _listing.query, category: _listing.category, sort: _listing.sort,
                    minPrice: min.text.trim().isEmpty ? null : min.text.trim(),
                    maxPrice: max.text.trim().isEmpty ? null : max.text.trim(),
                    factoryOnly: factory,
                  )),
                  child: const Text('Apply'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (result != null) setState(() => _listing = result);
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.chips});
  final List<(int, String, bool)> chips;

  @override
  Widget build(BuildContext context) => WebCard(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (id, name, active) = chips[i];
              return Material(
                color: active ? Brand.blue : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: active ? null : () => context.pushReplacement('/category/$id'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text(name, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? Colors.white : const Color(0xFF374151))),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// The website's "Recommended" rail: badge cards from App\Support\Highlights.
class _Recommended extends ConsumerStatefulWidget {
  const _Recommended({required this.categoryId});
  final int? categoryId;

  @override
  ConsumerState<_Recommended> createState() => _RecommendedState();
}

class _RecommendedState extends ConsumerState<_Recommended> {
  final _scroll = ScrollController();

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo((_scroll.offset + direction * 312).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _hex(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(highlightsProvider(widget.categoryId)).value ?? const <Highlight>[];
    // The website hides the rail below two cards.
    if (cards.length < 2) return const SizedBox.shrink();
    return WebCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Brand.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_outlined, color: Brand.blue, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Recommended', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          _CircleArrow(icon: Icons.chevron_left, onTap: () => _page(-1)),
          const SizedBox(width: 8),
          _CircleArrow(icon: Icons.chevron_right, onTap: () => _page(1)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = cards[i];
              final p = c.product;
              return SizedBox(
                width: 300,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/product/${p.id}', extra: p),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: _hex(c.background), borderRadius: BorderRadius.circular(20)),
                          child: Text(c.label, style: TextStyle(color: _hex(c.foreground), fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 76, height: 76, child: NetImage(p.imageUrl, radius: 8)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(p.onPricingHold ? 'Price under review' : '${p.priceFrom ? 'from ' : ''}${Money.bdt(p.unitPrice)}',
                                      style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w800, fontSize: 16)),
                                  const Spacer(),
                                  if (p.rating != null) ...[
                                    const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                                    Text(ratingLabel(p.rating!), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Brand.grayText)),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.25)),
                                const Spacer(),
                                if (p.saleCount > 0) ProductMetrics(saleCount: p.saleCount),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _CircleArrow extends StatelessWidget {
  const _CircleArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Icon(icon, size: 20, color: const Color(0xFF4B5563)),
        ),
      );
}
