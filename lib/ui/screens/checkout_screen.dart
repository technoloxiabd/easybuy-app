import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

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
  bool _saveAddress = true;
  bool _useCredit = false;
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
    for (final c in [_name, _phone, _address, _notes]) {
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

  Future<void> _choose({String? shipping, String? delivery}) async {
    try {
      final c = await ref.read(apiProvider).chooseMethods(shipping: shipping, delivery: delivery);
      setState(() => _checkout = c);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _place() async {
    final c = _checkout!;
    if (c.termsHtml != null && !await _acceptTerms(c)) return;

    setState(() => _fieldErrors = null);
    try {
      final order = await ref.read(apiProvider).placeOrder(
            idempotencyKey: _idempotencyKey,
            addressId: _addressId,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            saveAddress: _saveAddress,
            notes: _notes.text,
            useCredit: _useCredit,
          );
      await ref.read(cartProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/account');
      context.push('/orders/${order.number}');
      if (order.nextPayment != null) context.push('/orders/${order.number}/pay');
      showMessage(context, 'Order ${order.number} placed. Thank you!');
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = e);
      showError(context, e);
      // The dry run may have changed (a minimum, a coupon); show it fresh.
      if (e.code != 'validation_failed' && e.code != 'phone_invalid') _load();
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
      appBar: AppBar(title: const Text('Checkout')),
      body: c == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView())
          : Stack(children: [
              _body(c),
              if (_loading) const LinearProgressIndicator(),
            ]),
      bottomNavigationBar: c == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('Pay now', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(Money.bdt(c.dueNow), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.orange)),
                  ]),
                  const SizedBox(height: 8),
                  BusyButton(label: 'Place order', onPressed: c.canPlace ? _place : null),
                ]),
              ),
            ),
    );
  }

  Widget _body(Checkout c) {
    final phoneBlocked = c.blockers.any((b) => b.code == 'phone_unverified');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final b in c.blockers) Padding(padding: const EdgeInsets.only(bottom: 8), child: NoticeBox(b.message, tone: NoticeTone.danger)),
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
        SectionCard(
          title: 'Items (${c.itemCount} pcs)',
          child: Column(children: [
            for (final l in c.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 40, height: 40, child: NetImage(l.imageUrl, radius: 6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      Text('${l.attributes.isEmpty ? '' : '${Attribute.describe(l.attributes)} · '}× ${l.quantity}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ]),
                  ),
                  Text(Money.bdt(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        _addressSection(c),
        const SizedBox(height: 10),
        if (c.shippingMethods.isNotEmpty) ...[
          SectionCard(
            title: 'Shipping from China',
            child: RadioGroup<String>(
              groupValue: c.shippingMethod,
              onChanged: (v) => v == null ? null : _choose(shipping: v),
              child: Column(children: [
                for (final m in c.shippingMethods)
                  _ShippingOption(method: m, selected: m.name == c.shippingMethod),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (c.deliveryMethods.isNotEmpty) ...[
          SectionCard(
            title: 'Delivery in Bangladesh',
            child: RadioGroup<String>(
              groupValue: c.deliveryMethod,
              onChanged: (v) => v == null ? null : _choose(delivery: v),
              child: Column(children: [
                for (final d in c.deliveryMethods)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: d.name,
                    title: Text(d.name),
                    subtitle: d.note != null && d.name == c.deliveryMethod ? Text(d.note!, style: const TextStyle(fontSize: 12)) : null,
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SectionCard(
          title: 'Note for our team (optional)',
          child: TextField(controller: _notes, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'e.g. a second phone number, colour preferences')),
        ),
        const SizedBox(height: 10),
        _totals(c),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _addressSection(Checkout c) {
    final err = _fieldErrors;
    return SectionCard(
      title: 'Delivery address',
      child: RadioGroup<int?>(
        groupValue: _addressId,
        onChanged: (v) => setState(() => _addressId = v),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final a in c.addresses)
            RadioListTile<int?>(
              contentPadding: EdgeInsets.zero,
              value: a.id,
              title: Text('${a.label != null ? '${a.label} · ' : ''}${a.name} · ${a.phone}', style: const TextStyle(fontSize: 14)),
              subtitle: Text(a.address, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const RadioListTile<int?>(contentPadding: EdgeInsets.zero, value: null, title: Text('A new address')),
          if (_addressId == null) ...[
            TextField(controller: _name, decoration: InputDecoration(labelText: 'Recipient name', errorText: err?.fieldError('name'))),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Mobile number', hintText: '01XXXXXXXXX', errorText: err?.fieldError('phone'))),
            const SizedBox(height: 10),
            TextField(controller: _address, maxLines: 3, decoration: InputDecoration(labelText: 'Full address', errorText: err?.fieldError('address'))),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveAddress,
              onChanged: (v) => setState(() => _saveAddress = v ?? true),
              title: const Text('Save to my address book'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _totals(Checkout c) {
    final campaign = c.campaign;
    return SectionCard(
      title: 'Payment summary',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LabelValue('Goods', Money.bdt(c.goodsTotal)),
        if (campaign != null && campaign['applies'] == true)
          LabelValue('${campaign['title']} (${campaign['label']})', '− ${Money.bdt('${campaign['discount_bdt']}')}', valueColor: Brand.success),
        if (campaign != null && campaign['applies'] != true && campaign['min_order_amount_bdt'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: NoticeBox('Order ${Money.bdt('${campaign['min_order_amount_bdt']}')} or more to get ${campaign['label']} (${campaign['title']}).', tone: NoticeTone.info),
          ),
        if (c.coupon != null)
          c.coupon!.isValid
              ? LabelValue('Coupon ${c.coupon!.code}', '− ${Money.bdt(c.coupon!.discount)}', valueColor: Brand.success)
              : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: NoticeBox(c.coupon!.message ?? 'Coupon not applied', tone: NoticeTone.danger)),
        const Divider(),
        LabelValue('Goods total', Money.bdt(c.netGoods), bold: true),
        const SizedBox(height: 6),
        LabelValue('Pay now${c.advancePercent != null ? ' (${c.advancePercent}% advance)' : ''}', Money.bdt(c.dueNow), valueColor: Brand.orange, bold: true),
        if (Money.isPositive(c.dueLater)) LabelValue('Rest of the goods, at delivery', Money.bdt(c.dueLater)),
        if (Money.isPositive(c.creditBalance))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _useCredit,
            onChanged: (v) => setState(() => _useCredit = v ?? false),
            title: Text('Use my account balance (${Money.bdt(c.creditBalance)})'),
          ),
        const SizedBox(height: 6),
        Text('Shipping from China is billed later, by the weight of your parcel in Dhaka.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    );
  }
}

class _ShippingOption extends StatelessWidget {
  const _ShippingOption({required this.method, required this.selected});
  final ShippingMethod method;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final m = method;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RadioListTile<String>(
        contentPadding: EdgeInsets.zero,
        value: m.name,
        enabled: m.isAvailable,
        title: Text(m.name),
        subtitle: !m.isAvailable && m.minAmount != null ? Text('For orders of ${Money.bdt(m.minAmount)} or more') : null,
      ),
      if (selected && m.rates.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final r in m.rates)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                title: Text(r.pricePerKg != null ? '${r.name} — from ${Money.bdt(r.pricePerKg)}/kg' : r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                children: [Text(r.details, style: const TextStyle(fontSize: 12, height: 1.4))],
              ),
          ]),
        ),
    ]);
  }
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
