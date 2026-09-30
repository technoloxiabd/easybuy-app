import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../app.dart' show routerProvider;
import '../screens/product_screen.dart' show productProvider;
import 'common.dart' show NetImage;

/// The website's floating "Talk with CRM" button (layouts/app.blade.php,
/// .eb-chat-fab): brand blue with a white ring, bottom right above the tab
/// bar, the unread count on its corner. On every screen (owner, 29 Sep
/// 2026) -- and on a product it first asks whether to send that product
/// to the manager (owner, 1 Oct 2026), as the website's "Talk with CRM
/// about this product" does.
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
                onTap: () => product == null ? router.push('/chat') : _askAboutProduct(ref, router, int.parse(product)),
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

  /// "Send this product and start chatting?" -- yes opens the chat and
  /// sends the product's card as the first message; no opens the chat as
  /// it is.
  Future<void> _askAboutProduct(WidgetRef ref, GoRouter router, int id) async {
    // This button sits above the Navigator: the sheet goes on the router's.
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    final p = ref.read(productProvider(id)).value;
    final share = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Chat about this product?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.ink)),
            const SizedBox(height: 4),
            const Text("We'll send its details to your relationship manager so they know which one you mean.",
                style: TextStyle(fontSize: 14, color: Brand.grayText, height: 1.4)),
            if (p != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  if (p.images.isNotEmpty) SizedBox(width: 56, height: 56, child: NetImage(p.images.first, radius: 8)),
                  if (p.images.isNotEmpty) const SizedBox(width: 12),
                  Expanded(child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3))),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheet, true),
              style: FilledButton.styleFrom(backgroundColor: Brand.blue, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send product & chat', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheet, false),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Just chat'),
            ),
          ]),
        ),
      ),
    );
    if (share == null) return;
    router.push(share ? '/chat?product=$id&share=1' : '/chat');
  }
}
