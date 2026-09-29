import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../app.dart' show routerProvider;

/// The website's floating "Talk with CRM" button (layouts/app.blade.php,
/// .eb-chat-fab): brand blue with a white ring, bottom right above the tab
/// bar, the unread count on its corner. On every screen (owner, 29 Sep
/// 2026) -- and opened from a product, the chat starts "About this
/// product" with its link one tap away.
///
/// Signed-in customers only, as on the website: a guest has no manager yet.
/// Not on the chat itself, nor on the sign-in screens, nor while typing
/// (it would sit on the keyboard's edge).
class ChatFab extends ConsumerWidget {
  const ChatFab({super.key});

  static const _hiddenOn = ['/chat', '/login', '/register', '/forgot', '/verify-phone', '/search'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final signedIn = ref.watch(authProvider).value != null;
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        final typing = MediaQuery.of(context).viewInsets.bottom > 0;
        if (!signedIn || typing || _hiddenOn.any((p) => path == p || path.startsWith('$p/'))) return const SizedBox.shrink();

        final product = RegExp(r'^/product/(\d+)$').firstMatch(path)?.group(1);
        final unread = ref.watch(unreadMessagesProvider).value ?? 0;
        // Clears the tab bar (and the product page's Add to Cart bar).
        final bottom = MediaQuery.of(context).padding.bottom + (product != null ? 84.0 : 72.0);

        return Positioned(
          right: 14,
          bottom: bottom,
          // No Tooltip: this sits above the Navigator, outside any Overlay.
          child: Semantics(
            button: true,
            label: 'Chat with your relationship manager',
            child: Material(
              color: Brand.blue,
              shape: const CircleBorder(side: BorderSide(color: Color(0xD9FFFFFF), width: 2)),
              elevation: 6,
              shadowColor: const Color(0x590D476C),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => router.push(product == null ? '/chat' : '/chat?product=$product'),
                child: Badge(
                  isLabelVisible: unread > 0,
                  backgroundColor: const Color(0xFFDC2626),
                  offset: const Offset(6, -6),
                  label: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  child: const Padding(padding: EdgeInsets.all(13), child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
