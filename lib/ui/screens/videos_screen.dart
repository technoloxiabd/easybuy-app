import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';
import '../widgets/video.dart';

final videosProvider = FutureProvider.autoDispose.family<(List<HomeVideo>, List<String>), String?>(
  (ref, category) => ref.read(apiProvider).videos(category: category),
);

/// The website's video gallery (/videos): category tabs, then every video,
/// each played in the app.
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(videosProvider(_category));
    // Keep the tabs while a category loads.
    final categories = async.value?.$2 ?? ref.read(videosProvider(null)).value?.$2 ?? const <String>[];

    return Scaffold(
      appBar: const SiteHeader(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(videosProvider(_category)),
        child: CustomScrollView(slivers: [
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
                  const Expanded(
                    child: Text('Videos', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Brand.blue, letterSpacing: -0.3)),
                  ),
                ]),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in [null, ...categories])
                      ChoiceChip(
                        label: Text(c ?? 'All'),
                        selected: c == _category,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ]),
                ],
              ]),
            ),
          ),
          ...async.when(
            loading: () => [const SliverFillRemaining(hasScrollBody: false, child: LoadingView())],
            error: (e, _) => [SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: e, onRetry: () => ref.invalidate(videosProvider(_category))))],
            data: (d) => d.$1.isEmpty
                ? [const SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.ondemand_video_outlined, title: 'No videos here yet'))]
                : [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: d.$1.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _VideoCard(video: d.$1[i]),
                      ),
                    ),
                  ],
          ),
        ]),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final HomeVideo video;

  @override
  Widget build(BuildContext context) => WebCard(
        padding: const EdgeInsets.all(10),
        child: InkWell(
          onTap: () => openVideo(context, video),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(video.posterUrl, radius: 12),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: Brand.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                  ),
                ),
                if (video.duration != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(video.duration!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.3)),
                const SizedBox(height: 4),
                Text([video.category, video.date].whereType<String>().join(' · '), style: const TextStyle(color: Brand.grayText, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      );
}
