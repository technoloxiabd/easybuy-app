import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_error.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'cart_screen.dart' show confirm;
import 'order_screens.dart' show SignInPrompt;

final _day = DateFormat('d MMM yyyy');

final accountOverviewProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(authProvider);
  return ref.read(apiProvider).accountOverview();
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const SignInPrompt(icon: Icons.person_outline, title: 'Sign in to EasyBuy', from: '/account'),
      );
    }
    final overview = ref.watch(accountOverviewProvider).value;
    final orders = obj(overview?['orders']);
    final unread = ref.watch(unreadMessagesProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountOverviewProvider);
          ref.invalidate(unreadMessagesProvider);
          await ref.read(authProvider.notifier).reload();
        },
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SectionCard(
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Brand.blue.withValues(alpha: 0.1),
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null ? Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: const TextStyle(fontSize: 22, color: Brand.blue)) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Row(children: [
                    Text(user.phone),
                    const SizedBox(width: 6),
                    user.phoneVerified
                        ? const Icon(Icons.verified, size: 16, color: Brand.success)
                        : TextButton(onPressed: () => context.push('/verify-phone'), child: const Text('Verify')),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _Stat(label: 'Orders', value: '${orders['total'] ?? '–'}', onTap: () => context.push('/orders')),
            const SizedBox(width: 8),
            _Stat(label: 'Need action', value: '${orders['action_needed'] ?? '–'}', onTap: () => context.push('/orders')),
            const SizedBox(width: 8),
            _Stat(label: 'Balance', value: overview == null ? '–' : Money.bdt(str(overview['credit_balance_bdt'])), onTap: () => context.push('/account/credit')),
          ]),
          const SizedBox(height: 10),
          Card(
            child: Column(children: [
              _Item(Icons.receipt_long_outlined, 'My orders', '/orders'),
              _Item(Icons.chat_bubble_outline, 'Messages', '/chat', badge: unread),
              _Item(Icons.support_agent, 'Complaints & support', '/support'),
              _Item(Icons.account_balance_wallet_outlined, 'Payment history', '/account/payments'),
              _Item(Icons.savings_outlined, 'Account balance', '/account/credit'),
              _Item(Icons.location_on_outlined, 'Address book', '/account/addresses'),
              _Item(Icons.person_outline, 'Profile', '/account/profile'),
              _Item(Icons.lock_outline, 'Change password', '/account/password'),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              if (await confirm(context, 'Sign out?', 'Your cart stays with your account.')) {
                await ref.read(authProvider.notifier).signOut();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(children: [
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.blue)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ),
        ),
      );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.path, {this.badge = 0});
  final IconData icon;
  final String label;
  final String path;
  final int badge;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Brand.blue),
        title: Text(label),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (badge > 0) Badge(label: Text('$badge')),
          const Icon(Icons.chevron_right),
        ]),
        onTap: () => context.push(path),
      );
}

// ------------------------------------------------------------------ profile

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final User _user = ref.read(authProvider).value!;
  late final _name = TextEditingController(text: _user.name);
  late final _email = TextEditingController(text: _user.email ?? '');
  late final _phone = TextEditingController(text: _user.phone);
  ApiError? _error;

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      final user = await ref.read(apiProvider).updateProfile(name: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim());
      ref.read(authProvider.notifier).setUser(user);
      if (!mounted) return;
      showMessage(context, 'Profile updated.');
      if (!user.phoneVerified) {
        context.pushReplacement('/verify-phone');
      } else {
        context.pop();
      }
    } on ApiError catch (e) {
      setState(() => _error = e);
      rethrow;
    }
  }

  Future<void> _photo() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose a photo'), onTap: () => Navigator.pop(ctx, 'gallery')),
        ]),
      ),
    );
    final picked = await pickFrom(choice, allowVideo: false);
    if (picked.isEmpty) return;
    try {
      final user = await ref.read(apiProvider).updatePhoto(picked.first);
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) showMessage(context, 'Photo updated.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: GestureDetector(
            onTap: _photo,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Brand.blue.withValues(alpha: 0.1),
              backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
              child: user?.photoUrl == null ? const Icon(Icons.add_a_photo_outlined, color: Brand.blue) : null,
            ),
          ),
        ),
        TextButton(onPressed: _photo, child: const Text('Change photo')),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: InputDecoration(labelText: 'Name', errorText: _error?.fieldError('name'))),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Mobile number', helperText: 'Changing it means verifying the new number.', errorText: _error?.fieldError('phone'))),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email (optional)', errorText: _error?.fieldError('email'))),
        const SizedBox(height: 20),
        BusyButton(label: 'Save', onPressed: _save),
      ]),
    );
  }
}

class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  ApiError? _error;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(controller: _current, obscureText: true, decoration: InputDecoration(labelText: 'Current password', errorText: _error?.fieldError('current_password'))),
          const SizedBox(height: 12),
          TextField(controller: _next, obscureText: true, decoration: InputDecoration(labelText: 'New password (8+ characters)', errorText: _error?.fieldError('password'))),
          const SizedBox(height: 8),
          Text('Other phones signed in to your account will be signed out.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          BusyButton(
            label: 'Change password',
            onPressed: () async {
              setState(() => _error = null);
              try {
                await ref.read(apiProvider).changePassword(_current.text, _next.text);
                if (!context.mounted) return;
                showMessage(context, 'Password changed.');
                context.pop();
              } on ApiError catch (e) {
                setState(() => _error = e);
                rethrow;
              }
            },
          ),
        ]),
      );
}

// ------------------------------------------------------------------ addresses

