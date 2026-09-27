import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_error.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

final _when = DateFormat('d MMM yyyy, h:mm a');

Future<void> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, 'Could not open the link.', error: true);
}

/// A guest on a tab that needs an account.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.title, required this.from});
  final IconData icon;
  final String title;
  final String from;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: icon,
        title: title,
        body: 'Sign in to continue.',
        action: SizedBox(width: 200, child: FilledButton(onPressed: () => context.push('/login?from=${Uri.encodeComponent(from)}'), child: const Text('Sign in'))),
      );
}

// ------------------------------------------------------------------ list

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _orders = <OrderSummary>[];
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  Object? _error;
  int? _loadedFor;

  Future<void> _reset() async {
    setState(() {
      _orders.clear();
      _cursor = null;
      _done = false;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final page = await ref.read(apiProvider).orders(cursor: _cursor);
      setState(() {
        _orders.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user != null && _loadedFor != user.id) {
      _loadedFor = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: user == null
          ? const SignInPrompt(icon: Icons.receipt_long_outlined, title: 'Your orders appear here', from: '/orders')
          : RefreshIndicator(
              onRefresh: _reset,
              child: _orders.isEmpty && _error != null
                  ? ListView(children: [ErrorView(error: _error!, onRetry: _reset)])
                  : _orders.isEmpty && _done
                      ? ListView(children: [
                          EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet', action: FilledButton(onPressed: () => context.go('/'), child: const Text('Start shopping'))),
                        ])
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _more();
                            return false;
                          },
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: _orders.length + (_loading ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => i >= _orders.length ? const LoadingView() : _OrderRow(order: _orders[i]),
                          ),
                        ),
            ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/orders/${order.number}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(width: 56, height: 56, child: NetImage(order.thumbnailUrl)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(order.number, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    StatusChip(order.statusLabel, status: order.status),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${order.title ?? ''}${order.productCount > 1 ? ' and ${order.productCount - 1} more' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(order.placedAt != null ? DateFormat('d MMM yyyy').format(order.placedAt!) : '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const Spacer(),
                    if (order.nextPayment != null)
                      Text('Pay ${Money.bdt(order.nextPayment!.remaining)}', style: const TextStyle(color: Brand.orange, fontWeight: FontWeight.w700, fontSize: 13))
                    else
                      Text(Money.bdt(order.goodsTotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------ detail

final orderProvider = FutureProvider.autoDispose.family<OrderDetail, String>((ref, number) => ref.read(apiProvider).order(number));

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.number});
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderProvider(number));
    return Scaffold(
      appBar: AppBar(title: Text('Order $number'), actions: [
        IconButton(tooltip: 'Ask about this order', onPressed: () => context.push('/chat?order=$number'), icon: const Icon(Icons.chat_bubble_outline)),
      ]),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(orderProvider(number))),
        data: (o) => RefreshIndicator(
          onRefresh: () => ref.refresh(orderProvider(number).future),
          child: _OrderBody(order: o),
        ),
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = order.summary;
    final st = order.statement;
    final next = s.nextPayment;

    return ListView(padding: const EdgeInsets.all(12), children: [
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(s.placedAt != null ? 'Placed ${_when.format(s.placedAt!)}' : '', style: TextStyle(color: Colors.grey.shade700))),
            StatusChip(s.statusLabel, status: s.status),
          ]),
          if (next != null) ...[
            const SizedBox(height: 12),
            if (Money.isPositive(next.pending))
              Padding(padding: const EdgeInsets.only(bottom: 8), child: NoticeBox('${Money.bdt(next.pending)} received — waiting for our team to confirm.')),
            FilledButton.icon(
              onPressed: () async {
                await context.push('/orders/${s.number}/pay?stage=${next.stage}');
                ref.invalidate(orderProvider(s.number));
              },
              icon: const Icon(Icons.payments_outlined),
              label: Text(Money.isPositive(next.pending) && Money.isPositive(next.remaining)
                  ? 'Pay the rest — ${Money.bdt(next.remaining)}'
                  : next.stage == 'goods'
                      ? 'Pay advance — ${Money.bdt(next.amount)}'
                      : 'Pay due — ${Money.bdt(next.amount)}'),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      SectionCard(
        title: 'Items',
        child: Column(children: [for (final g in order.items) _ItemGroup(group: g)]),
      ),
      const SizedBox(height: 10),
      SectionCard(
        title: 'Payment summary',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LabelValue('Goods', Money.bdt(str(st['goods_total_bdt']))),
          LabelValue(
            'Shipping',
            objOrNull(st['freight']) == null ? 'By weight, later' : '${Money.bdt(str(obj(st['freight'])['amount_bdt']))} (${obj(st['freight'])['weight_kg']} kg)',
          ),
          for (final c in listOf(st['surcharges'], (e) => e)) LabelValue(str(c['label']), Money.bdt(str(c['amount_bdt']))),
          if (Money.isPositive(str(st['refund_charges_bdt']))) LabelValue('Refund charge kept', Money.bdt(str(st['refund_charges_bdt']))),
          const Divider(),
          LabelValue('Invoice amount', Money.bdt(str(st['invoice_amount_bdt'])), bold: true),
          if (Money.isPositive(str(st['credits_bdt']))) LabelValue('Discounts & credits', '− ${Money.bdt(str(st['credits_bdt']))}', valueColor: Brand.success),
          LabelValue('Paid', '− ${Money.bdt(str(st['paid_bdt']))}', valueColor: Brand.success),
          if (Money.isPositive(str(st['submitted_bdt']))) LabelValue('Submitted, awaiting confirmation', Money.bdt(str(st['submitted_bdt'])), valueColor: Brand.warning),
          if (Money.isPositive(str(st['refunded_bdt']))) LabelValue('Refunded to you', '+ ${Money.bdt(str(st['refunded_bdt']))}'),
          if (Money.isPositive(str(st['moved_to_balance_bdt']))) LabelValue('Moved to your balance', '+ ${Money.bdt(str(st['moved_to_balance_bdt']))}'),
          const SizedBox(height: 6),
          _BalanceBanner(statement: st),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final url = await ref.read(apiProvider).invoiceUrl(s.number);
                if (context.mounted) await openExternal(context, url);
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Invoice (PDF)'),
          ),
        ]),
      ),
      if (order.transactions.isNotEmpty) ...[
        const SizedBox(height: 10),
        SectionCard(
          title: 'Transactions',
          child: Column(children: [for (final t in order.transactions) _TransactionRow(number: s.number, txn: t)]),
        ),
      ],
      if (order.refunds.isNotEmpty) ...[
        const SizedBox(height: 10),
        SectionCard(
          title: 'Refunds',
          child: Column(children: [
            for (final r in order.refunds)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(str(r['reason'], 'Refund')),
                subtitle: Text(date(r['created_at']) != null ? _when.format(date(r['created_at'])!) : ''),
                trailing: Text('− ${Money.bdt(str(r['amount_bdt']))}', style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ],
      if (order.courier.isNotEmpty) ...[
        const SizedBox(height: 10),
        SectionCard(
          title: 'Courier',
          child: Column(children: [
            for (final b in order.courier)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${b['courier']}${integer(b['parcel_count']) > 1 ? ' · parcel ${b['parcel']} of ${b['parcel_count']}' : ''}'),
                subtitle: Text([
                  str(b['consignment_id']),
                  str(b['status']),
                  if (b['amount_to_collect_bdt'] != null) 'Pay on delivery ${Money.bdt(str(b['amount_to_collect_bdt']))}',
                ].where((x) => x.isNotEmpty).join(' · ')),
                trailing: b['tracking_url'] != null ? TextButton(onPressed: () => openExternal(context, str(b['tracking_url'])), child: const Text('Track')) : null,
              ),
          ]),
        ),
      ],
      if (order.timeline.isNotEmpty) ...[
        const SizedBox(height: 10),
        SectionCard(
          title: 'Tracking',
          child: Column(children: [
            for (final step in order.timeline)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.circle, size: 10, color: Brand.blue),
                title: Text(str(step['label']), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(date(step['at']) != null ? _when.format(date(step['at'])!) : ''),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      SectionCard(
        title: 'Shipping & delivery',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (s.shippingMethod != null) LabelValue('Shipment', s.shippingMethod!),
          if (s.deliveryMethod != null) LabelValue('Delivery', s.deliveryMethod!),
          if (order.deliveryNote != null) ...[const SizedBox(height: 6), NoticeBox(order.deliveryNote!, tone: NoticeTone.info)],
        ]),
      ),
      const SizedBox(height: 10),
      SectionCard(
        title: 'Delivery address',
        trailing: order.canEditAddress ? TextButton(onPressed: () => _editAddress(context, ref), child: const Text('Change')) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(str(order.address['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(str(order.address['phone'])),
          Text(str(order.address['address']), style: TextStyle(color: Colors.grey.shade700)),
          if (!order.canEditAddress)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Being prepared for delivery — contact us to change the address.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => context.push('/support/new?order=${s.number}'),
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Report a problem with this order'),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Future<void> _editAddress(BuildContext context, WidgetRef ref) async {
    final a = order.address;
    final name = TextEditingController(text: str(a['name']));
    final phone = TextEditingController(text: str(a['phone']));
    final address = TextEditingController(text: str(a['address']));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Change delivery address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Recipient name')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')),
          const SizedBox(height: 10),
          TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: 'Full address')),
          const SizedBox(height: 14),
          BusyButton(
            label: 'Save address',
            onPressed: () async {
              await ref.read(apiProvider).updateOrderAddress(order.summary.number, name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim());
              ref.invalidate(orderProvider(order.summary.number));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }
}

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.statement});
  final Json statement;

  @override
  Widget build(BuildContext context) {
    final settled = boolean(statement['is_settled']);
    final overpaid = boolean(statement['is_overpaid']);
    final balance = str(statement['balance_bdt'], '0');
    final (label, color) = settled
        ? ('Fully paid', Brand.success)
        : overpaid
            ? ('Credit — we owe you', Brand.blue)
            : ('Amount to pay', Brand.warning);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        const Spacer(),
        Text(settled ? Money.bdt('0') : Money.bdt(balance.replaceFirst('-', '')), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _ItemGroup extends StatelessWidget {
  const _ItemGroup({required this.group});
  final OrderItemGroup group;

  @override
  Widget build(BuildContext context) {
    final ship = group.shipping;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: group.productId == null ? null : () => context.push('/product/${group.productId}'),
          child: Row(children: [
            SizedBox(width: 44, height: 44, child: NetImage(group.imageUrl, radius: 8)),
            const SizedBox(width: 10),
            Expanded(child: Text(group.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Text(Money.bdt(group.total), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        for (final l in group.lines)
          Padding(
            padding: const EdgeInsets.only(left: 54, top: 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${l.attributes.isEmpty ? 'Standard' : Attribute.describe(l.attributes)} × ${l.quantity}${l.isCancelled ? ' · cancelled' : ''}',
                  style: TextStyle(fontSize: 12, color: l.isCancelled ? Colors.grey : Colors.grey.shade700, decoration: l.isCancelled ? TextDecoration.lineThrough : null),
                ),
              ),
              Text(Money.bdt(l.lineTotal), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ]),
          ),
        if (ship != null)
          Padding(
            padding: const EdgeInsets.only(left: 54, top: 4),
            child: Text(
              [
                'Shipping',
                if (ship['rate_per_kg_bdt'] != null) '${Money.bdt(str(ship['rate_per_kg_bdt']))}/kg',
                if (ship['weight_kg'] != null) '${ship['weight_kg']} kg',
                if (ship['cost_bdt'] != null) '= ${Money.bdt(str(ship['cost_bdt']))}',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Brand.blue),
            ),
          ),
      ]),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.number, required this.txn});
  final String number;
  final Transaction txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPay = txn.isPayment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isPay ? Icons.account_balance_wallet_outlined : Icons.receipt_outlined, color: Brand.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txn.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
              [if (txn.createdAt != null) _when.format(txn.createdAt!), if (txn.detail != null) txn.detail!].join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Wrap(spacing: 8, children: [
              for (final (i, r) in txn.receipts.indexed)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                  onPressed: () => openExternal(context, r.url),
                  child: Text(txn.receipts.length > 1 ? 'Receipt ${i + 1}' : 'Receipt'),
                ),
              if (txn.canEdit)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                  onPressed: () async {
                    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => AmendPaymentSheet(number: number, txn: txn));
                    ref.invalidate(orderProvider(number));
                  },
                  child: const Text('Edit'),
                ),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isPay ? '' : '${txn.sign} '}${Money.bdt(txn.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (isPay) StatusChip(txn.status, status: txn.status),
        ]),
      ]),
    );
  }
}

/// Correct a payment staff have not confirmed yet.
class AmendPaymentSheet extends ConsumerStatefulWidget {
  const AmendPaymentSheet({super.key, required this.number, required this.txn});
  final String number;
  final Transaction txn;

  @override
  ConsumerState<AmendPaymentSheet> createState() => _AmendPaymentSheetState();
}

class _AmendPaymentSheetState extends ConsumerState<AmendPaymentSheet> {
  late final _amount = TextEditingController(text: (double.tryParse(widget.txn.amount) ?? 0).round().toString());
  late final _reference = TextEditingController(text: widget.txn.detail ?? '');
  final _files = <String>[];

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Correct this payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('We have not confirmed it yet, so you can still fix it.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount you actually sent (৳)')),
          const SizedBox(height: 10),
          TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Transaction reference')),
          const SizedBox(height: 10),
          ReceiptPicker(files: _files, onChanged: () => setState(() {}), label: 'New receipt (replaces the old)'),
          const SizedBox(height: 14),
          BusyButton(
            label: 'Save changes',
            onPressed: () async {
              try {
                final r = await ref.read(apiProvider).amendPayment(widget.number, widget.txn.paymentId!, amount: _amount.text.trim(), reference: _reference.text, proofPaths: _files);
                if (!context.mounted) return;
                Navigator.pop(context);
                showMessage(context, '${r['message'] ?? 'Saved.'}');
              } on ApiError catch (e) {
                if (e.code == 'nothing_to_change' && context.mounted) Navigator.pop(context);
                rethrow;
              }
            },
          ),
        ]),
      );
}

