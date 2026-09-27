import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/api.dart';

/// Push notifications, when Firebase is configured for this build.
///
/// Configured from build-time defines (see [options]); a build without them
/// simply has no push -- everything else works.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _ready = false;
  String? _token;
  final _taps = StreamController<Map<String, dynamic>>.broadcast();
  final _foreground = StreamController<RemoteMessage>.broadcast();

  /// `data` of a notification the customer tapped: {type, order_number…}.
  Stream<Map<String, dynamic>> get taps => _taps.stream;

  /// Messages that arrive while the app is open (no system banner then).
  Stream<RemoteMessage> get foreground => _foreground.stream;

  /// The Firebase app settings, passed at build time (Codemagic env vars ->
  /// --dart-define). They are identifiers, not secrets -- every copy of the
  /// app carries them -- but keeping them out of git keeps one repo usable
  /// against a test and a live Firebase project.
  static FirebaseOptions? options() {
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
    final ios = !kIsWeb && Platform.isIOS;
    final apiKey = ios ? const String.fromEnvironment('FIREBASE_IOS_API_KEY') : const String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    final appId = ios ? const String.fromEnvironment('FIREBASE_IOS_APP_ID') : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    if (projectId.isEmpty || senderId.isEmpty || apiKey.isEmpty || appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: ios ? 'bd.com.easybuy.app' : null,
    );
  }

  Future<void> init() async {
    final opts = options();
    if (opts == null) {
      debugPrint('Push disabled: no Firebase settings in this build');
      return;
    }
    try {
      await Firebase.initializeApp(options: opts);
      _ready = true;
    } catch (e) {
      debugPrint('Push disabled: Firebase is not configured ($e)');
      return;
    }

    FirebaseMessaging.onMessage.listen(_foreground.add);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(m.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // After the first frame, once the router is listening.
      Future.delayed(const Duration(milliseconds: 600), () => _taps.add(initial.data));
    }
  }

  /// After sign-in: ask permission once, then tell the server this phone.
  Future<void> register(EasyBuyApi api, String appVersion) async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await api.registerDevice(_token!, Platform.isIOS ? 'ios' : 'android', appVersion);

      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        api.registerDevice(t, Platform.isIOS ? 'ios' : 'android', appVersion).ignore();
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Before sign-out, so the next person on this phone gets no pushes of ours.
  Future<void> unregister(EasyBuyApi api) async {
    final token = _token;
    if (!_ready || token == null) return;
    try {
      await api.unregisterDevice(token);
    } catch (_) {
      // Signing out removes the device on the server anyway.
    }
  }
}
