import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/json.dart';

/// "A new version of EasyBuy is available" (owner, 1 Oct 2026). The admin
/// records each release under Settings › Mobile app: its build number, the
/// oldest build still allowed, and the store link. An older build is asked
/// to update; "Later" puts the question off for three days. A build below
/// the minimum cannot carry on until it is updated.
class UpdatePrompt {
  UpdatePrompt(this._api, this._context);

  final EasyBuyApi _api;

  /// The router's navigator context: the dialog needs a Navigator above it.
  final BuildContext? Function() _context;

  static const _laterKey = 'update_later';
  static const _snooze = Duration(days: 3);

  /// Asked again when the app comes back to the front after this long.
  static const _recheckAfter = Duration(hours: 6);

  DateTime? _checkedAt;
  bool _showing = false;

  Future<void> check() async {
    if (kIsWeb || _showing) return;
    if (_checkedAt != null && DateTime.now().difference(_checkedAt!) < _recheckAfter) return;
    _checkedAt = DateTime.now();
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final r = await _api.appVersion(Platform.isIOS ? 'ios' : 'android', build);
      if (!boolean(r['update_available'])) return;

      final latest = integer(r['latest_build']);
      final required = boolean(r['update_required']);
      final prefs = await SharedPreferences.getInstance();
      if (!required) {
        // "<build>@<when>": Later on this release, not on the next one.
        final later = (prefs.getString(_laterKey) ?? '').split('@');
        final when = later.length == 2 ? DateTime.fromMillisecondsSinceEpoch(int.tryParse(later[1]) ?? 0) : null;
        if (later.first == '$latest' && when != null && DateTime.now().difference(when) < _snooze) return;
      }

      final context = _context();
      if (context == null || !context.mounted) return;
      _showing = true;
      final later = await showDialog<bool>(
        context: context,
        barrierDismissible: !required,
        builder: (_) => _UpdateDialog(
          version: strOrNull(r['version']),
          notes: strOrNull(r['notes']),
          url: str(r['update_url']),
          required: required,
        ),
      );
      _showing = false;
      if (later == true) await prefs.setString(_laterKey, '$latest@${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {
      // No answer (offline, or the server is busy): asked again next time.
      _checkedAt = null;
      _showing = false;
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.version, required this.notes, required this.url, required this.required});
  final String? version;
  final String? notes;
  final String url;
  final bool required;

  @override
  Widget build(BuildContext context) => PopScope(
        // A required update holds the app: back does not close it.
        canPop: !required,
        child: AlertDialog(
          icon: const Icon(Icons.system_update_rounded, size: 36, color: Brand.blue),
          title: Text(required ? 'Please update EasyBuy' : 'A new version is available'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              required
                  ? 'This version of the app is no longer supported. Update to keep shopping.'
                  : 'Update EasyBuy${version == null ? '' : ' to $version'} for the latest features and fixes.',
              style: const TextStyle(height: 1.4),
            ),
            if (notes != null && notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("What's new", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(notes!.trim(), style: const TextStyle(color: Brand.grayText, height: 1.4)),
            ],
          ]),
          actions: [
            if (!required) TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Later')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.blue),
              onPressed: () {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).ignore();
                // Left open when required: coming back without updating
                // finds it still there.
                if (!required) Navigator.pop(context, false);
              },
              child: const Text('Update now'),
            ),
          ],
        ),
      );
}
