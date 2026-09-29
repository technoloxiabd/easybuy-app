import 'package:dio/dio.dart';

import 'api_error.dart';
import 'config.dart';
import 'session_store.dart';

/// One HTTP client for the whole app.
///
/// Adds the bearer token and the guest cart token to every call, keeps a
/// cart token the server issues, and turns every failure into an [ApiError]
/// carrying the server's own message. A 401 on a signed-in call means the
/// token is gone (signed out elsewhere, password reset): [onSignedOut] lets
/// the session forget it.
class ApiClient {
  ApiClient(this.session, {Dio? dio, this.onSignedOut})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBase,
              // A connection that has not opened in 8 seconds is not coming:
              // say "No connection" rather than keep the spinner going.
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Accept': 'application/json'},
            )) {
    this.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = session.token;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        final cart = session.cartToken;
        if (cart != null) options.headers['X-Cart-Token'] = cart;
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // Issued on a guest's first add; the only copy is this one.
        final issued = response.headers.value('X-Cart-Token');
        if (issued != null && issued.isNotEmpty) await session.setCartToken(issued);
        handler.next(response);
      },
    ));
  }

  final SessionStore session;
  final Dio dio;
  void Function()? onSignedOut;

  /// [receiveTimeout] lifts the default 30s for the few calls that wait on
  /// a slow upstream (a search by photo can take 20s at the supplier).
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, Duration? receiveTimeout}) =>
      _send(() => dio.get(path, queryParameters: _clean(query), options: receiveTimeout == null ? null : Options(receiveTimeout: receiveTimeout)));

  Future<Map<String, dynamic>> post(String path, {Object? body, Map<String, String>? headers}) =>
      _send(() => dio.post(path, data: body, options: Options(headers: headers)));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send(() => dio.delete(path, data: body));

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{'data': data};
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) throw ApiError.offline();
      final error = ApiError.fromBody(response.data, response.statusCode);
      if (error.isUnauthenticated && session.token != null) {
        await session.setToken(null);
        onSignedOut?.call();
      }
      throw error;
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.fromEntries(query.entries.where((e) => e.value != null && '${e.value}' != ''));
  }
}
