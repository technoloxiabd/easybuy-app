import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'catalog_screens.dart' show QtyStepper;

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (async.value?.isEmpty == false)
            IconButton(
              tooltip: 'Empty cart',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await confirm(context, 'Empty the cart?', 'Every item will be removed.');
                if (ok && context.mounted) await _guard(context, () => ref.read(cartProvider.notifier).clear());
              },
            ),
        ],
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(cartProvider)),
        data: (cart) => cart.isEmpty
            ? EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                body: 'Find products from China at wholesale prices.',
                action: FilledButton(onPressed: () => context.go('/'), child: const Text('Start shopping')),
              )
            : _CartBody(cart: cart),
      ),
    );
  }
}

Future<void> _guard(BuildContext context, Future<void> Function() task) async {
  try {
    await task();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    ) ??
    false;

class _CartBody extends ConsumerWidget {
  const _CartBody({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final groups = <int, List<CartItem>>{};
    for (final item in cart.items) {
      groups.putIfAbsent(item.productId, () => []).add(item);
    }
    final allSelected = cart.items.every((i) => i.isSelected);

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            for (final w in cart.warnings) Padding(padding: const EdgeInsets.only(bottom: 8), child: NoticeBox(w.message)),
            for (final entry in groups.entries) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ProductGroup(lines: entry.value)),
            _CouponBox(coupon: cart.coupon),
            const SizedBox(height: 8),
            Text(
              'Only ticked items are ordered; the rest stay in your cart for later.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ]),
        ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          color: Colors.white,
          child: Row(children: [
            Checkbox(value: allSelected, onChanged: (v) => _guard(context, () => notifier.selectAll(v ?? false))),
            const Text('All'),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(Money.bdt(cart.selectedTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.orange)),
              Text('${cart.selectedCount} pcs selected', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: FilledButton(
                onPressed: cart.selectedCount == 0 ? null : () => context.push('/checkout'),
                child: const Text('Checkout'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _ProductGroup extends ConsumerWidget {
  const _ProductGroup({required this.lines});
  final List<CartItem> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final head = lines.first;
    final allSelected = lines.every((l) => l.isSelected);
    final unavailable = lines.any((l) => !l.isAvailable);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => context.push('/product/${head.productId}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: Row(children: [
              Checkbox(value: allSelected, onChanged: (v) => _guard(context, () => notifier.selectAll(v ?? false, productId: head.productId))),
              SizedBox(width: 48, height: 48, child: NetImage(head.imageUrl, radius: 8)),
              const SizedBox(width: 10),
              Expanded(child: Text(head.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
          ),
        ),
        if (unavailable)
          Container(
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: const Text('Sold out — no longer available from the supplier. Remove it (or untick it) to place your order.',
                style: TextStyle(color: Brand.danger, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        const Divider(height: 1),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
            child: Row(children: [
              Checkbox(value: line.isSelected, onChanged: (v) => _guard(context, () => notifier.setSelected(line.id, v ?? false))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(line.attributes.isEmpty ? 'Standard' : Attribute.describe(line.attributes), style: const TextStyle(fontSize: 13)),
                  Text('${Money.bdt(line.unitPrice)} × ${line.quantity} = ${Money.bdt(line.lineTotal)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ]),
              ),
              QtyStepper(value: line.quantity, min: 0, onChanged: (n) => _guard(context, () => n == 0 ? notifier.remove(line.id) : notifier.setQuantity(line.id, n))),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _guard(context, () => notifier.remove(line.id)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _CouponBox extends ConsumerStatefulWidget {
  const _CouponBox({required this.coupon});
  final CouponState? coupon;

  @override
  ConsumerState<_CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends ConsumerState<_CouponBox> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final notifier = ref.read(cartProvider.notifier);
    if (coupon != null) {
      return SectionCard(
        child: Row(children: [
          Icon(coupon.isValid ? Icons.local_offer : Icons.error_outline, color: coupon.isValid ? Brand.success : Brand.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Coupon ${coupon.code}${coupon.label != null ? ' — ${coupon.label}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (!coupon.isValid && coupon.message != null) Text(coupon.message!, style: const TextStyle(color: Brand.danger, fontSize: 12)),
            ]),
          ),
          TextButton(onPressed: () => _guard(context, notifier.removeCoupon), child: const Text('Remove')),
        ]),
      );
    }
    return SectionCard(
      child: Row(children: [
        Expanded(child: TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Coupon code', isDense: true))),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: BusyButton(label: 'Apply', outlined: true, onPressed: () async {
            if (_code.text.trim().isEmpty) return;
            await notifier.applyCoupon(_code.text.trim());
            _code.clear();
          }),
        ),
      ]),
    );
  }
}
