import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';
import 'catalog_screens.dart' show QtyStepper;

/// The website's cart page (cart/show.blade.php), section for section: the
/// header card, select-all, one card per product with its option rows and
/// subtotal, the order summary with the coupon and the advance split, and
/// the shipping and delivery choice -- asked HERE, as the website asks it,
/// before Proceed to Checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cartProvider);
    return Scaffold(
      appBar: const SiteHeader(),
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    ) ??
    false;

/// The website's round green tick.
class RoundCheck extends StatelessWidget {
  const RoundCheck({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: () => onChanged(!value),
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF16A34A) : Colors.white,
              border: Border.all(color: value ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB), width: 1.6),
            ),
            child: value ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
          ),
        ),
      );
}

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
    final selectedLines = cart.items.where((i) => i.isSelected).length;
    final allSelected = selectedLines == cart.items.length;
    final pcs = cart.items.fold(0, (a, i) => a + i.quantity);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        // ---- header card
        WebCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            if (context.canPop()) ...[
              Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.pop(),
                  child: const SizedBox(width: 40, height: 40, child: Icon(Icons.chevron_left, size: 26)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Flexible(child: Text('Shopping Cart', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
              child: Text('${groups.length} ${groups.length == 1 ? 'item' : 'items'} · $pcs pcs',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Brand.blue)),
            ),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Brand.danger, padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () async {
                final ok = await confirm(context, 'Clear the cart?', 'Every item will be removed.');
                if (ok && context.mounted) await _guard(context, notifier.clear);
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Clear cart', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // ---- select all
        WebCard(
          padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
          child: Row(children: [
            RoundCheck(value: allSelected, onChanged: (v) => _guard(context, () => notifier.selectAll(v))),
            Text(allSelected ? 'Unselect all' : 'Select all', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            Text('$selectedLines/${cart.items.length} selected for this order', style: const TextStyle(fontSize: 12.5, color: Brand.grayText, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        for (final w in cart.warnings) Padding(padding: const EdgeInsets.only(bottom: 10), child: NoticeBox(w.message)),
        // ---- one card per product
        for (final entry in groups.entries) Padding(padding: const EdgeInsets.only(bottom: 14), child: _ProductCard(lines: entry.value)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Continue shopping', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        _OrderSummary(cart: cart, products: groups.length),
        if (cart.shippingMethods.isNotEmpty) ...[const SizedBox(height: 14), _ShippingChoice(cart: cart)],
        if (cart.deliveryMethods.isNotEmpty) ...[const SizedBox(height: 14), _DeliveryChoice(cart: cart)],
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Brand.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: selectedLines == 0
                ? null
                : () {
                    // The website sends a missing delivery choice back here
                    // with this sentence; the app says it before leaving.
                    if (cart.deliveryChoiceRequired && (cart.deliveryMethod == null || cart.deliveryMethod!.isEmpty)) {
                      showMessage(context, 'Please choose a delivery method before checkout.', error: true);
                      return;
                    }
                    context.push('/checkout');
                  },
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(width: 6),
              Icon(Icons.chevron_right),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        const SecureCheckoutNote(),
      ]),
    );
  }
}

/// "Secure checkout", under the orange button.
class SecureCheckoutNote extends StatelessWidget {
  const SecureCheckoutNote({super.key});

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text('Secure checkout', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
      ]);
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.lines});
  final List<CartItem> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final head = lines.first;
    final allSelected = lines.every((l) => l.isSelected);
    final unavailable = lines.any((l) => !l.isAvailable);
    final chosen = lines.where((l) => l.isSelected);
    final pcs = chosen.fold(0, (a, l) => a + l.quantity);
    final subtotal = chosen.fold(0.0, (a, l) => a + (double.tryParse(l.lineTotal) ?? 0));

    return WebCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Row(children: [
            RoundCheck(value: allSelected, onChanged: (v) => _guard(context, () => notifier.selectAll(v, productId: head.productId))),
            SizedBox(width: 48, height: 48, child: NetImage(head.imageUrl, radius: 8)),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/product/${head.productId}'),
                child: Text(head.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.layers_outlined, size: 14, color: Brand.blue),
                const SizedBox(width: 3),
                Text('${lines.length} ${lines.length == 1 ? 'variant' : 'variants'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Brand.blue)),
              ]),
            ),
            IconButton(
              tooltip: 'Remove product',
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade500),
              onPressed: () async {
                final ok = await confirm(context, 'Remove product?', 'Every option of this product will be removed from your cart.');
                if (!ok || !context.mounted) return;
                await _guard(context, () async {
                  for (final l in lines) {
                    await notifier.remove(l.id);
                  }
                });
              },
            ),
          ]),
        ),
        if (unavailable)
          Container(
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Text('Sold out — no longer available from the supplier. Remove it (or untick it) to place your order.',
                style: TextStyle(color: Brand.danger, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        for (final line in lines) _LineRow(line: line),
        Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('Subtotal', style: TextStyle(color: Colors.grey.shade600)),
            Text(' · $pcs pcs', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(Money.bdt('$subtotal'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Brand.orange)),
          ]),
        ),
      ]),
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({required this.line});
  final CartItem line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: RoundCheck(value: line.isSelected, onChanged: (v) => _guard(context, () => notifier.setSelected(line.id, v))),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 64, height: 64, child: NetImage(line.imageUrl, radius: 8)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Each chosen option as its own highlighted chip.
                  for (final a in line.attributes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF3F4F6))),
                      child: Text.rich(
                        TextSpan(children: [
                          if (a.label.isNotEmpty) TextSpan(text: '${a.label}: ', style: const TextStyle(color: Color(0xFF9CA3AF))),
                          TextSpan(text: a.value, style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink)),
                        ]),
                        style: const TextStyle(fontSize: 14, height: 1.35),
                      ),
                    ),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: Money.bdt(line.unitPrice), style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' / pc', style: TextStyle(color: Color(0xFF9CA3AF))),
                  ]), style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              QtyStepper(value: line.quantity, min: 0, onChanged: (n) => _guard(context, () => n == 0 ? notifier.remove(line.id) : notifier.setQuantity(line.id, n))),
              const Spacer(),
              Text(Money.bdt(line.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade500),
                onPressed: () => _guard(context, () => notifier.remove(line.id)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// The order summary of the TICKED lines, with the coupon, the advance split
/// and the Bengali pay-now/pay-later notice -- the website's cart summary.
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart, required this.products});
  final Cart cart;
  final int products;

  @override
  Widget build(BuildContext context) {
    final s = cart.summary;
    final selectedProducts = s?.selectedProducts ?? products;
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Order summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        SummaryRow('Selected ($selectedProducts ${selectedProducts == 1 ? 'item' : 'items'} · ${cart.selectedCount} pcs)', Money.bdt(cart.selectedTotal)),
        const SummaryRow('Shipping (CN→BD)', 'Charged by weight later', muted: true),
        // The seller's own courier to our China warehouse: unknown until the
        // parcel arrives, so carried at zero, as the website shows it.
        const SummaryRow('China Courier Charge', '৳0.00', muted: true),
        const DashedDivider(),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Expanded(child: Text('Total (selected goods)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)))),
          Text(Money.bdt(cart.selectedTotal), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.orange)),
        ]),
        DiscountRows(campaign: s?.campaign, coupon: cart.coupon, total: cart.selectedTotal, net: s?.netGoods),
        const SizedBox(height: 14),
        _CouponBox(coupon: cart.coupon),
        if (s != null && s.hasAdvance) ...[
          const SizedBox(height: 12),
          AdvanceDue(now: s.dueNow, later: s.dueLater, percent: s.advancePercent, total: s.netGoods, discounted: s.netGoods != cart.selectedTotal),
        ],
        if (s != null) ...[
          const SizedBox(height: 12),
          GoodsNotice(now: s.dueNow, later: s.dueLater, percent: s.advancePercent),
        ],
      ]),
    );
  }
}

