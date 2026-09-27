import 'package:intl/intl.dart';

/// Money arrives as decimal strings ("3381.00") and is only ever formatted
/// here, never computed with: the server does every sum.
class Money {
  static final _whole = NumberFormat('#,##,##0', 'en_IN');
  static final _paisa = NumberFormat('#,##,##0.00', 'en_IN');

  /// "৳3,381" -- whole taka shown without ".00", real paisa kept.
  static String bdt(String? amount) {
    final value = double.tryParse(amount ?? '') ?? 0;
    final whole = value == value.roundToDouble();
    return '৳${whole ? _whole.format(value) : _paisa.format(value)}';
  }

  static bool isPositive(String? amount) => (double.tryParse(amount ?? '') ?? 0) > 0.004;
}