/// Picks receipt photos or PDFs; used when paying and when correcting.
class ReceiptPicker extends StatelessWidget {
  const ReceiptPicker({super.key, required this.files, required this.onChanged, this.label = 'Payment receipt (screenshot or PDF)'});
  final List<String> files;
  final VoidCallback onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton.icon(
          onPressed: files.length >= 5
              ? null
              : () async {
                  final picked = await pickFiles(context, allowVideo: false);
                  files.addAll(picked.take(5 - files.length));
                  onChanged();
                },
          icon: const Icon(Icons.upload_file),
          label: Text(files.isEmpty ? label : 'Add another file'),
        ),
        for (final (i, f) in files.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(f.split('/').last, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                files.removeAt(i);
                onChanged();
              },
            ),
          ),
      ]);
}

/// Camera, gallery or a document -- the paths of what was chosen.
Future<List<String>> pickFiles(BuildContext context, {bool allowVideo = true}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, 'camera')),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose photos'), onTap: () => Navigator.pop(ctx, 'gallery')),
        ListTile(leading: const Icon(Icons.description_outlined), title: Text(allowVideo ? 'Choose a file or video' : 'Choose a PDF or file'), onTap: () => Navigator.pop(ctx, 'file')),
      ]),
    ),
  );
  return pickFrom(choice, allowVideo: allowVideo);
}
