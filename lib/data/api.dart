import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import 'json.dart';
import 'models.dart';

/// Every server endpoint the app uses, typed. Screens call these; nothing
/// else in the app builds a URL.
class EasyBuyApi {
  EasyBuyApi(this.client);

  final ApiClient client;

  // ---------------------------------------------------------- auth

  Future<(String, User)> login(String login, String password, String device) async {
    final r = await client.post('/auth/login', body: {'login': login, 'password': password, 'device_name': device});
    return (str(r['token']), User.fromJson(obj(r['user'])));
  }

  Future<(String, User)> register({required String name, required String phone, String? email, required String password, required String device}) async {
    final r = await client.post('/auth/register', body: {'name': name, 'phone': phone, 'email': email, 'password': password, 'device_name': device});
    return (str(r['token']), User.fromJson(obj(r['user'])));
  }

  Future<User> me() async => User.fromJson(obj((await client.get('/auth/me'))['data']));

  Future<void> logout() => client.post('/auth/logout');

  Future<Json> sendPhoneCode() => client.post('/auth/phone/send');

  Future<User> verifyPhone(String code) async => User.fromJson(obj((await client.post('/auth/phone/verify', body: {'code': code}))['data']));

  /// Email: a reset link is mailed. Phone: an SMS code, then [resetPassword].
  Future<Json> forgotPassword(String login) => client.post('/auth/password/forgot', body: {'login': login});

  Future<void> resetPassword({required String phone, required String code, required String password}) =>
      client.post('/auth/password/reset', body: {'phone': phone, 'code': code, 'password': password, 'password_confirmation': password});

  // ---------------------------------------------------------- catalogue

  Future<Paged<ProductCard>> products({String? query, int? category, String? sort, String? cursor}) async {
    final r = await client.get('/products', query: {'q': query, 'category': category, 'sort': sort, 'cursor': cursor, 'per_page': 20});
    return Paged(listOf(r['data'], ProductCard.fromJson), strOrNull(obj(r['meta'])['next_cursor']));
  }

  Future<ProductDetail> product(int id) async => ProductDetail.fromJson(obj((await client.get('/products/$id'))['data']));

  Future<Json> price(int id, int quantity, {String? skuId}) async =>
      obj((await client.get('/products/$id/price', query: {'quantity': quantity, 'sku_id': skuId}))['data']);

  Future<List<Category>> categories() async => listOf((await client.get('/categories'))['data'], Category.fromJson);

  Future<List<String>> suggest(String q) async {
    final r = await client.get('/search/suggest', query: {'q': q});
    final data = r['data'];
    return data is List ? data.map((e) => '$e').toList() : const [];
  }

  // ---------------------------------------------------------- cart

  Future<Cart> cart() async => Cart.fromJson(obj((await client.get('/cart'))['data']));

  Future<Cart> addToCart(int productId, {String? skuId, int? quantity, Map<String, int>? variants}) async {
    final body = <String, dynamic>{'product_id': productId};
    if (variants != null && variants.isNotEmpty) {
      body['variants'] = variants.entries.map((e) => {'sku_id': e.key, 'quantity': e.value}).toList();
    } else {
      body['sku_id'] = skuId;
      body['quantity'] = quantity;
    }
    return Cart.fromJson(obj((await client.post('/cart/items', body: body))['data']));
  }

  Future<Cart> updateLine(int id, {int? quantity, bool? selected}) async =>
      Cart.fromJson(obj((await client.patch('/cart/items/$id', body: {'quantity': quantity, 'is_selected': selected}..removeWhere((k, v) => v == null)))['data']));

  Future<Cart> removeLine(int id) async => Cart.fromJson(obj((await client.delete('/cart/items/$id'))['data']));

  Future<Cart> selectAll(bool selected, {int? productId}) async =>
      Cart.fromJson(obj((await client.patch('/cart/selection', body: {'selected': selected, 'product_id': productId}))['data']));

