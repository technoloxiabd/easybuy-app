import 'package:easybuy/core/money.dart';
import 'package:easybuy/core/push.dart';
import 'package:easybuy/data/models.dart';
import 'package:easybuy/ui/app.dart' show pushRoute;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money reads like the website: whole taka, Western grouping', () {
    expect(Money.bdt('3381.00'), '৳3,381');
    expect(Money.bdt('312200.00'), '৳312,200');
    expect(Money.bdt('162546.50'), '৳162,547');
    expect(Money.bdt(null), '৳0');
    expect(Money.isPositive('0.00'), isFalse);
    expect(Money.isPositive('0.50'), isTrue);
    expect(Money.count(1800002), '1.8M');
    expect(Money.count(5600), '5,600');
    expect(Money.kg('2.000'), '2 kg');
    expect(Money.kg('1.250'), '1.25 kg');
  });

  test('a cart parses, including an unavailable line and warnings', () {
    final cart = Cart.fromJson({
      'items': [
        {
          'id': 5, 'product_id': 9, 'sku_id': 'RED-M', 'title': 'Tee', 'image_url': null,
          'attributes': [{'label': 'Colour', 'value': 'Red'}, {'label': 'Size', 'value': 'M'}],
          'quantity': 3, 'is_selected': true, 'unit_price_bdt': '200', 'line_total_bdt': '600.00',
          'min_quantity': 2, 'is_available': false,
        },
      ],
      'item_count': 3, 'goods_total_bdt': '600.00', 'selected_count': 3, 'selected_total_bdt': '600.00',
      'coupon': {'code': 'EID10', 'label': '10% off', 'is_valid': false, 'message': 'Minimum not met'},
      'shipping_method': 'By Air', 'delivery_method': null,
      'warnings': [{'code': 'below_minimum_quantity', 'product_id': 9, 'message': 'Minimum 5 pcs'}],
    });

    expect(cart.items.single.isAvailable, isFalse);
    expect(Attribute.describe(cart.items.single.attributes), 'Colour: Red · Size: M');
    expect(cart.coupon!.isValid, isFalse);
    expect(cart.warnings.single.productId, 9);
  });

  test('the checkout dry run parses blockers, methods and totals', () {
    final c = Checkout.fromJson({
      'lines': [],
      'item_count': 3,
      'totals': {
        'goods_total_bdt': '600.00',
        'campaign': null,
        'coupon': {'code': 'EID10', 'label': '10%', 'is_valid': true, 'message': null, 'discount_bdt': '60.00'},
        'net_goods_bdt': '540.00',
      },
      'payment': {'due_now_bdt': '270.00', 'due_later_bdt': '270.00', 'advance_percent': '50', 'credit_balance_bdt': '0.00'},
      'shipping_method': 'By Air',
      'shipping_methods': [
        {'name': 'By Air', 'min_amount_bdt': null, 'is_available': true, 'rates': [{'name': 'Category A', 'price_per_kg_bdt': '770.00', 'details': '…'}]},
        {'name': 'By Sea', 'min_amount_bdt': '10000.00', 'is_available': false, 'rates': []},
      ],
      'delivery_method': null,
      'delivery_choice_required': true,
      'delivery_methods': [{'name': 'Collect From Dhaka Warehouse', 'type': 'pickup', 'note': null, 'is_default': false}],
      'addresses': [{'id': 1, 'label': null, 'name': 'Rahim', 'phone': '01712345678', 'address': 'Dhanmondi', 'is_default': true}],
      'default_address_id': 1,
      'terms': {'title': 'Terms', 'html': '<p>One</p><ul><li>Two</li></ul>'},
      'blockers': [{'code': 'delivery_method_required', 'message': 'Please choose a delivery method before checkout.'}],
      'can_place': false,
    });

    expect(c.canPlace, isFalse);
    expect(c.blockers.single.code, 'delivery_method_required');
    expect(c.shippingMethods[1].isAvailable, isFalse);
    expect(c.shippingMethods[0].rates.single.pricePerKg, '770.00');
    expect(c.deliveryMethods.single.isPickup, isTrue);
    expect(c.coupon!.discount, '60.00');
    expect(c.dueNow, '270.00');
  });

  test('an order parses its statement, transactions and next payment', () {
    final o = OrderDetail.fromJson({
      'number': 'SEP100001', 'status': 'pending_payment', 'status_label': 'Pending payment', 'placed_at': '2026-09-27T16:00:00+06:00',
      'goods_total_bdt': '1000.00', 'amount_due_bdt': '900.00', 'is_settled': false,
      'next_payment': {'stage': 'goods', 'stage_label': 'Goods', 'amount_bdt': '450.00', 'remaining_bdt': '250.00', 'pending_bdt': '200.00'},
      'items': [
        {'product_id': null, 'title': 'Tee', 'quantity': 5, 'total_bdt': '1000.00', 'shipping': null,
         'lines': [{'id': 1, 'attributes': [], 'quantity': 5, 'unit_price_bdt': '200', 'line_total_bdt': '1000.00', 'is_cancelled': false}]},
      ],
      'statement': {'invoice_amount_bdt': '1000.00', 'balance_bdt': '900.00', 'is_settled': false, 'freight': null},
      'transactions': [
        {'kind': 'payment', 'id': 7, 'stage_label': 'Goods', 'method': 'bKash', 'amount_bdt': '200.00', 'status': 'pending', 'can_edit': true,
         'receipts': [{'url': 'https://x/api/v1/files/a.jpg?signature=1', 'name': 'a.jpg', 'kind': 'image'}]},
        {'kind': 'adjustment', 'label': 'Discount', 'amount_bdt': '100.00', 'sign': '-'},
      ],
      'refunds': [], 'courier': [], 'timeline': [{'status': 'pending_payment', 'label': 'Pending payment', 'at': '2026-09-27T16:00:00+06:00'}],
      'address': {'name': 'Rahim', 'phone': '01712345678', 'address': 'Dhanmondi', 'can_edit': true},
    });

    expect(o.summary.nextPayment!.remaining, '250.00');
    expect(o.transactions.first.canEdit, isTrue);
    expect(o.transactions.first.receipts.single.kind, 'image');
    expect(o.transactions.last.isPayment, isFalse);
    expect(o.canEditAddress, isTrue);
    expect(o.summary.placedAt, isNotNull);
  });

  test('missing fields never crash parsing', () {
    expect(() => ProductDetail.fromJson({}), returnsNormally);
    expect(() => OrderSummary.fromJson({}), returnsNormally);
    expect(() => User.fromJson({'id': '5'}), returnsNormally);
    expect(User.fromJson({'id': '5'}).id, 5);
  });

  test('a tapped push opens the screen its data names', () {
    expect(pushRoute({'type': 'order', 'order_number': 'SEP100001'}), '/orders/SEP100001');
    expect(pushRoute({'type': 'complaint', 'complaint_number': 'CMP-7'}), '/support/CMP-7');
    expect(pushRoute({'type': 'chat'}), '/chat');
    expect(pushRoute({'type': 'order'}), isNull);
    expect(pushRoute({}), isNull);
  });

  test('without Firebase settings the build simply has no push', () {
    expect(PushService.options(), isNull);
  });
}
