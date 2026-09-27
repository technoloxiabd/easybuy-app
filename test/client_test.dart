import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easybuy/core/api_client.dart';
import 'package:easybuy/core/api_error.dart';
import 'package:easybuy/core/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session without the platform keystore.
class MemorySession extends SessionStore {
  String? _t;
  String? _c;
  @override
  String? get token => _t;
  @override
  String? get cartToken => _c;
  @override
  Future<void> setToken(String? v) async => _t = v;
  @override
  Future<void> setCartToken(String? v) async => _c = v;
  @override
  Future<void> load() async {}
}

/// Answers every request with one canned response and remembers the request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body, {this.headers = const {}});
  final int status;
  final Object body;
  final Map<String, List<String>> headers;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

(ApiClient, FakeAdapter, MemorySession) make(int status, Object body, {Map<String, List<String>> headers = const {}}) {
  final session = MemorySession();
  final adapter = FakeAdapter(status, body, headers: headers);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))..httpClientAdapter = adapter;
  return (ApiClient(session, dio: dio), adapter, session);
}

void main() {
  test('sends the bearer token and the guest cart token', () async {
    final (client, adapter, session) = make(200, {'data': []});
    await session.setToken('tok-1');
    await session.setCartToken('cart-1');

    await client.get('/cart');

    expect(adapter.last!.headers['Authorization'], 'Bearer tok-1');
    expect(adapter.last!.headers['X-Cart-Token'], 'cart-1');
  });

  test('keeps a cart token the server issues', () async {
    final (client, _, session) = make(201, {'data': {}}, headers: {'X-Cart-Token': ['issued-123']});

    await client.post('/cart/items', body: {'product_id': 1});

    expect(session.cartToken, 'issued-123');
  });

  test('turns the error envelope into an ApiError with field errors', () async {
    final (client, _, _) = make(422, {
      'code': 'validation_failed',
      'message': 'The phone field is required.',
      'errors': {'phone': ['The phone field is required.']},
    });

    await expectLater(
      client.post('/auth/register'),
      throwsA(isA<ApiError>()
          .having((e) => e.code, 'code', 'validation_failed')
          .having((e) => e.fieldError('phone'), 'phone', 'The phone field is required.')),
    );
  });

  test('a refused business rule keeps its code and meta', () async {
    final (client, _, _) = make(422, {'code': 'phone_invalid', 'message': 'Enter one valid number', 'meta': {'field': 'phone'}});

    await expectLater(
      client.post('/checkout'),
      throwsA(isA<ApiError>().having((e) => e.fieldError('phone'), 'field', 'Enter one valid number')),
    );
  });

  test('a 401 forgets the token and tells the session', () async {
    final (client, _, session) = make(401, {'code': 'unauthenticated', 'message': 'Please sign in again.'});
    await session.setToken('expired');
    var told = false;
    client.onSignedOut = () => told = true;

    await expectLater(client.get('/auth/me'), throwsA(isA<ApiError>()));

    expect(session.token, isNull);
    expect(told, isTrue);
  });
}