  Future<Cart> clearCart() async => Cart.fromJson(obj((await client.delete('/cart'))['data']));

  Future<Cart> applyCoupon(String code) async => Cart.fromJson(obj((await client.post('/cart/coupon', body: {'code': code}))['data']));

  Future<Cart> removeCoupon() async => Cart.fromJson(obj((await client.delete('/cart/coupon'))['data']));

  // ---------------------------------------------------------- checkout

  Future<Checkout> checkout() async => Checkout.fromJson(obj((await client.get('/checkout'))['data']));

  Future<Checkout> chooseMethods({String? shipping, String? delivery}) async =>
      Checkout.fromJson(obj((await client.patch('/checkout/methods', body: {'shipping_method': shipping, 'delivery_method': delivery}..removeWhere((k, v) => v == null)))['data']));

  /// A fresh key per attempt at ONE order: retries of the same tap reuse it,
  /// so a dropped connection can never place the order twice.
  static String newIdempotencyKey() => const Uuid().v4();

  Future<OrderSummary> placeOrder({required String idempotencyKey, int? addressId, String? name, String? phone, String? address, bool saveAddress = true, String? notes, bool useCredit = false}) async {
    final body = <String, dynamic>{
      if (addressId != null) 'address_id': addressId else ...{'name': name, 'phone': phone, 'address': address, 'save_address': saveAddress},
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (useCredit) 'use_credit': true,
    };
    final r = await client.post('/checkout', body: body, headers: {'Idempotency-Key': idempotencyKey});
    return OrderSummary.fromJson(obj(r['data']));
  }

  // ---------------------------------------------------------- orders

  Future<Paged<OrderSummary>> orders({String? cursor, String? status}) async {
    final r = await client.get('/orders', query: {'cursor': cursor, 'status': status});
    return Paged(listOf(r['data'], OrderSummary.fromJson), strOrNull(obj(r['meta'])['next_cursor']));
  }

  Future<OrderDetail> order(String number) async => OrderDetail.fromJson(obj((await client.get('/orders/$number'))['data']));

  Future<String> invoiceUrl(String number) async => str(obj((await client.get('/orders/$number/invoice'))['data'])['url']);

  Future<OrderDetail> updateOrderAddress(String number, {required String name, required String phone, required String address}) async =>
      OrderDetail.fromJson(obj((await client.patch('/orders/$number/address', body: {'name': name, 'phone': phone, 'address': address}))['data']));

  // ---------------------------------------------------------- payments

  Future<PayOptions> payOptions(String number, {String? stage}) async =>
      PayOptions.fromJson(obj((await client.get('/orders/$number/payments', query: {'stage': stage}))['data']));

  Future<Json> pay(String number, {required String stage, required int methodId, String? amount, bool shippingOnly = false, String? reference, List<String> proofPaths = const []}) async {
    final form = FormData.fromMap({
      'stage': stage,
      'payment_method_id': methodId,
      if (amount != null && amount.isNotEmpty) 'amount': amount,
      if (shippingOnly) 'shipping_only': 1,
      if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim(),
      'proof[]': [for (final p in proofPaths) await MultipartFile.fromFile(p)],
    });
    return obj((await client.post('/orders/$number/payments', body: form))['data']);
  }

  Future<Json> amendPayment(String number, int paymentId, {String? amount, String? reference, List<String> proofPaths = const []}) async {
    final form = FormData.fromMap({
      if (amount != null && amount.isNotEmpty) 'amount': amount,
      if (reference != null && reference.trim().isNotEmpty) 'reference': reference.trim(),
      'proof[]': [for (final p in proofPaths) await MultipartFile.fromFile(p)],
    });
    return obj((await client.post('/orders/$number/payments/$paymentId', body: form))['data']);
  }

  // ---------------------------------------------------------- account

  Future<Json> accountOverview() async => obj((await client.get('/account'))['data']);

