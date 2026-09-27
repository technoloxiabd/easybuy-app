/// Defensive readers for server JSON: a missing or null field becomes a safe
/// default instead of a crash on a customer's phone.
typedef Json = Map<String, dynamic>;

String str(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
String? strOrNull(Object? v) => v == null ? null : '$v';
int integer(Object? v, [int fallback = 0]) => v is int ? v : int.tryParse('$v') ?? fallback;
int? intOrNull(Object? v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
bool boolean(Object? v) => v == true || v == 1 || v == '1';
Json obj(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
Json? objOrNull(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<T> listOf<T>(Object? v, T Function(Json) parse) =>
    v is List ? v.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList() : <T>[];
DateTime? date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
