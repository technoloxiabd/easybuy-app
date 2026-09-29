import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';
import '../widgets/tab_bar.dart';
import 'cart_screen.dart';
import 'order_screens.dart' show openExternal, pickFiles;

/// The website's checkout (checkout/show.blade.php): the order summary,
/// delivery details from the address book, the shipping and delivery chosen
/// on the cart, the account balance, and the PAYMENT METHOD -- chosen before
/// the order is placed, with the transfer reference and receipts, exactly as
/// on the website (owner, 29 Sep 2026: "the order procedure is not the same").
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Checkout? _checkout;
  Object? _error;
  bool _loading = true;

  /// null = a new address typed below.
  int? _addressId;
  bool _addressChosen = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _reference = TextEditingController();
  bool _saveAddress = true;
  bool _useCredit = false;
  int? _methodId;
  final List<String> _proof = [];
  ApiError? _fieldErrors;

  /// One key for this order attempt: a retried tap after a dropped
  /// connection returns the order already placed instead of a second one.
  final _idempotencyKey = EasyBuyApi.newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _notes, _reference]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await ref.read(apiProvider).checkout();
      setState(() {
        _checkout = c;
        _error = null;
        if (!_addressChosen) {
          _addressId = c.defaultAddressId ?? c.addresses.firstOrNull?.id;
          _addressChosen = true;
          final user = ref.read(authProvider).value;
          _name.text = user?.name ?? '';
          _phone.text = user?.phone ?? '';
        }
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  PayMethod? get _method => _checkout?.paymentMethods.where((m) => m.id == _methodId).firstOrNull;

  Future<void> _place() async {
    final c = _checkout!;
    // The website's form requires a method; say so before the round trip.
    if (c.paymentMethods.isNotEmpty && _methodId == null && !(_useCredit && Money.isPositive(c.creditBalance))) {
      showMessage(context, 'Choose how you will pay the advance.', error: true);
      return;
    }
    if (c.termsHtml != null && !await _acceptTerms(c)) return;

    setState(() => _fieldErrors = null);
    try {
      final (order, payment) = await ref.read(apiProvider).placeOrder(
            idempotencyKey: _idempotencyKey,
            addressId: _addressId,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            saveAddress: _saveAddress,
            notes: _notes.text,
            useCredit: _useCredit,
            paymentMethodId: _methodId,
            reference: _method?.collectsReference == true ? _reference.text : null,
            proofPaths: _method?.collectsProof == true ? _proof : const [],
          );
      await ref.read(cartProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/account');
      context.push('/orders/${order.number}');

      // The website's confirmation sentences, by what became of the payment.
      final status = payment?['status'];
      if (status == 'redirect' && payment?['redirect_url'] != null) {
        await openExternal(context, '${payment!['redirect_url']}');
      } else if (status == 'failed') {
        showMessage(context, '${payment?['message']}', error: true);
      } else if (status == 'submitted') {
        showMessage(context, 'আপনার অর্ডারটি সফলভাবে সম্পন্ন হয়েছে। আপনার ${payment?['method']} পেমেন্টটি শীঘ্রই যাচাই করে নিশ্চিত করা হবে।');
      } else {
        showMessage(context, 'আপনার অর্ডারটি সফলভাবে সম্পন্ন হয়েছে।${_useCredit ? ' পেমেন্টটি আপনার অ্যাকাউন্ট ব্যালেন্স থেকে পরিশোধ করা হয়েছে।' : ''}');
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = e);
      showError(context, e);
      // The dry run may have changed (a minimum, a coupon); show it fresh.
      if (e.code != 'validation_failed' && e.code != 'phone_invalid' && e.code != 'payment_method_required') {
        _load();
      }
    }
  }

  Future<bool> _acceptTerms(Checkout c) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (_, scroll) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(c.termsTitle ?? 'Order terms & conditions', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Expanded(child: SingleChildScrollView(controller: scroll, child: Text(plainText(c.termsHtml!), style: const TextStyle(height: 1.45)))),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I agree — place order')),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ]),
          ),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final c = _checkout;
    return Scaffold(
      appBar: const SiteHeader(),
      // The website keeps its tab bar on checkout; no tab is lit there.
      bottomNavigationBar: const PageTabBar(current: null),
      body: c == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView())
          : Stack(children: [
              _body(c),
              if (_loading) const LinearProgressIndicator(),
            ]),
    );
  }

  Widget _body(Checkout c) {
    final phoneBlocked = c.blockers.any((b) => b.code == 'phone_unverified');
    final products = c.lines.map((l) => l.productId).toSet().length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        WebCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Material(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.pop(),
                child: const SizedBox(width: 40, height: 40, child: Icon(Icons.chevron_left, size: 26)),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.blue)),
          ]),
        ),
        const SizedBox(height: 12),
        for (final b in c.blockers) Padding(padding: const EdgeInsets.only(bottom: 10), child: NoticeBox(b.message, tone: NoticeTone.danger)),
        if (phoneBlocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.push('/verify-phone?from=/checkout');
                _load();
              },
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Verify my number'),
            ),
          ),
        _summary(c, products),
        const SizedBox(height: 14),
        _delivery(c),
        const SizedBox(height: 14),
        _shippingAndDelivery(c),
        if (Money.isPositive(c.creditBalance)) ...[
          const SizedBox(height: 14),
          WebCard(
            child: Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _useCredit,
                onChanged: (v) => setState(() => _useCredit = v ?? false),
                title: Text('Use my account balance (${Money.bdt(c.creditBalance)})', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Paid from your balance first; confirmed at once.'),
              ),
            ),
          ),
        ],
        if (c.paymentMethods.isNotEmpty) ...[const SizedBox(height: 14), _payment(c)],
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: BusyButton(label: 'Place order  ›', onPressed: c.canPlace ? _place : null),
        ),
        const SizedBox(height: 10),
        const SecureCheckoutNote(),
      ]),
    );
  }

  // ---------------------------------------------------------------- summary

  Widget _summary(Checkout c, int products) => WebCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Order summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
              child: Text('$products ${products == 1 ? 'item' : 'items'} · ${c.itemCount} pcs', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Brand.blue)),
            ),
          ]),
          const SizedBox(height: 8),
          for (final l in c.lines)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 64, height: 64, child: NetImage(l.imageUrl, radius: 8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
                    for (final a in l.attributes)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFF3F4F6))),
                        child: Text.rich(
                          TextSpan(children: [
                            if (a.label.isNotEmpty) TextSpan(text: '${a.label}: ', style: const TextStyle(color: Color(0xFF9CA3AF))),
                            TextSpan(text: a.value, style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: Money.bdt(l.unitPrice), style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' / pc', style: TextStyle(color: Color(0xFF9CA3AF))),
                      TextSpan(text: ' × ${l.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]), style: const TextStyle(fontSize: 13.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                  child: Text(Money.bdt(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.orange)),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          SummaryRow('Goods ($products ${products == 1 ? 'item' : 'items'} · ${c.itemCount} pcs)', Money.bdt(c.goodsTotal)),
          const SummaryRow('Shipping (CN→BD)', 'Charged by weight later', muted: true),
          const SummaryRow('China Courier Charge', '৳0.00', muted: true),
          const DashedDivider(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: Text('Goods total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            Text(Money.bdt(c.goodsTotal), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.orange)),
          ]),
          DiscountRows(campaign: c.campaign, coupon: c.coupon, total: c.goodsTotal, net: c.netGoods),
          if (c.advancePercent != null || Money.isPositive(c.dueLater)) ...[
            const SizedBox(height: 12),
            AdvanceDue(now: c.dueNow, later: c.dueLater, percent: c.advancePercent, total: c.netGoods, discounted: c.netGoods != c.goodsTotal),
          ],
          const SizedBox(height: 12),
          GoodsNotice(now: c.dueNow, later: c.dueLater, percent: c.advancePercent),
        ]),
      );

  // ---------------------------------------------------------------- delivery details

  Widget _delivery(Checkout c) {
    final err = _fieldErrors;
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Delivery details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: () async {
              await context.push('/account/addresses');
              _load();
            },
            child: const Text('Address book', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final a in c.addresses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(
              selected: _addressId == a.id,
              label: a.name,
              trailing: a.id == c.defaultAddressId
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Default', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Brand.blue)),
                    )
                  : null,
              onTap: () => setState(() => _addressId = a.id),
              details: Text('${a.phone}\n${a.address}', style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF4B5563))),
            ),
          ),
        DottedChoice(
          selected: _addressId == null,
          label: '+ Use a new address',
          onTap: () => setState(() => _addressId = null),
        ),
        if (_addressId == null) ...[
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: 'Recipient name', errorText: err?.fieldError('name'))),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Mobile number', hintText: '01XXXXXXXXX', errorText: err?.fieldError('phone'))),
          const SizedBox(height: 10),
          TextField(controller: _address, maxLines: 3, decoration: InputDecoration(labelText: 'Full address', errorText: err?.fieldError('address'))),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveAddress,
              onChanged: (v) => setState(() => _saveAddress = v ?? true),
              title: const Text('Save to my address book'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'Notes', style: TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: ' (optional)', style: TextStyle(color: Color(0xFF9CA3AF))),
        ]), style: TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        TextField(controller: _notes, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'e.g. a second phone number, colour preferences')),
      ]),
    );
  }

  // ---------------------------------------------------------------- shipping & delivery

  Widget _shippingAndDelivery(Checkout c) {
    final delivery = c.deliveryMethods.where((d) => d.name == c.deliveryMethod).firstOrNull;
    Widget tile(IconData icon, String caption, String value) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 19, color: Brand.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(caption, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF9CA3AF))),
                Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        );
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Shipping & delivery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          // Chosen on the cart, as on the website: Change goes back there.
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 36),
              side: const BorderSide(color: Brand.blue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => context.pop(),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        if (c.shippingMethod != null) tile(Icons.send_outlined, 'SHIPPING METHOD', c.shippingMethod!),
        if (c.deliveryMethod != null) tile(Icons.home_outlined, 'DELIVERY METHOD', c.deliveryMethod!),
        if (delivery?.note != null) InfoNote(delivery!.note!),
      ]),
    );
  }

  // ---------------------------------------------------------------- payment

  Widget _payment(Checkout c) {
    final pct = c.advancePercent;
    final restPct = pct == null ? null : (100 - (double.tryParse(pct) ?? 0));
    String bnPct(num v) => Money.bn(v == v.roundToDouble() ? v.round() : v);
    const hl = TextStyle(fontWeight: FontWeight.w800, color: Brand.orange);
    return WebCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Payment method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFED7AA))),
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'PAYABLE NOW  ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
              TextSpan(text: Money.bdt(c.dueNow), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.orange)),
            ])),
          ),
        ]),
        const SizedBox(height: 12),
        for (final m in c.paymentMethods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(
              selected: _methodId == m.id,
              label: m.name,
              trailing: m.isGateway
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(20)),
                      child: const Text('ONLINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                    )
                  : null,
              onTap: () => setState(() {
                _methodId = m.id;
                _proof.clear();
              }),
              child: _MethodDetails(method: m, reference: _reference, proof: _proof, onChanged: () => setState(() {}), error: _fieldErrors),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'এখন আপনাকে প্রদান করতে হবে: '),
              TextSpan(text: Money.bdt(c.dueNow), style: hl),
              if (pct != null) TextSpan(text: ' (${bnPct(double.tryParse(pct) ?? 0)}%)', style: hl),
              if (Money.isPositive(c.dueLater)) ...[
                const TextSpan(text: ', বাকি '),
                TextSpan(text: Money.bdt(c.dueLater), style: hl),
                if (restPct != null) TextSpan(text: ' (${bnPct(restPct)}%)', style: hl),
                const TextSpan(text: ' ডেলিভারির সময় পরিশোধ করতে হবে।'),
              ] else
                const TextSpan(text: ' — সম্পূর্ণ পণ্যমূল্য।'),
              const TextSpan(text: ' ব্যাংক ডিপোজিট / ম্যানুয়াল পেমেন্ট আমাদের টিমের যাচাইকরণের পর নিশ্চিত করা হবে।'),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF374151)),
          ),
        ),
      ]),
    );
  }
}

