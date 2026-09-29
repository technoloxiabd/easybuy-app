import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'order_screens.dart' show openExternal, pickFiles;

final _when = DateFormat('d MMM, h:mm a');

// ------------------------------------------------------------------ complaints

final complaintsProvider = FutureProvider.autoDispose<List<ComplaintSummary>>((ref) => ref.read(apiProvider).complaints());

class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(complaintsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints & support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/support/new');
          ref.invalidate(complaintsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New complaint'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(complaintsProvider)),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(complaintsProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Brand.blue),
                title: const Text('Questions? Message your relationship manager'),
                subtitle: const Text('For "when does it arrive?" and anything quick.'),
                onTap: () => context.push('/chat'),
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty) const EmptyState(icon: Icons.support_agent, title: 'No complaints', body: 'Something wrong with an order? Open a complaint and our team will follow it up.'),
            for (final c in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () async {
                    await context.push('/support/${c.number}');
                    ref.invalidate(complaintsProvider);
                  },
                  title: Text(c.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([c.number, if (c.orderNumber != null) 'Order ${c.orderNumber}', c.awaitingSupport ? 'Waiting for support' : 'Support replied'].join(' · ')),
                  trailing: StatusChip(c.statusLabel, status: c.isClosed ? 'delivered' : 'pending'),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class NewComplaintScreen extends ConsumerStatefulWidget {
  const NewComplaintScreen({super.key, this.orderNumber});
  final String? orderNumber;

  @override
  ConsumerState<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends ConsumerState<NewComplaintScreen> {
  final _subject = TextEditingController();
  final _details = TextEditingController();
  late final _order = TextEditingController(text: widget.orderNumber ?? '');
  final _files = <String>[];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New complaint')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _order, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Order number (optional)', hintText: 'SEP…')),
          const SizedBox(height: 12),
          TextField(controller: _subject, maxLength: 200, decoration: const InputDecoration(labelText: 'Subject', hintText: 'e.g. Wrong colour received')),
          TextField(controller: _details, maxLines: 6, maxLength: 5000, decoration: const InputDecoration(labelText: 'What happened?')),
          const SizedBox(height: 8),
          _Attachments(files: _files, onChanged: () => setState(() {}), max: 6),
          const SizedBox(height: 16),
          BusyButton(
            label: 'Submit complaint',
            onPressed: () async {
              final c = await ref.read(apiProvider).openComplaint(
                    subject: _subject.text.trim(),
                    details: _details.text.trim(),
                    orderNumber: _order.text.trim().isEmpty ? null : _order.text.trim(),
                    files: _files,
                  );
              if (!context.mounted) return;
              showMessage(context, 'Your complaint has been submitted. Our team will get back to you.');
              context.pushReplacement('/support/${c.summary.number}');
            },
          ),
        ]),
      );
}

final complaintProvider = FutureProvider.autoDispose.family<ComplaintDetail, String>((ref, n) => ref.read(apiProvider).complaint(n));

class ComplaintScreen extends ConsumerStatefulWidget {
  const ComplaintScreen({super.key, required this.number});
  final String number;

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  final _reply = TextEditingController();
  final _files = <String>[];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(complaintProvider(widget.number));
    return Scaffold(
      appBar: AppBar(title: Text(widget.number)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(complaintProvider(widget.number))),
        data: (c) => ListView(padding: const EdgeInsets.all(12), children: [
          SectionCard(
            title: c.summary.subject,
            trailing: StatusChip(c.summary.statusLabel, status: c.summary.isClosed ? 'delivered' : 'pending'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.summary.orderNumber != null)
                TextButton(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => context.push('/orders/${c.summary.orderNumber}'), child: Text('Order ${c.summary.orderNumber}')),
              Text(c.details, style: const TextStyle(height: 1.4)),
              _FileChips(files: c.attachments),
            ]),
          ),
          const SizedBox(height: 10),
          for (final m in c.messages) _Bubble(message: m),
          const SizedBox(height: 10),
          SectionCard(
            title: c.summary.isClosed ? 'Reply (reopens the complaint)' : 'Reply',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _reply, maxLines: 4, decoration: const InputDecoration(hintText: 'Write your reply')),
              const SizedBox(height: 8),
              _Attachments(files: _files, onChanged: () => setState(() {}), max: 6),
              const SizedBox(height: 8),
              BusyButton(
                label: 'Send reply',
                onPressed: () async {
                  await ref.read(apiProvider).replyComplaint(widget.number, _reply.text.trim(), files: _files);
                  _reply.clear();
                  setState(_files.clear);
                  ref.invalidate(complaintProvider(widget.number));
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ chat

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.orderNumber, this.productId});
  final String? orderNumber;
  final int? productId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _messages = <ThreadMessage>[];
  final _text = TextEditingController();
  final _files = <String>[];
  final _scroll = ScrollController();
  Json? _manager;

  /// The website chat's one-tap "📦 My order status?" buttons (server's call).
  bool _statusPreset = false;
  bool _hasMore = false;
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  Timer? _poll;

  /// "About order X / product Y" rides on the first message only.
  late String? _aboutOrder = widget.orderNumber;
  late int? _aboutProduct = widget.productId;

  int get _lastId => _messages.isEmpty ? 0 : _messages.last.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Until push is switched on, a gentle catch-up while the chat is open.
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _catchUp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _catchUp();
  }

