import 'package:intl/intl.dart';

/// Money arrives as decimal strings ("3381.00") and is only ever formatted
/// here, never computed with: the server does every sum.
class Money {
  static final _whole = NumberFormat('#,##0', 'en_US');

  /// "৳312,200" -- exactly as the website prints money (PricingService::
  /// format: whole taka, Western grouping, rounded half away from zero).
  static String bdt(String? amount) {
    final value = double.tryParse(amount ?? '') ?? 0;
    return '৳${_whole.format(value.round())}';
  }

  /// Western digits as Bengali numerals ("৳1,000" -> "৳১,০০০"): the
  /// website's Bengali notices write their numbers this way.
  static String bn(Object value) => '$value'.replaceAllMapped(RegExp(r'\d'), (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)]);

  static bool isPositive(String? amount) => (double.tryParse(amount ?? '') ?? 0) > 0.004;

  static final _compact = NumberFormat.compact(locale: 'en');

  /// "1.8M sold" rather than "1800002 sold".
  static String count(int n) => n < 10000 ? NumberFormat('#,##0').format(n) : _compact.format(n);

  /// "2 kg", "1.25 kg" -- trailing zeros off.
  static String kg(String? value) {
    final v = double.tryParse(value ?? '');
    if (v == null) return '';
    return '${v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '')} kg';
  }
}
