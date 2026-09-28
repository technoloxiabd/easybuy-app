import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';
import '../widgets/video.dart';
import 'order_screens.dart' show openExternal;

final homeProvider = FutureProvider<HomeData>((ref) => ref.read(apiProvider).home());

/// Where a link on the homepage goes: an app screen when it names one.
void openLink(BuildContext context, LinkTarget? link) {
  if (link == null) return;
  switch (link.type) {
    case 'product' when link.id != null:
      context.push('/product/${link.id}');
    case 'category' when link.id != null:
      context.push('/category/${link.id}');
    case 'shop':
      context.go('/shop');
    default:
      if (link.url.isNotEmpty) openExternal(context, link.url);
  }
}

/// The website's homepage, band for band (catalog/home.blade.php).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeProvider);
    return Scaffold(
      appBar: const SiteHeader(),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider)),
        data: (home) => RefreshIndicator(
          onRefresh: () => ref.refresh(homeProvider.future),
          child: CustomScrollView(slivers: [
            if (home.banners.isNotEmpty) SliverToBoxAdapter(child: _BannerSlider(banners: home.banners)),
            if (home.categories.isNotEmpty) SliverToBoxAdapter(child: _CategoryCard(categories: home.categories)),
            if (home.videos.isNotEmpty) SliverToBoxAdapter(child: _VideoBand(videos: home.videos, heading: home.videosHeading)),
            _ProductBand(title: home.featured.title, products: home.featured.products, color: Brand.bandLight, onViewAll: () => context.go('/shop')),
            for (final (i, s) in home.sections.indexed)
              _ProductBand(
                title: s.title,
                products: s.products,
                // After the white "Popular right now": odd strips tinted.
                color: i.isEven ? Brand.bandTint : Brand.bandLight,
                onViewAll: s.categoryId == null ? null : () => context.push('/category/${s.categoryId}'),
              ),
            if (home.posts.isNotEmpty) SliverToBoxAdapter(child: _BlogBand(posts: home.posts, heading: home.postsHeading)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ banners

class _BannerSlider extends StatefulWidget {
  const _BannerSlider({required this.banners});
  final List<HomeBanner> banners;

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  final _pages = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_pages.hasClients) return;
        final next = (_index + 1) % widget.banners.length;
        _pages.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        // The website's phone artwork is 1.6:1.
        aspectRatio: 1.6,
        child: Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => openLink(context, widget.banners[i].link),
              child: NetImage(widget.banners[i].imageUrl, radius: 0),
            ),
          ),
          if (widget.banners.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < widget.banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 24 : 12,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == _index ? 1 : 0.6),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                    ),
                  ),
              ]),
            ),
        ]),
      );
}

// ------------------------------------------------------------------ categories

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.categories});
  final List<Category> categories;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  final _scroll = ScrollController();

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * _scroll.position.viewportDimension * 0.8).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Two rows that page sideways, filled column by column -- the website's
    // grid-auto-flow: column -- so each tile sits where it does on the site.
    final rows = <List<Category>>[[], []];
    for (final (i, c) in widget.categories.indexed) {
      rows[i % 2].add(c);
    }
    return WebCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Expanded(
            child: KickerHeader(title: 'Discover a wide selection tailored just for you!', subtitle: 'Find what you need, faster', large: true),
          ),
          const SizedBox(width: 8),
          _ArrowButton(icon: Icons.chevron_left, onTap: () => _page(-1)),
          const SizedBox(width: 8),
          _ArrowButton(icon: Icons.chevron_right, onTap: () => _page(1)),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: Column(children: [
            for (final row in rows.where((r) => r.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [for (final c in row) Padding(padding: const EdgeInsets.only(right: 12), child: _CategoryTile(category: c))]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 36, height: 36, child: Icon(icon, color: const Color(0xFF374151))),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) => Material(
        color: Brand.tile,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/category/${category.id}'),
          child: Container(
            width: 128,
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              AspectRatio(aspectRatio: 1, child: NetImage(category.imageUrl, radius: 8)),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: Center(
                  child: Text(category.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2, color: Color(0xFF1F2937))),
                ),
              ),
            ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------ videos

class _VideoBand extends StatelessWidget {
  const _VideoBand({required this.videos, required this.heading});
  final List<HomeVideo> videos;
  final Map<String, dynamic> heading;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        padding: const EdgeInsets.fromLTRB(18, 20, 0, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B5B86), Color(0xFF15212E)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: KickerHeader(
              title: '${heading['title'] ?? 'See how importing works'}',
              subtitle: heading['subtitle'] == null ? null : '${heading['subtitle']}',
              light: true,
              onViewAll: () => context.push('/videos'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            // Poster (16:9 of the card width) plus a two-line title and date.
            height: MediaQuery.of(context).size.width * 0.66 * 9 / 16 + 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 18),
              itemCount: videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final v = videos[i];
                final width = MediaQuery.of(context).size.width * 0.66;
                return GestureDetector(
                  onTap: () => openVideo(context, v),
                  child: SizedBox(
                    width: width,
                    child: Column(children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(fit: StackFit.expand, children: [
                          NetImage(v.posterUrl, radius: 14),
                          Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(color: Brand.orange, shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                            ),
                          ),
                          if (v.duration != null)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                child: Text(v.duration!, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.25)),
                      if (v.date != null) Text(v.date!, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ product bands

class _ProductBand extends StatelessWidget {
  const _ProductBand({required this.title, required this.products, required this.color, this.onViewAll});
  final String title;
  final List<ProductCard> products;
  final Color color;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return DecoratedSliver(
      decoration: BoxDecoration(color: color),
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        sliver: SliverMainAxisGroup(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 14), child: KickerHeader(title: title, onViewAll: onViewAll))),
          ProductCardGrid(products: products),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ blog

class _BlogBand extends StatelessWidget {
  const _BlogBand({required this.posts, required this.heading});
  final List<HomePost> posts;
  final Map<String, dynamic> heading;

  @override
  Widget build(BuildContext context) => Container(
        color: Brand.bandLight,
        padding: const EdgeInsets.fromLTRB(16, 20, 0, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (heading['kicker'] != null)
                Text('${heading['kicker']}'.toUpperCase(),
                    style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              KickerHeader(
                title: '${heading['title'] ?? 'Learn before you buy'}',
                subtitle: heading['subtitle'] == null ? null : '${heading['subtitle']}',
                onViewAll: () => context.push('/videos'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = posts[i];
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.72,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => openExternal(context, p.url),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(aspectRatio: 16 / 9, child: NetImage(p.coverUrl, radius: 0)),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (p.category != null)
                              Text(p.category!.toUpperCase(), style: const TextStyle(color: Brand.orange, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
                            const SizedBox(height: 4),
                            Text([p.read, p.date].whereType<String>().join(' · '), style: const TextStyle(color: Brand.grayText, fontSize: 12)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}
