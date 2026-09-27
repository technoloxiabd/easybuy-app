import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/api_error.dart';
import '../../core/theme.dart';

/// The server's message when it sent one; a plain sentence otherwise.
String messageOf(Object error) =>
    error is ApiError ? error.message : 'Something went wrong. Please try again.';

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Brand.danger : Brand.ink,
      behavior: SnackBarBehavior.floating,
    ));
}

void showError(BuildContext context, Object error) => showMessage(context, messageOf(error), error: true);

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiError && (error as ApiError).code == 'offline';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 44, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(messageOf(error), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Brand.blue.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

/// A remote image with a neutral placeholder; supplier images come from
/// alicdn through the site's image proxy, so they are safe to cache.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.radius = 10});
  final String? url;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : CachedNetworkImage(imageUrl: url!, fit: fit, placeholder: (_, _) => placeholder, errorWidget: (_, _, _) => placeholder),
    );
  }
}

/// A coloured note: warnings, blockers, confirmations.
class NoticeBox extends StatelessWidget {
  const NoticeBox(this.text, {super.key, this.tone = NoticeTone.warning, this.icon});
  final String text;
  final NoticeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, defaultIcon) = switch (tone) {
      NoticeTone.warning => (const Color(0xFFFFF7ED), Brand.warning, Icons.info_outline),
      NoticeTone.danger => (const Color(0xFFFEF2F2), Brand.danger, Icons.error_outline),
      NoticeTone.success => (const Color(0xFFF0FDF4), Brand.success, Icons.check_circle_outline),
      NoticeTone.info => (const Color(0xFFEFF6FF), Brand.blue, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? defaultIcon, size: 18, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.35))),
      ]),
    );
  }
}

enum NoticeTone { warning, danger, success, info }

/// A white card with a title, the building block of detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null) ...[
              Row(children: [
                Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                ?trailing,
              ]),
              const SizedBox(height: 10),
            ],
            child,
          ]),
        ),
      );
}

/// label ....... value, for statements and summaries.
class LabelValue extends StatelessWidget {
  const LabelValue(this.label, this.value, {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: bold ? FontWeight.w700 : null))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'delivered' => Brand.success,
      'cancelled' || 'refunded' || 'rejected' => Brand.danger,
      'pending_payment' || 'pending' || 'ready_for_delivery' => Brand.warning,
      _ => Brand.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Shows a spinner on a button while [task] runs, and the error if it fails.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.outlined = false, this.icon});
  final String label;
  final Future<void> Function()? onPressed;
  final bool outlined;
  final IconData? icon;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final child = _busy
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Text(widget.label);
    if (widget.outlined) {
      return OutlinedButton(onPressed: onPressed, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text(widget.label));
    }
    return widget.icon != null && !_busy
        ? FilledButton.icon(onPressed: onPressed, icon: Icon(widget.icon), label: child)
        : FilledButton(onPressed: onPressed, child: child);
  }
}