  Future<void> _load() async {
    try {
      final (list, meta) = await ref.read(apiProvider).messages();
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _manager = objOrNull(meta['manager']);
        _statusPreset = boolean(meta['status_preset']);
        _hasMore = boolean(meta['has_more']);
        _error = null;
      });
      ref.invalidate(unreadMessagesProvider);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _catchUp() async {
    if (_loading || !mounted) return;
    try {
      final (list, meta) = await ref.read(apiProvider).messages(after: _lastId);
      final removed = (meta['removed'] as List?)?.map((e) => integer(e)).toSet() ?? const <int>{};
      final preset = boolean(meta['status_preset']);
      if (preset != _statusPreset) setState(() => _statusPreset = preset);
      if (list.isEmpty && removed.isEmpty) return;
      setState(() {
        _messages.removeWhere((m) => removed.contains(m.id));
        _messages.addAll(list.where((m) => !_messages.any((x) => x.id == m.id)));
        _manager = objOrNull(meta['manager']) ?? _manager;
      });
      ref.invalidate(unreadMessagesProvider);
    } catch (_) {
      // A missed catch-up is retried on the next tick.
    }
  }

  Future<void> _older() async {
    if (!_hasMore || _messages.isEmpty) return;
    final (list, meta) = await ref.read(apiProvider).messages(before: _messages.first.id);
    setState(() {
      _messages.insertAll(0, list);
      _hasMore = boolean(meta['has_more']);
    });
  }

