import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'order_screens.dart' show ReceiptPicker, openExternal;

/// Paying for an order. Every live method is a transfer made outside the app
/// (bKash Send Money, a bank deposit): the customer pays, then sends the
/// reference and a screenshot here, and staff confirm it.
class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key, required this.number, this.stage});
  final String number;
  final String? stage;

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  PayOptions? _options;
  Object? _error;
  int? _methodId;
  bool _shippingOnly = false;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _files = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await ref.read(apiProvider).payOptions(widget.number, stage: widget.stage);
      setState(() {
        _options = o;
        _error = null;
        _methodId ??= o.methods.firstOrNull?.id;
        _amount.text = (double.tryParse(o.suggested) ?? 0).ceil().toString();
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  PayMethod? get _method => _options?.methods.where((m) => m.id == _methodId).firstOrNull;

  Future<void> _submit() async {
    final o = _options!;
    final m = _method!;
    final r = await ref.read(apiProvider).pay(
          widget.number,
          stage: o.stage,
          methodId: m.id,
          amount: m.isGateway ? null : _amount.text.trim(),
          shippingOnly: _shippingOnly,
          reference: _reference.text,
          proofPaths: _files,
        );
    if (!mounted) return;
    final redirect = r['redirect_url'];
    if (redirect is String && redirect.isNotEmpty) {
      await openExternal(context, redirect);
      if (mounted) context.pop();
      return;
    }
    showMessage(context, '${r['message'] ?? 'Thank you. We will confirm your payment shortly.'}');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = _options;
    return Scaffold(
      appBar: AppBar(title: Text('Pay — ${widget.number}')),
      body: o == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView())
          : !o.canPay
              ? const EmptyState(icon: Icons.check_circle_outline, title: 'Nothing to pay right now')
              : ListView(padding: const EdgeInsets.all(12), children: [
                  SectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(o.stageLabel, style: TextStyle(color: Colors.grey.shade700)),
                      Text(Money.bdt(_shippingOnly ? o.shippingOnly : o.outstanding), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Brand.orange)),
                      if (Money.isPositive(o.pending)) ...[
                        const SizedBox(height: 8),
                        NoticeBox('${Money.bdt(o.pending)} already sent — waiting for our team to confirm.'),
                      ],
                      if (o.shippingOnly != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _shippingOnly,
                          onChanged: (v) => setState(() {
                            _shippingOnly = v;
                            _amount.text = (double.tryParse(v ? o.shippingOnly! : o.suggested) ?? 0).ceil().toString();
                          }),
                          title: Text('Pay only the shipping (${Money.bdt(o.shippingOnly)})'),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SectionCard(
                    title: 'Pay with',
                    child: RadioGroup<int>(
                      groupValue: _methodId,
                      onChanged: (v) => setState(() => _methodId = v),
                      child: Column(children: [
                        for (final m in o.methods) RadioListTile<int>(contentPadding: EdgeInsets.zero, value: m.id, title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
                  if (_method != null) ...[
                    const SizedBox(height: 10),
                    _MethodDetails(method: _method!),
                    if (!_method!.isGateway) ...[
                      const SizedBox(height: 10),
                      SectionCard(
                        title: 'After you have paid',
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount you sent (৳)', helperText: 'Sent less? Enter what you actually sent.')),
                          if (_method!.collectsReference) ...[
                            const SizedBox(height: 10),
                            TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Transaction ID / reference', hintText: 'e.g. TRX123456789')),
                          ],
                          if (_method!.collectsProof) ...[
                            const SizedBox(height: 10),
                            ReceiptPicker(files: _files, onChanged: () => setState(() {})),
                          ],
                        ]),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  BusyButton(label: _method?.isGateway == true ? 'Continue to ${_method!.name}' : 'Submit payment', onPressed: _method == null ? null : _submit),
                  const SizedBox(height: 24),
                ]),
    );
  }
}

class _MethodDetails extends StatelessWidget {
  const _MethodDetails({required this.method});
  final PayMethod method;

  static const _labels = {
    'account_name': 'Account name',
    'account_number': 'Account',
    'branch_name': 'Branch',
    'routing_number': 'Routing no.',
    'swift_code': 'SWIFT',
  };

  @override
  Widget build(BuildContext context) => SectionCard(
        title: method.name,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (method.instructions != null) Text(method.instructions!, style: const TextStyle(height: 1.4)),
          if (method.account.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final e in method.account.entries)
              Row(children: [
                SizedBox(width: 100, child: Text(_labels[e.key] ?? e.key, style: TextStyle(color: Colors.grey.shade600))),
                Expanded(child: SelectableText(e.value, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: e.value));
                    if (context.mounted) showMessage(context, 'Copied');
                  },
                ),
              ]),
          ],
        ]),
      );
}