class _ShippingChoice extends ConsumerWidget {
  const _ShippingChoice({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final methods = cart.shippingMethods;
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Shipping method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          for (final (i, m) in methods.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: ChoiceTile(
                selected: m.name == cart.shippingMethod,
                enabled: m.isAvailable,
                icon: m.name.toLowerCase().contains('sea') ? Icons.directions_boat_outlined : Icons.send_outlined,
                label: m.name,
                note: !m.isAvailable && m.minAmount != null ? 'From ${Money.bdt(m.minAmount)}' : null,
                onTap: () => _guard(context, () => notifier.setMethods(shipping: m.name)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _DeliveryChoice extends ConsumerWidget {
  const _DeliveryChoice({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final none = cart.deliveryMethod == null || cart.deliveryMethod!.isEmpty;
    final chosen = cart.deliveryMethods.where((d) => d.name == cart.deliveryMethod).firstOrNull;
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Delivery method'),
          if (cart.deliveryChoiceRequired) const TextSpan(text: ' *', style: TextStyle(color: Brand.danger)),
        ]), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (cart.deliveryChoiceRequired && none)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Please choose how you want to receive your parcel.', style: TextStyle(color: Brand.danger, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 12),
        for (final d in cart.deliveryMethods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(
              selected: d.name == cart.deliveryMethod,
              label: d.name,
              radio: true,
              onTap: () => _guard(context, () => notifier.setMethods(delivery: d.name)),
            ),
          ),
        if (chosen?.note != null) InfoNote(chosen!.note!),
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
    final notifier = ref.read(cartProvider.notifier);
    if (widget.coupon != null) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => _guard(context, notifier.removeCoupon), child: Text('Remove coupon ${widget.coupon!.code}')),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(letterSpacing: 1.2),
            decoration: const InputDecoration(hintText: 'COUPON CODE', isDense: true),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: BusyButton(label: 'Apply', outlined: false, color: Brand.blue, onPressed: () async {
            if (_code.text.trim().isEmpty) return;
            await notifier.applyCoupon(_code.text.trim());
            _code.clear();
          }),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ shared with checkout

/// A label/value line in an order summary.
class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key, this.muted = false});
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)))),
          Text(value, style: muted ? TextStyle(fontSize: 13, color: Colors.grey.shade500) : const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      );
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: LayoutBuilder(builder: (context, box) {
          final n = (box.maxWidth / 8).floor();
          return Row(children: [for (var i = 0; i < n; i++) Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 2), color: const Color(0xFFE5E7EB)))]);
        }),
      );
}