  Future<void> _send({bool shareProduct = false}) async {
    if (_sending) return;
    if (!shareProduct && _text.text.trim().isEmpty && _files.isEmpty) return;
    setState(() => _sending = true);
    try {
      final m = await ref.read(apiProvider).sendMessage(
            body: shareProduct ? null : _text.text,
            files: shareProduct ? const [] : List.of(_files),
            orderNumber: _aboutOrder,
            productId: _aboutProduct,
            shareProduct: shareProduct,
          );
      setState(() {
        _messages.add(m);
        if (!shareProduct) {
          _text.clear();
          _files.clear();
        }
        _aboutOrder = null;
        _aboutProduct = null;
      });
      // The order-status bot may answer at once.
      Future.delayed(const Duration(seconds: 3), _catchUp);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// A tap on a quick reply, an order chip or a preset: sent as typed.
  void _sendText(String text) {
    _text.text = text;
    _send();
  }

  Future<void> _undo(ThreadMessage m) async {
    try {
      await ref.read(apiProvider).undoMessage(m.id);
      setState(() => _messages.removeWhere((x) => x.id == m.id));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: _ManagerHeader(manager: manager)),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null && _messages.isEmpty
                  ? ErrorView(error: _error!, onRetry: _load)
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) return TextButton(onPressed: _older, child: const Text('Earlier messages'));
                        final m = _messages[_messages.length - 1 - i];
                        return GestureDetector(
                          onLongPress: m.canUndo
                              ? () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Undo this message?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Undo')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) _undo(m);
                                }
                              : null,
                          child: _Bubble(message: m, onSend: _sendText),
                        );
                      },
                    ),
        ),
        if (_aboutOrder != null || _aboutProduct != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(children: [
              const Icon(Icons.link, size: 16, color: Brand.blue),
              const SizedBox(width: 6),
              Expanded(child: Text(_aboutOrder != null ? 'About order $_aboutOrder' : 'About this product', style: const TextStyle(color: Brand.blue, fontSize: 13))),
              if (_aboutProduct != null) TextButton(onPressed: _sending ? null : () => _send(shareProduct: true), child: const Text('Send product')),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _aboutOrder = _aboutProduct = null)),
            ]),
          ),
        // Shown while an order is in flight; the status bot answers them.
        if (_statusPreset)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _PresetPill(label: '📦 My order status?', onTap: _sending ? null : () => _sendText('Can you tell me my order status?')),
              _PresetPill(label: '📦 অর্ডারের স্ট্যাটাস?', onTap: _sending ? null : () => _sendText('আপনি কি আমাকে আমার অর্ডারের স্ট্যাটাস জানাতে পারবেন?')),
            ]),
          ),
        if (_files.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 6, children: [
              for (final f in _files) InputChip(label: Text(f.split('/').last, overflow: TextOverflow.ellipsis), onDeleted: () => setState(() => _files.remove(f))),
            ]),
          ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
            child: Row(children: [
              IconButton(
                tooltip: 'Attach',
                icon: const Icon(Icons.attach_file),
                onPressed: _files.length >= 5
                    ? null
                    : () async {
                        final picked = await pickFiles(context);
                        setState(() => _files.addAll(picked.take(5 - _files.length)));
                      },
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Type a message', isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: Brand.orange),
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ pieces

/// The website's chat header: the manager's photo (or initial) with a
/// presence dot, the name with an Online / Idle / Offline badge, and what to
/// expect underneath.
class _ManagerHeader extends StatelessWidget {
  const _ManagerHeader({required this.manager});
  final Json? manager;

  @override
  Widget build(BuildContext context) {
    final m = manager;
    final name = m?['name'] != null ? '${m!['name']}' : 'Your relationship manager';
    final (dot, chipBg, chipFg, label) = switch (m?['presence']) {
      'online' => (const Color(0xFF22C55E), const Color(0xFFF0FDF4), const Color(0xFF15803D), 'Online'),
      'idle' => (const Color(0xFFFBBF24), const Color(0xFFFFFBEB), const Color(0xFFB45309), 'Idle'),
      _ => (const Color(0xFFF87171), const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'Offline'),
    };
    return Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        m?['photo_url'] != null
            ? CircleAvatar(radius: 20, backgroundColor: Colors.white, backgroundImage: NetworkImage('${m!['photo_url']}'))
            : CircleAvatar(
                radius: 20,
                backgroundColor: Brand.blue,
                child: Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
        if (m != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(width: 14, height: 14, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
          ),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.ink))),
            if (m != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: chipFg)),
              ),
            ],
          ]),
          Text(
            m != null ? 'Usually replies within a few hours' : 'Being assigned — send a message and we will pick it up',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: Color(0xFF6B7280)),
          ),
        ]),
      ),
    ]);
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: Brand.blue, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Brand.blue)),
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onSend});
  final ThreadMessage message;

  /// Sends a quick reply or an order number, as the website's chips do.
  /// Null in a complaint thread, which has no bot and no chips.
  final ValueChanged<String>? onSend;

  static final _chips = RegExp(r'\[([^\[\]<>]{1,24})\]|\b([A-Z]{3}\d{6})\b');

  /// The body with the website's buttons: [bracketed] quick replies in the
  /// bot's messages, order numbers in any staff or bot message.
  Widget _body(String body) {
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _chips.allMatches(body)) {
      final quick = m[1];
      final number = m[2];
      if (quick != null && !message.isBot) continue;
      spans.add(TextSpan(text: body.substring(at, m.start)));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Material(
            color: quick != null ? Brand.blue : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSend!(quick ?? number!),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Text(quick ?? number!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: quick != null ? Colors.white : Brand.blue)),
              ),
            ),
          ),
        ),
      ));
      at = m.end;
    }
    spans.add(TextSpan(text: body.substring(at)));
    return Text.rich(TextSpan(children: spans), style: const TextStyle(color: Brand.ink, height: 1.35));
  }

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final context_ = message.context;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: mine ? Brand.blue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (context_ != null && context_['type'] == 'product')
            InkWell(
              onTap: () => context.push('/product/${context_['product_id']}'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 44, height: 44, child: NetImage(strOrNull(context_['image_url']), radius: 6)),
                const SizedBox(width: 8),
                Flexible(child: Text(str(context_['title']), style: TextStyle(color: mine ? Colors.white : Brand.ink, fontWeight: FontWeight.w600))),
              ]),
            ),
          if (context_ != null && context_['type'] == 'order')
            InkWell(
              onTap: () => context.push('/orders/${context_['order_number']}'),
              child: Text('Order ${context_['order_number']}', style: TextStyle(color: mine ? Colors.white : Brand.blue, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
            ),
          if (message.body != null)
            mine || onSend == null
                ? SelectableText(message.body!, style: TextStyle(color: mine ? Colors.white : Brand.ink, height: 1.35))
                : _body(message.body!),
          _FileChips(files: message.attachments, light: mine),
          const SizedBox(height: 4),
          Text(
            [if (!mine && message.author != null) message.author!, if (message.createdAt != null) _when.format(message.createdAt!)].join(' · '),
            style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : Colors.grey.shade600),
          ),
        ]),
      ),
    );
  }
}

class _FileChips extends StatelessWidget {
  const _FileChips({required this.files, this.light = false});
  final List<FileLink> files;
  final bool light;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final f in files)
          f.kind == 'image'
              ? GestureDetector(onTap: () => openExternal(context, f.url), child: SizedBox(width: 120, height: 120, child: NetImage(f.url)))
              : ActionChip(
                  avatar: Icon(f.kind == 'video' ? Icons.play_circle_outline : Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(f.kind == 'video' ? 'Video' : 'Document'),
                  onPressed: () => openExternal(context, f.url),
                ),
      ]),
    );
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments({required this.files, required this.onChanged, required this.max});
  final List<String> files;
  final VoidCallback onChanged;
  final int max;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton.icon(
          onPressed: files.length >= max
              ? null
              : () async {
                  final picked = await pickFiles(context);
                  files.addAll(picked.take(max - files.length));
                  onChanged();
                },
          icon: const Icon(Icons.attach_file),
          label: Text(files.isEmpty ? 'Add photos, video or PDF' : 'Add another'),
        ),
        for (final f in files)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(f.split('/').last, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () {
              files.remove(f);
              onChanged();
            }),
          ),
      ]);
}
