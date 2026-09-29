import 'package:easybuy/core/api_client.dart';
import 'package:easybuy/data/api.dart';
import 'package:easybuy/data/models.dart';
import 'package:easybuy/state/providers.dart';
import 'package:easybuy/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'client_test.dart' show MemorySession;

/// The API with canned answers, so screens can be driven without a server.
class FakeApi extends EasyBuyApi {
  FakeApi() : super(ApiClient(MemorySession()));

  static final _products = [
    ProductCard(id: 1, title: 'Stainless steel water bottle', unitPrice: '350', minQuantity: 2, isFactory: true, isSoldOut: false, saleCount: 23000, rating: '4.5'),
    ProductCard(id: 2, title: 'Kids rain boots', unitPrice: '410.50', minQuantity: 3, isFactory: false, isSoldOut: false, saleCount: 0, priceFrom: true),
  ];

  @override
  Future<Paged<ProductCard>> products({String? query, int? category, String? sort, String? cursor, String? minPrice, String? maxPrice, bool factoryOnly = false}) async =>
      Paged(_products, null);

  @override
  Future<HomeData> home() async => HomeData(
        banners: const [],
        categories: [Category(id: 1, name: 'Home and Kitchen')],
        videos: const [],
        videosHeading: const {},
        featured: HomeSection(title: 'Popular right now', products: _products),
        sections: [HomeSection(title: 'Winter Cloths', categoryId: 1, products: _products.take(1).toList())],
        posts: const [],
        postsHeading: const {},
      );

  @override
  Future<List<Category>> categories() async => [
        Category(id: 1, name: 'Home and Kitchen', children: [Category(id: 11, name: 'Cookware')]),
        Category(id: 2, name: 'Bags'),
      ];

  @override
  Future<List<Highlight>> highlights({int? category}) async => const [];

  @override
  Future<Cart> cart({bool visit = false}) async => Cart.empty();
}

Widget app() => ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(MemorySession()),
        apiProvider.overrideWithValue(FakeApi()),
      ],
      child: const EasyBuyApp(),
    );

void main() {
  testWidgets('home shows the website sections: tiles, Popular right now, admin strips', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Discover a wide selection tailored just for you!'), findsOneWidget);
    expect(find.text('Home and Kitchen'), findsOneWidget);
    expect(find.text('Popular right now'), findsOneWidget);
    expect(find.text('৳350'), findsWidgets);
    expect(find.text('23k sold'), findsWidgets);
    // Options priced differently read "from".
    expect(find.text('from ৳411'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Winter Cloths'),
      400,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('Winter Cloths'), findsOneWidget);
  });

  testWidgets('the tab bar is the website\'s: Home, Categories, Cart, Wishlist, Shop, Account', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    for (final label in ['Home', 'Categories', 'Cart', 'Wishlist', 'Shop', 'Account']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('categories open as the two-pane browser', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();

    expect(find.text('All Home and Kitchen'), findsOneWidget);
    expect(find.text('Cookware'), findsOneWidget);
    await tester.tap(find.text('Bags'));
    await tester.pumpAndSettle();
    expect(find.text('All Bags'), findsOneWidget);
  });

  testWidgets('an empty cart invites the customer to shop', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart').last);
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('a guest on the Account tab is asked to sign in, not thrown out', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account').last);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to EasyBuy'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
