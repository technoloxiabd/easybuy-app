import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/push.dart';
import '../core/theme.dart';
import '../state/providers.dart';
import 'screens/account_screens.dart';
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
      GoRoute(path: '/category/:id', parentNavigatorKey: _rootKey, builder: (_, s) => ListingScreen(categoryId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/product/:id', parentNavigatorKey: _rootKey, builder: (_, s) => ProductScreen(id: int.parse(s.pathParameters['id']!))),
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
      if (route != null) ref.read(routerProvider).push(route);
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
      );
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: SiteTabBar(
          current: shell.currentIndex,
          onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      );
}
