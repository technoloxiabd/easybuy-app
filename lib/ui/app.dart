import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/push.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'screens/account_screens.dart';
import 'screens/article_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/cart_screen.dart';
import 'screens/catalog_screens.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';
import 'screens/image_search_screen.dart';
import 'screens/listing_screen.dart';
import 'screens/product_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_screens.dart';
import 'screens/pay_screen.dart';
import 'screens/support_screens.dart';
import 'screens/videos_screen.dart';
import 'widgets/chat_fab.dart';
import 'widgets/tab_bar.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Screens a guest cannot open; they are sent to sign in and brought back.
/// The Orders and Account TABS stay open and invite a guest to sign in;
/// only the screens under them are guarded (hence the trailing slashes).
const _needsAccount = ['/checkout', '/orders/', '/account/', '/support', '/chat', '/verify-phone'];

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.value != null;
      final path = state.uri.path;
      if (!signedIn && _needsAccount.any(path.startsWith)) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        // The website's phone tab bar: Home, Categories, Cart, Wishlist, Shop, Account.
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/shop', builder: (_, _) => const ListingScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())]),
        ],
      ),
      GoRoute(path: '/search', parentNavigatorKey: _rootKey, builder: (_, s) => SearchScreen(initial: s.uri.queryParameters['q'])),
      // Search results: the Shop listing for the query, as the website's.
      GoRoute(path: '/search/results', parentNavigatorKey: _rootKey, builder: (_, s) => ListingScreen(query: s.uri.queryParameters['q'])),
      GoRoute(path: '/search/image', parentNavigatorKey: _rootKey, builder: (_, s) => ImageSearchScreen(path: s.extra as String?)),
      GoRoute(path: '/videos', parentNavigatorKey: _rootKey, builder: (_, _) => const VideosScreen()),
      // An article or the blog list, from its website URL.
      GoRoute(path: '/blog', parentNavigatorKey: _rootKey, builder: (_, s) => ArticleScreen(url: s.uri.queryParameters['url'] ?? '${AppConfig.siteBase}/blog')),
      GoRoute(path: '/category/:id', parentNavigatorKey: _rootKey, builder: (_, s) => ListingScreen(categoryId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/product/:id', parentNavigatorKey: _rootKey, builder: (_, s) => ProductScreen(id: int.parse(s.pathParameters['id']!), preview: s.extra is ProductCard ? s.extra as ProductCard : null)),
      GoRoute(path: '/orders', parentNavigatorKey: _rootKey, builder: (_, _) => const OrdersScreen()),
      GoRoute(path: '/checkout', parentNavigatorKey: _rootKey, builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: '/orders/:number', parentNavigatorKey: _rootKey, builder: (_, s) => OrderScreen(number: s.pathParameters['number']!)),
      GoRoute(
        path: '/orders/:number/pay',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => PayScreen(number: s.pathParameters['number']!, stage: s.uri.queryParameters['stage']),
      ),
      GoRoute(path: '/login', parentNavigatorKey: _rootKey, builder: (_, s) => LoginScreen(from: s.uri.queryParameters['from'])),
      GoRoute(path: '/register', parentNavigatorKey: _rootKey, builder: (_, s) => RegisterScreen(from: s.uri.queryParameters['from'])),
      GoRoute(path: '/forgot', parentNavigatorKey: _rootKey, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-phone', parentNavigatorKey: _rootKey, builder: (_, s) => VerifyPhoneScreen(from: s.uri.queryParameters['from'])),
      GoRoute(path: '/account/profile', parentNavigatorKey: _rootKey, builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/account/password', parentNavigatorKey: _rootKey, builder: (_, _) => const PasswordScreen()),
      GoRoute(path: '/account/addresses', parentNavigatorKey: _rootKey, builder: (_, _) => const AddressesScreen()),
      GoRoute(path: '/account/payments', parentNavigatorKey: _rootKey, builder: (_, _) => const PaymentHistoryScreen()),
      GoRoute(path: '/account/credit', parentNavigatorKey: _rootKey, builder: (_, _) => const CreditScreen()),
      GoRoute(path: '/support', parentNavigatorKey: _rootKey, builder: (_, _) => const ComplaintsScreen()),
      GoRoute(path: '/support/new', parentNavigatorKey: _rootKey, builder: (_, s) => NewComplaintScreen(orderNumber: s.uri.queryParameters['order'])),
      GoRoute(path: '/support/:number', parentNavigatorKey: _rootKey, builder: (_, s) => ComplaintScreen(number: s.pathParameters['number']!)),
      GoRoute(
        path: '/chat',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ChatScreen(orderNumber: s.uri.queryParameters['order'], productId: int.tryParse(s.uri.queryParameters['product'] ?? '')),
      ),
    ],
  );

  // Re-run the redirect when the customer signs in or out.
  ref.listen(authProvider, (_, _) => router.refresh());

  // Arriving on the cart -- its tab, "View cart", or back from checkout --
  // is a visit, as loading the website's cart page is: the delivery method
  // is asked again when the shop wants it chosen every time.
  var lastPath = '';
  router.routerDelegate.addListener(() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == '/cart' && lastPath != '/cart') ref.read(cartProvider.notifier).visit().ignore();
    lastPath = path;
  });
  return router;
});