/// What a selected method needs: its instructions, the account to pay into
/// (each line copyable), the transfer reference, and the receipts.
class _MethodDetails extends StatelessWidget {
  const _MethodDetails({required this.method, required this.reference, required this.proof, required this.onChanged, this.error});
  final PayMethod method;
  final TextEditingController reference;
  final List<String> proof;
  final VoidCallback onChanged;
  final ApiError? error;

  static const _labels = {
    'account_name': 'Account name',
    'account_number': 'Account',
    'branch_name': 'Branch',
    'routing_number': 'Routing no.',
    'swift_code': 'SWIFT',
  };

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (method.instructions != null) Text(method.instructions!, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF4B5563))),
        if (method.account.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(children: [
              for (final e in method.account.entries)
                Row(children: [
                  Text('${_labels[e.key] ?? e.key}: ', style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280))),
                  Expanded(child: SelectableText(e.value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.copy_rounded, size: 17, color: Colors.grey.shade500),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: e.value));
                      if (context.mounted) showMessage(context, 'Copied');
                    },
                  ),
                ]),
            ]),
          ),
        if (method.collectsReference) ...[
          const SizedBox(height: 10),
          const Text.rich(TextSpan(children: [
            TextSpan(text: 'Transaction reference'),
            TextSpan(text: ' (if you have one)', style: TextStyle(color: Color(0xFF9CA3AF))),
          ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
          const SizedBox(height: 4),
          TextField(
            controller: reference,
            maxLength: 128,
            style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1),
            decoration: InputDecoration(hintText: 'e.g. TrxID 8N7A2K4L', isDense: true, counterText: '', prefixIcon: const Icon(Icons.tag, size: 18), errorText: error?.fieldError('reference')),
          ),
        ],
        if (method.collectsProof) ...[
          const SizedBox(height: 10),
          const Text.rich(TextSpan(children: [
            TextSpan(text: 'Payment proof'),
            TextSpan(text: ' (screenshot or receipt)', style: TextStyle(color: Color(0xFF9CA3AF))),
          ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: proof.length >= 5
                ? null
                : () async {
                    final picked = await pickFiles(context, allowVideo: false);
                    proof.addAll(picked.take(5 - proof.length));
                    onChanged();
                  },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD1D5DB))),
              child: proof.isEmpty
                  ? Column(children: [
                      Icon(Icons.upload_file_outlined, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      const Text('Upload screenshots or receipts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Brand.blue)),
                      Text('Up to 5 files — JPG, PNG, WEBP or PDF · 5 MB each', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ])
                  : Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                      for (final (i, f) in proof.indexed)
                        InputChip(
                          label: Text(f.split('/').last, overflow: TextOverflow.ellipsis),
                          onDeleted: () {
                            proof.removeAt(i);
                            onChanged();
                          },
                        ),
                      if (proof.length < 5) const Chip(avatar: Icon(Icons.add, size: 16), label: Text('Add')),
                    ]),
            ),
          ),
        ],
      ]);
}

/// A dashed-border choice, the website's "+ Use a new address".
class DottedChoice extends StatelessWidget {
  const DottedChoice({super.key, required this.selected, required this.label, required this.onTap});
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedBorder(color: selected ? Brand.blue : const Color(0xFFD1D5DB)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: selected ? Brand.blue : const Color(0xFF9CA3AF)),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              ]),
            ),
          ),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// The admin's terms arrive as rich-text HTML; the app shows them as text.
String plainText(String html) => html
    .replaceAll(RegExp(r'<(br|/p|/li|/h\d)[^>]*>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
