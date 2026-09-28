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
import 'screens/listing_screen.dart';
import 'screens/product_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_screens.dart';
import 'screens/pay_screen.dart';
import 'screens/support_screens.dart';
import '../state/wishlist.dart';

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
    // In the foreground the system shows no banner; say it in the app.
    _subs.add(push.foreground.listen((m) {
      ref.invalidate(unreadMessagesProvider);
      final route = pushRoute(m.data);
      messengerKey.currentState?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text([m.notification?.title, m.notification?.body].whereType<String>().join(' — ')),
        action: route == null ? null : SnackBarAction(label: 'View', onPressed: () => ref.read(routerProvider).push(route)),
      ));
    }));
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

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.home_outlined, 'Home'),
    (Icons.menu, 'Categories'),
    (Icons.shopping_cart_outlined, 'Cart'),
    (Icons.favorite_border, 'Wishlist'),
    (Icons.storefront_outlined, 'Shop'),
    (Icons.person_outline, 'Account'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final saved = ref.watch(wishlistProvider).length;
    return Scaffold(
      body: shell,
      // The website's bottom bar: white, hairline top, the active tab orange
      // with a short orange dash above it.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (final (i, (icon, label)) in _tabs.indexed)
              Expanded(
                child: InkWell(
                  onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                      if (i == shell.currentIndex)
                        Positioned(top: -9, child: Container(width: 32, height: 2.5, decoration: BoxDecoration(color: Brand.orange, borderRadius: BorderRadius.circular(2)))),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Badge(
                          isLabelVisible: (i == 2 && cartCount > 0) || (i == 3 && saved > 0),
                          backgroundColor: Brand.orange,
                          label: Text('${i == 2 ? cartCount : saved}'),
                          child: Icon(icon, size: 24, color: i == shell.currentIndex ? Brand.orange : const Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 2),
                        Text(label,
                            maxLines: 1,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: i == shell.currentIndex ? Brand.orange : const Color(0xFF4B5563))),
                      ]),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