/// The campaign and coupon rows and the after-discount total
/// (partials/discount-summary).
class DiscountRows extends StatelessWidget {
  const DiscountRows({super.key, this.campaign, this.coupon, required this.total, this.net});
  final Json? campaign;
  final CouponState? coupon;
  final String total;
  final String? net;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final discounted = net != null && Money.isPositive('${(double.tryParse(total) ?? 0) - (double.tryParse(net!) ?? 0)}');
    Widget band(Color bg, Color fg, String left, [String? right]) => Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text(left, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13.5))),
            if (right != null) Text(right, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c != null && c['applies'] == true) band(const Color(0xFFFEF2F2), const Color(0xFFB91C1C), '${c['title']} — ${c['label']}', '− ${Money.bdt('${c['discount_bdt']}')}'),
      if (c != null && c['applies'] != true && c['min_order_amount_bdt'] != null)
        band(const Color(0xFFFFFBEB), const Color(0xFF92400E),
            'Add ${Money.bdt('${(double.tryParse('${c['min_order_amount_bdt']}') ?? 0) - (double.tryParse(total) ?? 0)}')} more to unlock ${c['label']} (${c['title']}).'),
      if (coupon != null && coupon!.isValid)
        band(const Color(0xFFF0FDF4), const Color(0xFF15803D), 'Coupon ${coupon!.code}${coupon!.label != null ? ' — ${coupon!.label}' : ''}', '− ${Money.bdt(coupon!.discount)}'),
      if (coupon != null && !coupon!.isValid) band(const Color(0xFFFEF2F2), const Color(0xFFB91C1C), 'Coupon ${coupon!.code}: ${coupon!.message ?? 'not applied'}'),
      if (discounted)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            const Expanded(child: Text('After discount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Text(Money.bdt(net), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Brand.orange)),
          ]),
        ),
    ]);
  }
}

/// "Net payable now" and the rest on delivery (partials/advance-due).
class AdvanceDue extends StatelessWidget {
  const AdvanceDue({super.key, required this.now, required this.later, this.percent, required this.total, this.discounted = false});
  final String now;
  final String later;
  final String? percent;
  final String total;
  final bool discounted;

  @override
  Widget build(BuildContext context) {
    final restRemains = Money.isPositive(later);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFED7AA))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Net payable now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink))),
          Text(Money.bdt(now), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Brand.orange)),
        ]),
        if (restRemains) ...[
          const Divider(color: Color(0xFFFED7AA), height: 16),
          Row(children: [
            const Expanded(child: Text('Rest to pay on delivery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF4B5563)))),
            Text(Money.bdt(later), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink)),
          ]),
        ],
        if (percent != null && percent != '0')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$percent%', style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.orange)),
              TextSpan(text: ' of ${Money.bdt(total)}${discounted ? ' (after discount)' : ''}${restRemains ? '.' : ' — the full amount payable now.'}'),
            ]), style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          ),
      ]),
    );
  }
}

