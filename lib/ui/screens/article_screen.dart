import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';
import 'order_screens.dart' show openExternal;

/// Where a website link lives in the app, or null when it has no screen
/// here. Articles and the blog list open in [ArticleScreen]; a product or
/// category link from inside an article opens that screen, as it would on
/// the website.
String? appRouteFor(String url) {
  final uri = Uri.tryParse(url);
  final site = Uri.parse(AppConfig.siteBase);
  if (uri == null || (uri.host.isNotEmpty && uri.host != site.host)) return null;
  final path = uri.path;
  if (path == '/blog' || path.startsWith('/blog/')) return '/blog?url=${Uri.encodeComponent(site.resolveUri(uri).toString())}';
  // /products/<slug>-<id> and /category/<slug>-<id>: the id ends the path.
  final id = RegExp(r'-(\d+)$').firstMatch(path)?.group(1) ?? RegExp(r'/(\d+)$').firstMatch(path)?.group(1);
  if (path.startsWith('/products/') && id != null) return '/product/$id';
  if (path.startsWith('/p/') && id != null) return '/product/$id';
  if (path.startsWith('/category/') && id != null) return '/category/$id';
  if (path == '/products') {
    final q = uri.queryParameters['q'];
    return q == null || q.isEmpty ? '/shop' : '/search/results?q=${Uri.encodeComponent(q)}';
  }
  return null;
}

/// Opens a website link in the app when it has a screen here, else in the
/// browser.
void openSiteLink(BuildContext context, String url) {
  final route = appRouteFor(url);
  if (route == null) {
    openExternal(context, url);
  } else if (route == '/shop') {
    context.go(route);
  } else {
    context.push(route);
  }
}

/// A blog article, or the blog list, in the app (owner, 29 Sep 2026: they
/// opened in the browser). It is the website's own page, asked for with
/// ?in_app=1 so it comes without the site's header, footer and tab bar --
/// the app has its own. Moving between articles stays here; a product or
/// category link opens that screen; anything else goes to the browser.
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.url});
  final String url;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final WebViewController _web;
  bool _loading = true;
  Object? _error;
  String _title = '';

  static bool _isBlog(Uri uri) => uri.host == Uri.parse(AppConfig.siteBase).host && (uri.path == '/blog' || uri.path.startsWith('/blog/'));

  static Uri _inApp(Uri uri) => uri.replace(queryParameters: {...uri.queryParameters, 'in_app': '1'});

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F4F6))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) async {
          final title = await _web.getTitle();
          if (!mounted) return;
          setState(() {
            _loading = false;
            // "How importing works — EasyBuy": the article's own part.
            _title = (title ?? '').split(' — ').first;
          });
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _error = e.description);
        },
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          final uri = Uri.parse(request.url);
          if (_isBlog(uri)) {
            if (uri.queryParameters['in_app'] == '1') return NavigationDecision.navigate;
            _web.loadRequest(_inApp(uri));
            return NavigationDecision.prevent;
          }
          openSiteLink(context, request.url);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(_inApp(Uri.parse(widget.url)));
  }

  Future<void> _retry() async {
    setState(() => _error = null);
    await _web.reload();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // Back steps through the articles read here before leaving.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _web.canGoBack()) {
            await _web.goBack();
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(title: Text(_title.isEmpty ? 'Guides' : _title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: _error != null
              ? ErrorView(error: _error!, onRetry: _retry)
              : Stack(children: [
                  WebViewWidget(controller: _web),
                  if (_loading) const LinearProgressIndicator(minHeight: 2, color: Brand.orange, backgroundColor: Colors.transparent),
                ]),
        ),
      );
}
