import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../screens/order_screens.dart' show openExternal;
import 'common.dart';

/// A product's own video (1688 serves a plain MP4), played in the gallery
/// where the website's `<video>` plays it: tap to pause or resume, drag the
/// bar to seek. Plays as soon as it is ready, since opening it was the tap.
class ProductVideo extends StatefulWidget {
  const ProductVideo({super.key, required this.url, this.poster});
  final String url;
  final String? poster;

  @override
  State<ProductVideo> createState() => _ProductVideoState();
}

class _ProductVideoState extends State<ProductVideo> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_changed);
    _video.initialize().then((_) {
      if (mounted) _video.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _video.value.hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This video could not be played here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
          TextButton(onPressed: () => openExternal(context, widget.url), child: const Text('Open it in the browser')),
        ]),
      );
    }

    final v = _video.value;
    if (!v.isInitialized) {
      return Stack(fit: StackFit.expand, children: [
        NetImage(widget.poster, fit: BoxFit.contain, radius: 10),
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      ]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Colors.black,
        child: GestureDetector(
          onTap: () => v.isPlaying ? _video.pause() : _video.play(),
          child: Stack(children: [
            Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_video))),
            if (!v.isPlaying)
              const Center(
                child: CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.play_arrow_rounded, size: 40, color: Brand.ink)),
              ),
            if (v.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _video,
                allowScrubbing: true,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                colors: const VideoProgressColors(playedColor: Brand.orange, bufferedColor: Colors.white54, backgroundColor: Colors.white24),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Plays a gallery video (YouTube, Facebook, stream) in the app. Falls back
/// to the website's watch page only when the video has no embed.
void openVideo(BuildContext context, HomeVideo video) {
  if (video.embedUrl == null) {
    openExternal(context, video.url);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)));
}

class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({super.key, required this.video});
  final HomeVideo video;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            // The admin's shape: reels are 9:16, everything else 16:9. The
            // frame is as large as the screen allows at that shape.
            final aspect = video.aspectRatio ?? 16 / 9;
            var width = box.maxWidth;
            var height = width / aspect;
            if (height > box.maxHeight - 80) {
              height = box.maxHeight - 80;
              width = height * aspect;
            }
            return Column(children: [
              Expanded(
                child: Center(
                  child: SizedBox(width: width, height: height, child: EmbedPlayer(embedUrl: video.embedUrl!, width: width)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, height: 1.3)),
                  if (video.date != null) Text(video.date!, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ]),
              ),
            ]);
          }),
        ),
      );
}

/// A provider's player iframe in a WebView.
///
/// The page is loaded with the website as its origin: YouTube refuses to
/// play an embed that has no referrer, and Facebook's plugin wants a real
/// site too. Playback is allowed without a second gesture -- inside an app
/// that is a setting, not a browser policy -- so the tap that opened this
/// screen starts the video WITH sound (the website had to learn that
/// autoplay in a browser always starts muted). Links out of the player
/// (the YouTube logo, "watch on Facebook") open in the browser rather than
/// replacing the player.
class EmbedPlayer extends StatefulWidget {
  const EmbedPlayer({super.key, required this.embedUrl, required this.width});
  final String embedUrl;
  final double width;

  @override
  State<EmbedPlayer> createState() => _EmbedPlayerState();
}

class _EmbedPlayerState extends State<EmbedPlayer> {
  late final WebViewController _web;

  String get _src {
    final uri = Uri.parse(widget.embedUrl);
    // Facebook's plugin draws a 500px player unless told the width.
    if (uri.host.contains('facebook.com')) {
      return uri.replace(queryParameters: {...uri.queryParameters, 'width': '${widget.width.round()}'}).toString();
    }
    return widget.embedUrl;
  }

  @override
  void initState() {
    super.initState();
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{})
        : const PlatformWebViewControllerCreationParams();
    _web = WebViewController.fromPlatformCreationParams(params);
    final platform = _web.platform;
    if (platform is AndroidWebViewController) platform.setMediaPlaybackRequiresUserGesture(false);

    final src = const HtmlEscape().convert(_src);
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame || request.url.startsWith(AppConfig.siteBase) || request.url == 'about:blank') {
            return NavigationDecision.navigate;
          }
          openExternal(context, request.url);
          return NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(
        '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}'
        'iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style></head>'
        '<body><iframe src="$src" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>',
        baseUrl: '${AppConfig.siteBase}/',
      );
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
