import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Saved products, kept on this phone -- exactly as the website keeps its
/// wishlist in the browser (no account needed, nothing on the server).
class WishlistNotifier extends Notifier<List<ProductCard>> {
  static const _key = 'wishlist_v1';

  @override
  List<ProductCard> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is List) state = list.whereType<Map>().map((m) => ProductCard.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (_) {
      // A damaged store starts empty rather than breaking the app.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.map((p) => p.toJson()).toList()));
    } catch (_) {}
  }

  bool contains(int productId) => state.any((p) => p.id == productId);

  /// Add or remove; newest first, like the website's list.
  Future<bool> toggle(ProductCard product) async {
    final saved = contains(product.id);
    state = saved ? state.where((p) => p.id != product.id).toList() : [product, ...state];
    await _save();
    return !saved;
  }

  Future<void> clear() async {
    state = const [];
    await _save();
  }
}

final wishlistProvider = NotifierProvider<WishlistNotifier, List<ProductCard>>(WishlistNotifier.new);