final addressesProvider = FutureProvider.autoDispose<List<Address>>((ref) => ref.read(apiProvider).addresses());

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Address book')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.location_on_outlined, title: 'No saved addresses', body: 'Addresses you save pre-fill checkout.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return Card(
                    child: ListTile(
                      title: Row(children: [
                        Flexible(child: Text('${a.label != null ? '${a.label} · ' : ''}${a.name}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (a.isDefault) ...[const SizedBox(width: 8), const StatusChip('Default', status: 'delivered')],
                      ]),
                      subtitle: Text('${a.phone}\n${a.address}'),
                      isThreeLine: true,
                      onTap: () => _edit(context, ref, a),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          try {
                            if (v == 'default') await ref.read(apiProvider).makeDefaultAddress(a.id);
                            if (v == 'delete' && context.mounted && await confirm(context, 'Remove this address?', a.address)) {
                              await ref.read(apiProvider).deleteAddress(a.id);
                            }
                            ref.invalidate(addressesProvider);
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                        itemBuilder: (_) => [
                          if (!a.isDefault) const PopupMenuItem(value: 'default', child: Text('Make default')),
                          const PopupMenuItem(value: 'delete', child: Text('Remove')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Address? a) async {
    final label = TextEditingController(text: a?.label ?? '');
    final name = TextEditingController(text: a?.name ?? ref.read(authProvider).value?.name ?? '');
    final phone = TextEditingController(text: a?.phone ?? ref.read(authProvider).value?.phone ?? '');
    final address = TextEditingController(text: a?.address ?? '');
    var makeDefault = a?.isDefault ?? false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(a == null ? 'New address' : 'Edit address', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Label (optional)', hintText: 'Home, Office, Shop')),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Recipient name')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')),
            const SizedBox(height: 10),
            TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: 'Full address')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: makeDefault, onChanged: (v) => setSheet(() => makeDefault = v ?? false), title: const Text('Use as default')),
            BusyButton(
              label: 'Save',
              onPressed: () async {
                await ref.read(apiProvider).saveAddress(
                      id: a?.id,
                      label: label.text.trim().isEmpty ? null : label.text.trim(),
                      name: name.text.trim(),
                      phone: phone.text.trim(),
                      address: address.text.trim(),
                      makeDefault: makeDefault,
                    );
                ref.invalidate(addressesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ money history

/// A cursor-paged list of JSON rows with a header built from the first page's meta.
class _PagedJsonList extends ConsumerStatefulWidget {
  const _PagedJsonList({required this.fetch, required this.row, required this.header, required this.empty});
  final Future<Json> Function(String? cursor) fetch;
  final Widget Function(Json row) row;
  final Widget Function(Json meta) header;
  final String empty;

  @override
  ConsumerState<_PagedJsonList> createState() => _PagedJsonListState();
}

class _PagedJsonListState extends ConsumerState<_PagedJsonList> {
  final _rows = <Json>[];
  Json? _meta;
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final r = await widget.fetch(_cursor);
      setState(() {
        _meta ??= obj(r['meta']);
        _rows.addAll(listOf(r['data'], (e) => e));
        _cursor = strOrNull(obj(r['meta'])['next_cursor']);
        _done = _cursor == null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty && _error != null) return ErrorView(error: _error!, onRetry: _more);
    if (_meta == null) return const LoadingView();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _more();
        return false;
      },
      child: ListView(padding: const EdgeInsets.all(12), children: [
        widget.header(_meta!),
        const SizedBox(height: 10),
        if (_rows.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(widget.empty, textAlign: TextAlign.center)),
        for (final r in _rows) widget.row(r),
        if (_loading) const LoadingView(),
      ]),
    );
  }
}

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Payment history')),
        body: _PagedJsonList(
          fetch: (c) => ref.read(apiProvider).accountPayments(cursor: c),
          empty: 'No payments yet.',
          header: (meta) {
            final t = obj(meta['totals']);
            return SectionCard(
              child: Column(children: [
                LabelValue('Confirmed', Money.bdt(str(t['confirmed_bdt'])), valueColor: Brand.success),
                LabelValue('Waiting for confirmation', Money.bdt(str(t['pending_bdt'])), valueColor: Brand.warning),
                LabelValue('Still due on your orders', Money.bdt(str(t['due_bdt'])), bold: true),
              ]),
            );
          },
          row: (p) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => context.push('/orders/${p['order_number']}'),
              title: Text('${p['order_number']} · ${p['stage_label']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([str(p['method']), if (date(p['created_at']) != null) _day.format(date(p['created_at'])!)].join(' · ')),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Money.bdt(str(p['amount_bdt'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                StatusChip(str(p['status']), status: str(p['status'])),
              ]),
            ),
          ),
        ),
      );
}

class CreditScreen extends ConsumerWidget {
  const CreditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Account balance')),
        body: _PagedJsonList(
          fetch: (c) => ref.read(apiProvider).credit(cursor: c),
          empty: 'No balance activity yet.',
          header: (meta) => SectionCard(
            child: Column(children: [
              Text(Money.bdt(str(meta['balance_bdt'])), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Brand.blue)),
              const SizedBox(height: 4),
              Text('You can spend it on your next order at checkout.', style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ),
          row: (c) {
            final amount = str(c['amount_bdt']);
            final negative = amount.startsWith('-');
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(str(c['label']), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([if (c['order_number'] != null) 'Order ${c['order_number']}', if (date(c['created_at']) != null) _day.format(date(c['created_at'])!)].join(' · ')),
                trailing: Text('${negative ? '−' : '+'} ${Money.bdt(amount.replaceFirst('-', ''))}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: negative ? Brand.danger : Brand.success)),
              ),
            );
          },
        ),
      );
}
