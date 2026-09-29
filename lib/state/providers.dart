import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/config.dart';
import '../core/push.dart';
import '../core/session_store.dart';
import '../data/api.dart';
import '../data/models.dart';

/// Loaded in main() before the first frame and overridden there.
final sessionStoreProvider = Provider<SessionStore>((ref) => throw UnimplementedError('override in main'));

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(sessionStoreProvider));
  // A token the server no longer accepts: forget the customer.
  client.onSignedOut = () => ref.read(authProvider.notifier).signedOutElsewhere();
  return client;
});

final apiProvider = Provider<EasyBuyApi>((ref) => EasyBuyApi(ref.watch(apiClientProvider)));

// ------------------------------------------------------------------ session

/// The signed-in customer, or null for a guest.
class AuthNotifier extends AsyncNotifier<User?> {
  EasyBuyApi get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<User?> build() async {
    if (_store.token == null) return null;
    try {
      final user = await _api.me();
      // Every start: Firebase may have rotated the token since last time.
      PushService.instance.register(_api, AppConfig.appVersion).ignore();
      return user;
    } on ApiError catch (e) {
      if (e.isUnauthenticated) return null;
      rethrow;
    }
  }

  User? get user => state.value;

  Future<void> signIn(String login, String password, String device) async {
    final (token, user) = await _api.login(login, password, device);
    await _adopt(token, user);
  }

  Future<void> register({required String name, required String phone, String? email, required String password, required String device}) async {
    final (token, user) = await _api.register(name: name, phone: phone, email: email, password: password, device: device);
    await _adopt(token, user);
  }

  Future<void> _adopt(String token, User user) async {
    await _store.setToken(token);
    state = AsyncData(user);
    // The first signed-in cart call folds the guest cart into the account;
    // after that the guest token names nothing, so it is dropped.
    await ref.read(cartProvider.notifier).refresh();
    await _store.setCartToken(null);
    PushService.instance.register(_api, AppConfig.appVersion).ignore();
  }

  Future<void> signOut() async {
    await PushService.instance.unregister(_api);
    try {
      await _api.logout();
    } catch (_) {
      // Signing out locally must work offline too.
    }
    await _store.setToken(null);
    state = const AsyncData(null);
    ref.invalidate(cartProvider);
  }

  void signedOutElsewhere() {
    state = const AsyncData(null);
    ref.invalidate(cartProvider);
  }

  void setUser(User user) => state = AsyncData(user);

  Future<void> reload() async {
    final user = await _api.me();
    state = AsyncData(user);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

// ------------------------------------------------------------------ cart

/// The cart, for the signed-in customer or the guest's token. Every change
/// answers with the whole cart as the server now sees it.
class CartNotifier extends AsyncNotifier<Cart> {
  EasyBuyApi get _api => ref.read(apiProvider);

  @override
  Future<Cart> build() => _api.cart();

  Future<void> refresh() async => state = AsyncData(await _api.cart());

  Future<void> _apply(Future<Cart> Function() change) async => state = AsyncData(await change());

  Future<void> add(int productId, {String? skuId, int? quantity, Map<String, int>? variants}) =>
      _apply(() => _api.addToCart(productId, skuId: skuId, quantity: quantity, variants: variants));

  Future<void> setQuantity(int lineId, int quantity) => _apply(() => _api.updateLine(lineId, quantity: quantity));

  Future<void> setSelected(int lineId, bool selected) => _apply(() => _api.updateLine(lineId, selected: selected));

  Future<void> selectAll(bool selected, {int? productId}) => _apply(() => _api.selectAll(selected, productId: productId));

  Future<void> remove(int lineId) => _apply(() => _api.removeLine(lineId));

  Future<void> clear() => _apply(_api.clearCart);

  Future<void> setMethods({String? shipping, String? delivery}) => _apply(() => _api.cartMethods(shipping: shipping, delivery: delivery));

  Future<void> applyCoupon(String code) => _apply(() => _api.applyCoupon(code));

  Future<void> removeCoupon() => _apply(_api.removeCoupon);
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(CartNotifier.new);

/// Pieces in the cart, for the tab badge.
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).value?.itemCount ?? 0);

/// Chat replies waiting, for the badge. Refreshed on app resume / push.
final unreadMessagesProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return 0;
  return ref.read(apiProvider).unreadMessages();
});