final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Where tapping a push goes, from its `data`.
String? pushRoute(Map<String, dynamic> data) => switch (data['type']) {
      'order' when data['order_number'] != null => '/orders/${data['order_number']}',
      'complaint' when data['complaint_number'] != null => '/support/${data['complaint_number']}',
      'chat' => '/chat',
      // An admin broadcast (Marketing › App push): its link, when the app
      // has a screen for it; one without a link just opens the app.
      'link' when data['url'] != null => appRouteFor('${data['url']}'),
      _ => null,
    };

class EasyBuyApp extends ConsumerStatefulWidget {
  const EasyBuyApp({super.key});

  @override
  ConsumerState<EasyBuyApp> createState() => _EasyBuyAppState();
}

class _EasyBuyAppState extends ConsumerState<EasyBuyApp> {
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    final push = PushService.instance;
    _subs.add(push.taps.listen((data) {
      final route = pushRoute(data);
      if (route == '/shop') {
        ref.read(routerProvider).go(route!);
      } else if (route != null) {
        ref.read(routerProvider).push(route);
      } else if (data['type'] == 'link' && data['url'] != null) {
        // A page the app has no screen for: the browser.
        launchUrl(Uri.parse('${data['url']}'), mode: LaunchMode.externalApplication).ignore();
      }
    }));
    // Open app: PushService puts it in the notification bar; bring the
    // Messages count up to date at once.
    _subs.add(push.foreground.listen((_) => ref.invalidate(unreadMessagesProvider)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'EasyBuy',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scaffoldMessengerKey: messengerKey,
        routerConfig: ref.watch(routerProvider),
        // The floating chat button rides over every screen.
        builder: (context, child) => Stack(children: [child!, const ChatFab()]),
      );
}

/// The tab shell. Android's back (button or edge swipe) steps back through
/// the tabs visited, then on Home asks for a second back before leaving
/// (owner, 30 Sep 2026: back on any tab but Home closed the app). Pages
/// pushed over the tabs still pop as before: this PopScope is only asked
/// when the shell itself is the top route.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Tabs visited, each once, the current one last.
  late final _visited = [widget.shell.currentIndex];
  DateTime? _exitAskedAt;

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    // Every way onto a tab lands here: the bar, a button's context.go, a
    // page's tab bar.
    final i = widget.shell.currentIndex;
    if (_visited.last != i) {
      _visited
        ..remove(i)
        ..add(i);
    }
  }

  void _back() {
    final shell = widget.shell;
    if (_visited.length > 1 || shell.currentIndex != 0) {
      _visited.removeLast();
      if (_visited.isEmpty) _visited.add(0);
      shell.goBranch(_visited.last);
      return;
    }
    final now = DateTime.now();
    if (_exitAskedAt != null && now.difference(_exitAskedAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _exitAskedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Press back again to exit'), backgroundColor: Brand.ink, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          body: widget.shell,
          bottomNavigationBar: SiteTabBar(
            current: widget.shell.currentIndex,
            onTap: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
          ),
        ),
      );
}
