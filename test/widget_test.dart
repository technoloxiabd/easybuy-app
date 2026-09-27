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

  @override
  Future<Paged<ProductCard>> products({String? query, int? category, String? sort, String? cursor}) async => Paged([
        ProductCard(id: 1, title: 'Stainless steel water bottle', unitPrice: '350', minQuantity: 2, isFactory: true, isSoldOut: false, saleCount: 120),
        ProductCard(id: 2, title: 'Kids rain boots', unitPrice: '410.50', minQuantity: 3, isFactory: false, isSoldOut: false, saleCount: 0),
      ], null);

  @override
  Future<List<Category>> categories() async => [Category(id: 1, name: 'Home and Kitchen')];

  @override
  Future<Cart> cart() async => Cart.empty();
}

Widget app() => ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(MemorySession()),
        apiProvider.overrideWithValue(FakeApi()),
      ],
      child: const EasyBuyApp(),
    );

void main() {
  testWidgets('home shows the product feed and the categories strip', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Stainless steel water bottle'), findsOneWidget);
    expect(find.text('৳350'), findsOneWidget);
    expect(find.text('৳410.50'), findsOneWidget);
    expect(find.text('Home and Kitchen'), findsOneWidget);
  });

  testWidgets('an empty cart invites the customer to shop', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('a guest on the Orders tab is asked to sign in, not thrown out', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Your orders appear here'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