/// The Bengali pay-now / pay-later notice (partials/goods-notice).
class GoodsNotice extends StatelessWidget {
  const GoodsNotice({super.key, required this.now, required this.later, this.percent});
  final String now;
  final String later;
  final String? percent;

  static const _hl = TextStyle(fontWeight: FontWeight.w800, color: Brand.orange);

  @override
  Widget build(BuildContext context) {
    final rest = Money.isPositive(later);
    final pct = double.tryParse(percent ?? '');
    final hasPct = pct != null && pct > 0;
    String restPct() {
      final r = 100 - pct!;
      return Money.bn(r == r.roundToDouble() ? r.round() : r);
    }

    final paragraphs = rest
        ? [
            [
              const TextSpan(text: 'আপনাকে এখন শুধুমাত্র পণ্যের মূল্যের '),
              TextSpan(text: '${hasPct ? '[${Money.bn(percent!)}%] - ' : ''}${Money.bdt(now)}', style: _hl),
              const TextSpan(text: ' পরিশোধ করতে হবে।'),
            ],
            [
              const TextSpan(text: 'আপনার পার্সেলটি আমাদের চায়না এবং পরে ঢাকা ওয়্যারহাউসে পৌঁছানোর পর চায়নার ডোমেস্টিক কুরিয়ার চার্জ ও প্রকৃত ওজন অনুযায়ী চায়না→ঢাকা শিপিং চার্জ ধার্য করে বাকী '),
              TextSpan(text: '${hasPct ? '[${restPct()}%] - ' : ''}${Money.bdt(later)}', style: _hl),
              const TextSpan(text: ' সাথে যোগ করে মোট বকেয়া ডেলিভারির সময় পরিশোধ করতে হবে।'),
            ],
          ]
        : [
            [
              const TextSpan(text: 'আপনাকে এখন পণ্যের মূল্য '),
              TextSpan(text: Money.bdt(now), style: _hl),
              const TextSpan(text: ' পরিশোধ করতে হবে।'),
            ],
            [
              const TextSpan(text: 'আপনার পার্সেলটি আমাদের চায়না এবং পরে ঢাকা ওয়্যারহাউসে পৌঁছানোর পর চায়নার ডোমেস্টিক কুরিয়ার চার্জ ও প্রকৃত ওজন অনুযায়ী চায়না→ঢাকা শিপিং চার্জ ধার্য করা হবে, যা ডেলিভারির সময় পরিশোধ করতে হবে।'),
            ],
          ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, p) in paragraphs.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Text.rich(TextSpan(children: p), style: const TextStyle(fontSize: 15, height: 1.65, color: Brand.blue)),
          ),
      ]),
    );
  }
}

/// A bordered choice: a shipping tile, a delivery or payment option.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.selected, required this.label, required this.onTap, this.enabled = true, this.icon, this.note, this.radio = true, this.trailing, this.child, this.details});
  final bool selected;
  final bool enabled;
  final String label;
  final IconData? icon;
  final String? note;
  final bool radio;
  final Widget? trailing;

  /// Shown under the label while selected (a payment method's details).
  final Widget? child;

  /// Always shown under the label (an address's phone and street).
  final Widget? details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled && !selected ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? Brand.blue : const Color(0xFFE5E7EB), width: selected ? 1.8 : 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  if (radio) ...[
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: selected ? Brand.blue : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 10),
                  ],
                  if (icon != null) ...[Icon(icon, size: 20, color: Brand.ink), const SizedBox(width: 8)],
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Brand.ink))),
                  ?trailing,
                ]),
                if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note!, style: const TextStyle(fontSize: 12, color: Brand.grayText))),
                if (details != null) Padding(padding: EdgeInsets.only(top: 6, left: radio ? 30 : 0), child: details),
                if (selected && child != null) Padding(padding: const EdgeInsets.only(top: 12), child: child),
              ]),
            ),
          ),
        ),
      );
}

/// The blue info box an admin's delivery note sits in.
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.info_outline, size: 17, color: Brand.blue)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.55, color: Brand.blue))),
        ]),
      );
}
