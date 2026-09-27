import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push.dart';
import 'core/session_store.dart';
import 'state/providers.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The saved sign-in and guest cart, before the first screen asks for them.
  final session = SessionStore();
  await session.load();

  // Push, when this build carries the Firebase config; a no-op otherwise.
  await PushService.instance.init();

  runApp(ProviderScope(
    overrides: [sessionStoreProvider.overrideWithValue(session)],
    child: const EasyBuyApp(),
  ));
}
