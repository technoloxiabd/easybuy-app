@Tags(['live'])
library;

import 'package:easybuy/core/api_client.dart';
import 'package:easybuy/data/api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'client_test.dart' show MemorySession;

/// Read-only calls to the REAL public API, to prove the models parse what
/// the server actually sends. Not part of the normal run:
///   flutter test --tags live
void main() {
  final api = EasyBuyApi(ApiClient(MemorySession()));

  test('categories, a product page and a product detail parse', () async {
    final categories = await api.categories();
    expect(categories, isNotEmpty);

    final page = await api.products();
    expect(page.items, isNotEmpty);
    expect(page.items.first.title, isNotEmpty);
    expect(double.tryParse(page.items.first.unitPrice), isNotNull);

    final detail = await api.product(page.items.first.id);
    expect(detail.images, isNotEmpty);
    expect(detail.minQuantity, greaterThanOrEqualTo(1));

    final price = await api.price(detail.id, detail.minQuantity, skuId: detail.variants.length == 1 ? detail.variants.first.skuId : null);
    expect(double.tryParse('${price['line_total_bdt']}'), isNotNull);

    final guestCart = await api.cart();
    expect(guestCart.isEmpty, isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
