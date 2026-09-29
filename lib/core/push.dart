import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  /// Shows a message that arrives while the app is open in the notification
  /// bar too. Android leaves that to the app (it only draws notifications
  /// for an app in the background); iOS is told to via
  /// setForegroundNotificationPresentationOptions instead.
  final _local = FlutterLocalNotificationsPlugin();

  /// The channel MainActivity creates and the server names in every push.
  static const _channel = AndroidNotificationDetails(
    'updates',
    'Order and message updates',
    channelDescription: 'Order status, payments and replies from EasyBuy',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// `data` of a notification the customer tapped: {type, order_number…}.
  Stream<Map<String, dynamic>> get taps => _taps.stream;

  /// Messages that arrive while the app is open (also shown in the bar).
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

    if (Platform.isAndroid) {
      await _local.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        // Tapping it goes where tapping a background push goes.
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        },
      );
    } else {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    }

    FirebaseMessaging.onMessage.listen((m) {
      _foreground.add(m);
      _showInBar(m);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(m.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // After the first frame, once the router is listening.
      Future.delayed(const Duration(milliseconds: 600), () => _taps.add(initial.data));
    }
  }

  void _showInBar(RemoteMessage m) {
    final n = m.notification;
    if (!Platform.isAndroid || n == null) return;
    _local
        .show(
          id: m.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: n.title,
          body: n.body,
          notificationDetails: const NotificationDetails(android: _channel),
          payload: jsonEncode(m.data),
        )
        .ignore();
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