  Future<User> updateProfile({required String name, String? email, required String phone}) async =>
      User.fromJson(obj((await client.patch('/account/profile', body: {'name': name, 'email': email, 'phone': phone}))['data']));

  Future<User> updatePhoto(String path) async =>
      User.fromJson(obj((await client.post('/account/photo', body: FormData.fromMap({'photo': await MultipartFile.fromFile(path)})))['data']));

  Future<void> changePassword(String current, String next) =>
      client.patch('/account/password', body: {'current_password': current, 'password': next, 'password_confirmation': next});

  Future<List<Address>> addresses() async => listOf((await client.get('/account/addresses'))['data'], Address.fromJson);

  Future<Address> saveAddress({int? id, String? label, required String name, required String phone, required String address, bool makeDefault = false}) async {
    final body = {'label': label, 'name': name, 'phone': phone, 'address': address, 'is_default': makeDefault};
    final r = id == null ? await client.post('/account/addresses', body: body) : await client.patch('/account/addresses/$id', body: body);
    return Address.fromJson(obj(r['data']));
  }

  Future<List<Address>> makeDefaultAddress(int id) async => listOf((await client.patch('/account/addresses/$id/default'))['data'], Address.fromJson);

  Future<List<Address>> deleteAddress(int id) async => listOf((await client.delete('/account/addresses/$id'))['data'], Address.fromJson);

  Future<Json> accountPayments({String? cursor}) => client.get('/account/payments', query: {'cursor': cursor});

  Future<Json> credit({String? cursor}) => client.get('/account/credit', query: {'cursor': cursor});

  // ---------------------------------------------------------- support

  Future<List<ComplaintSummary>> complaints() async => listOf((await client.get('/complaints'))['data'], ComplaintSummary.fromJson);

  Future<ComplaintDetail> complaint(String number) async => ComplaintDetail.fromJson(obj((await client.get('/complaints/$number'))['data']));

  Future<ComplaintDetail> openComplaint({required String subject, required String details, String? orderNumber, List<String> files = const []}) async {
    final form = FormData.fromMap({
      'subject': subject,
      'details': details,
      'order_number': ?orderNumber,
      'attachments[]': [for (final p in files) await MultipartFile.fromFile(p)],
    });
    return ComplaintDetail.fromJson(obj((await client.post('/complaints', body: form))['data']));
  }

  Future<ComplaintDetail> replyComplaint(String number, String body, {List<String> files = const []}) async {
    final form = FormData.fromMap({'body': body, 'attachments[]': [for (final p in files) await MultipartFile.fromFile(p)]});
    return ComplaintDetail.fromJson(obj((await client.post('/complaints/$number/reply', body: form))['data']));
  }

  Future<(List<ThreadMessage>, Json)> messages({int? after, int? before}) async {
    final r = await client.get('/messages', query: {'after': after, 'before': before});
    return (listOf(r['data'], ThreadMessage.fromJson), obj(r['meta']));
  }

  Future<ThreadMessage> sendMessage({String? body, List<String> files = const [], String? orderNumber, int? productId, bool shareProduct = false}) async {
    final form = FormData.fromMap({
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      'order_number': ?orderNumber,
      'product_id': ?productId,
      if (shareProduct) 'share_product': 1,
      'attachments[]': [for (final p in files) await MultipartFile.fromFile(p)],
    });
    return ThreadMessage.fromJson(obj((await client.post('/messages', body: form))['data']));
  }

  Future<void> undoMessage(int id) => client.delete('/messages/$id');

  Future<int> unreadMessages() async => integer(obj((await client.get('/messages/unread'))['data'])['unread']);

  // ---------------------------------------------------------- push

  Future<void> registerDevice(String token, String platform, String appVersion) =>
      client.post('/devices', body: {'token': token, 'platform': platform, 'app_version': appVersion});

  Future<void> unregisterDevice(String token) => client.delete('/devices', body: {'token': token});
}
