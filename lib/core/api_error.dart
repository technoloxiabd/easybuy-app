/// The server's one error envelope: `{code, message, meta?, errors?}`.
///
/// `message` is always safe to show -- the server writes it for the customer,
/// in their language. `code` is what the app branches on.
class ApiError implements Exception {
  ApiError({
    required this.code,
    required this.message,
    this.status,
    this.meta = const {},
    this.errors = const {},
  });

  final String code;
  final String message;
  final int? status;
  final Map<String, dynamic> meta;

  /// Field errors from a 422 `validation_failed`: field -> messages.
  final Map<String, List<String>> errors;

  /// No response at all: no signal, DNS, timeout.
  static ApiError offline() => ApiError(
        code: 'offline',
        message: 'No connection. Check your internet and try again.',
      );

  factory ApiError.fromBody(Object? body, int? status) {
    if (body is Map) {
      final errors = <String, List<String>>{};
      final raw = body['errors'];
      if (raw is Map) {
        raw.forEach((k, v) {
          errors['$k'] = v is List ? v.map((e) => '$e').toList() : ['$v'];
        });
      }
      return ApiError(
        code: '${body['code'] ?? 'error'}',
        message: '${body['message'] ?? 'Something went wrong. Please try again.'}',
        status: status,
        meta: body['meta'] is Map ? Map<String, dynamic>.from(body['meta'] as Map) : const {},
        errors: errors,
      );
    }
    return ApiError(
      code: 'error',
      message: 'Something went wrong. Please try again.',
      status: status,
    );
  }

  /// The first message for [field], for showing under an input.
  String? fieldError(String field) {
    final list = errors[field];
    if (list != null && list.isNotEmpty) return list.first;
    if (meta['field'] == field) return message;
    return null;
  }

  bool get isUnauthenticated => status == 401 || code == 'unauthenticated';

  @override
  String toString() => 'ApiError($code, $status): $message';
}
