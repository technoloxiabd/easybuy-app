@Tags(['screens'])
library;

import 'dart:io';

import 'package:easybuy/core/api_client.dart';
import 'package:easybuy/data/api.dart';
import 'package:easybuy/data/json.dart';
import 'package:easybuy/data/models.dart';
import 'package:easybuy/state/providers.dart';
import 'package:easybuy/ui/app.dart';
import 'package:easybuy/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'client_test.dart' show MemorySession;

/// Renders the main screens as phone-sized PNGs for review, with REAL
/// catalogue data from the live API and sample customer data (never a real
/// customer's). Not part of the normal run:
///   flutter test --tags screens --run-skipped --update-goldens test/screens_test.dart
/// Output: test/screens/*.png

const _fonts = '/home/easybuycom/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String f) async => ByteData.sublistView(await File('$_fonts/$f').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(bytes('Roboto-Regular.ttf'))
        ..addFont(bytes('Roboto-Medium.ttf'))
        ..addFont(bytes('Roboto-Bold.ttf'))
        ..addFont(bytes('Roboto-Black.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(bytes('MaterialIcons-Regular.otf'))).load();
  Future<ByteData> asset(String f) async => ByteData.sublistView(await File('assets/fonts/$f').readAsBytes());
  await (FontLoader('AnekBangla')
        ..addFont(asset('AnekBangla-Regular.ttf'))
        ..addFont(asset('AnekBangla-SemiBold.ttf'))
        ..addFont(asset('AnekBangla-Bold.ttf')))
      .load();
}

class LiveData {
  late List<Category> categories;
  late List<ProductCard> products;
  late ProductDetail detail;
}

class ShotApi extends EasyBuyApi {
  ShotApi(this.live) : super(ApiClient(MemorySession()));
  final LiveData live;

  ProductCard get p0 => live.products[0];
  ProductCard get p1 => live.products[1];

  CartItem _line(ProductCard p, int id, int qty, String unit, String total, {String? colour, bool available = true}) => CartItem(
        id: id, productId: p.id, title: p.title, imageUrl: p.imageUrl,
        attributes: colour == null ? const [] : [Attribute('Colour', colour), Attribute('Size', 'M')],
        quantity: qty, isSelected: true, unitPrice: unit, lineTotal: total, minQuantity: p.minQuantity, isAvailable: available,
      );

  @override
  Future<User> me() async => User(id: 1, name: 'Rahim Uddin', phone: '01712345678', email: 'rahim@example.com', phoneVerified: true);

  @override
  Future<List<Category>> categories() async => live.categories;

  @override
  Future<Paged<ProductCard>> products({String? query, int? category, String? sort, String? cursor}) async => Paged(live.products, null);

  @override
  Future<ProductDetail> product(int id) async => live.detail;

  @override
  Future<Json> price(int id, int quantity, {String? skuId}) async =>
      {'unit_price_bdt': live.detail.unitPrice, 'line_total_bdt': ((double.tryParse(live.detail.unitPrice) ?? 0) * quantity).toStringAsFixed(2)};

  @override
  Future<Cart> cart() async => Cart(
        items: [
          _line(p0, 1, 3, p0.unitPrice, (double.parse(p0.unitPrice) * 3).toStringAsFixed(2), colour: 'Red'),
          _line(p0, 2, 2, p0.unitPrice, (double.parse(p0.unitPrice) * 2).toStringAsFixed(2), colour: 'Blue'),
          _line(p1, 3, p1.minQuantity, p1.unitPrice, (double.parse(p1.unitPrice) * p1.minQuantity).toStringAsFixed(2)),
        ],
        itemCount: 5 + p1.minQuantity,
        goodsTotal: '4200.00',
        selectedCount: 5 + p1.minQuantity,
        selectedTotal: '4200.00',
        coupon: CouponState(code: 'EID10', label: '10% off', isValid: true),
        warnings: const [],
      );

  @override
  Future<Checkout> checkout() async {
    final c = await cart();
    return Checkout(
      lines: c.items, itemCount: c.itemCount, goodsTotal: '4200.00',
      coupon: CouponState(code: 'EID10', label: '10% off', isValid: true, discount: '420.00'),
      netGoods: '3780.00', dueNow: '1890.00', dueLater: '1890.00', advancePercent: '50', creditBalance: '150.00',
      shippingMethod: 'By Air',
      shippingMethods: [
        ShippingMethod(name: 'By Air', isAvailable: true, rates: [
          ShippingRate('Category A', '770.00', 'From ৳770/kg. Shoes, bags, jewellery, tools, electronics accessories. 7–12 days.'),
          ShippingRate('Category B', '1170.00', 'From ৳1,170/kg. Items with batteries, copies, seeds, chemicals. 15–25 days.'),
        ]),
        ShippingMethod(name: 'By Sea', minAmount: '10000.00', isAvailable: false, rates: const []),
      ],
      deliveryMethod: 'Delivery by Courier',
      deliveryChoiceRequired: true,
      deliveryMethods: [
        DeliveryMethod(name: 'Collect From Dhaka Warehouse', type: 'pickup', isDefault: false),
        DeliveryMethod(name: 'Delivery by Courier', type: 'courier', note: 'Delivered by Pathao; the rider collects any balance.', isDefault: false),
      ],
      addresses: [
        Address(id: 1, label: 'Home', name: 'Rahim Uddin', phone: '01712345678', address: 'House 12, Road 5, Dhanmondi, Dhaka', isDefault: true),
        Address(id: 2, label: 'Shop', name: 'Rahim Uddin', phone: '01812345678', address: 'Shop 44, Bashundhara City, Panthapath', isDefault: false),
      ],
      defaultAddressId: 1,
      blockers: const [],
      canPlace: true,
    );
  }

  OrderSummary _summary(String number, String status, String label, {NextPayment? next}) => OrderSummary(
        number: number, status: status, statusLabel: label, placedAt: DateTime(2026, 9, 21, 15, 40),
        title: p0.title, thumbnailUrl: p0.imageUrl, productCount: 2, itemCount: 8, goodsTotal: '4200.00',
        discount: '420.00', advanceDue: '1890.00', paid: next == null ? '3780.00' : '0.00',
        amountDue: next == null ? '0.00' : '3780.00', isSettled: next == null, nextPayment: next,
        shippingMethod: 'By Air', deliveryMethod: 'Delivery by Courier',
      );

  @override
  Future<Paged<OrderSummary>> orders({String? cursor, String? status}) async => Paged([
        _summary('SEP270412', 'pending_payment', 'Pending payment',
            next: NextPayment(stage: 'goods', stageLabel: 'Goods', amount: '1890.00', remaining: '1890.00', pending: '0.00')),
        _summary('SEP214087', 'shipped', 'Shipped from China'),
        _summary('SEP180339', 'delivered', 'Delivered'),
      ], null);

  @override
  Future<OrderDetail> order(String number) async => OrderDetail.fromJson({
        'number': 'SEP214087', 'status': 'ready_for_delivery', 'status_label': 'Ready for delivery', 'placed_at': '2026-09-14T11:20:00+06:00',
        'title': p0.title, 'thumbnail_url': p0.imageUrl, 'product_count': 2, 'item_count': 8,
        'goods_total_bdt': '4200.00', 'discount_bdt': '420.00', 'advance_due_bdt': '1890.00', 'paid_bdt': '1890.00', 'amount_due_bdt': '3150.00',
        'is_settled': false,
        'next_payment': {'stage': 'balance', 'stage_label': 'Balance due', 'amount_bdt': '3150.00', 'remaining_bdt': '3150.00', 'pending_bdt': '0.00'},
        'shipping_method': 'By Air', 'delivery_method': 'Delivery by Courier',
        'items': [
          {'product_id': p0.id, 'title': p0.title, 'image_url': p0.imageUrl, 'quantity': 5, 'total_bdt': '2600.00',
           'shipping': {'rate_per_kg_bdt': '770.00', 'weight_kg': '1.2', 'cost_bdt': '924.00'},
           'lines': [
             {'id': 1, 'attributes': [{'label': 'Colour', 'value': 'Red'}], 'quantity': 3, 'unit_price_bdt': '520', 'line_total_bdt': '1560.00', 'is_cancelled': false},
             {'id': 2, 'attributes': [{'label': 'Colour', 'value': 'Blue'}], 'quantity': 2, 'unit_price_bdt': '520', 'line_total_bdt': '1040.00', 'is_cancelled': false},
           ]},
          {'product_id': p1.id, 'title': p1.title, 'image_url': p1.imageUrl, 'quantity': 3, 'total_bdt': '1600.00', 'shipping': null,
           'lines': [{'id': 3, 'attributes': [], 'quantity': 3, 'unit_price_bdt': '534', 'line_total_bdt': '1600.00', 'is_cancelled': false}]},
        ],
        'statement': {
          'goods_total_bdt': '4200.00', 'freight': {'amount_bdt': '1260.00', 'weight_kg': '1.64'}, 'surcharges': [],
          'refund_charges_bdt': '0.00', 'invoice_amount_bdt': '5460.00', 'credits_bdt': '420.00', 'paid_bdt': '1890.00',
          'submitted_bdt': '0.00', 'refunded_bdt': '0.00', 'moved_to_balance_bdt': '0.00', 'balance_bdt': '3150.00',
          'is_settled': false, 'is_overpaid': false,
        },
        'transactions': [
          {'kind': 'payment', 'id': 9, 'stage_label': 'Goods', 'method': 'bKash (Merchant)', 'amount_bdt': '1890.00', 'status': 'confirmed',
           'reference': 'TRX8K2Q1A', 'can_edit': false, 'created_at': '2026-09-14T11:31:00+06:00', 'receipts': [{'url': 'x', 'name': 'r.jpg', 'kind': 'image'}]},
          {'kind': 'adjustment', 'label': 'Discount', 'reason': 'Coupon: EID10', 'amount_bdt': '420.00', 'sign': '-', 'created_at': '2026-09-14T11:20:00+06:00'},
        ],
        'refunds': [], 'courier': [],
        'timeline': [
          {'status': 'ready_for_delivery', 'label': 'Ready for delivery', 'at': '2026-09-26T10:05:00+06:00'},
          {'status': 'shipped', 'label': 'Shipped from China', 'at': '2026-09-19T18:40:00+06:00'},
          {'status': 'confirmed', 'label': 'Confirmed', 'at': '2026-09-14T12:02:00+06:00'},
        ],
        'address': {'name': 'Rahim Uddin', 'phone': '01712345678', 'address': 'House 12, Road 5, Dhanmondi, Dhaka', 'can_edit': false},
      });

  @override
  Future<PayOptions> payOptions(String number, {String? stage}) async => PayOptions(
        stage: 'balance', stageLabel: 'Balance due', outstanding: '3150.00', pending: '0.00', suggested: '3150.00',
        shippingOnly: '1260.00', canPay: true,
        methods: [
          PayMethod(id: 1, name: 'bKash (Merchant)', type: 'manual', instructions: 'Use "Payment" in the bKash app to the merchant number below, then enter the TrxID.',
              account: {'account_name': 'EasyBuy', 'account_number': '01XXXXXXXXX'}, collectsReference: true, collectsProof: true),
          PayMethod(id: 5, name: 'Dutch Bangla Bank (DBBL)', type: 'manual', account: const {}, collectsReference: true, collectsProof: true),
        ],
      );

  @override
  Future<Json> accountOverview() async => {'credit_balance_bdt': '150.00', 'orders': {'total': 12, 'in_transit': 2, 'action_needed': 1}};

  @override
  Future<int> unreadMessages() async => 1;

  @override
  Future<(List<ThreadMessage>, Json)> messages({int? after, int? before}) async => (
        [
          ThreadMessage(id: 1, mine: true, body: 'When will order SEP214087 reach Dhaka?', attachments: const [], canUndo: false, createdAt: DateTime(2026, 9, 25, 10, 2)),
          ThreadMessage(id: 2, mine: false, author: 'EasyBuy bot', body: 'Order SEP214087 is Shipped from China. It usually reaches Dhaka in 7–12 days.', attachments: const [], canUndo: false, createdAt: DateTime(2026, 9, 25, 10, 2)),
          ThreadMessage(id: 3, mine: false, author: 'Nabila', body: 'It landed this morning — ready for delivery. The rider will call you.', attachments: const [], canUndo: false, createdAt: DateTime(2026, 9, 26, 10, 11)),
        ],
        <String, dynamic>{'manager': {'name': 'Nabila', 'presence': 'online'}, 'removed': [], 'has_more': false},
      );
}

void main() {
  late LiveData live;

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('screens', (tester) async {
    HttpOverrides.global = null; // this test fetches real catalogue data
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    live = LiveData();
    await tester.runAsync(() async {
      final real = EasyBuyApi(ApiClient(MemorySession()));
      live.categories = await real.categories();
      live.products = (await real.products()).items.where((p) => p.imageUrl != null).take(8).toList();
      live.detail = await real.product(live.products.first.id);

      final urls = {
        ...live.products.map((p) => p.imageUrl!),
        ...live.categories.map((c) => c.imageUrl).whereType<String>(),
        ...live.detail.images.take(1),
        ...live.detail.variants.map((v) => v.imageUrl).whereType<String>(),
      };
      final client = HttpClient();
      for (final u in urls) {
        try {
          final res = await (await client.getUrl(Uri.parse(u))).close();
          final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
          if (res.statusCode == 200) NetImage.preloaded[u] = Uint8List.fromList(bytes);
        } catch (_) {}
      }
    });

    final session = MemorySession();
    await session.setToken('screenshot');
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStoreProvider.overrideWithValue(session), apiProvider.overrideWithValue(ShotApi(live))],
      child: const EasyBuyApp(),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    }

    Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/$name.png'));

    final router = ProviderScope.containerOf(tester.element(find.byType(EasyBuyApp))).read(routerProvider);

    await settle();
    await shot('01_home');

    router.push('/product/${live.detail.id}');
    await settle();
    await shot('02_product');
    router.pop();
    await settle();

    router.go('/cart');
    await settle();
    await shot('03_cart');

    router.push('/checkout');
    await settle();
    await shot('04_checkout');
    router.pop();
    await settle();

    router.go('/orders');
    await settle();
    await shot('05_orders');

    router.push('/orders/SEP214087');
    await settle();
    await shot('06_order');

    router.push('/orders/SEP214087/pay');
    await settle();
    await shot('07_pay');
    router.pop();
    router.pop();
    await settle();

    router.go('/account');
    await settle();
    await shot('08_account');

    router.push('/chat');
    await settle();
    await shot('09_chat');

    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
