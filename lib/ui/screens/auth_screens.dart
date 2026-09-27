import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// What "signed-in devices" will call this phone.
String deviceName() {
  try {
    return Platform.isIOS ? 'EasyBuy app (iPhone)' : 'EasyBuy app (Android)';
  } catch (_) {
    return 'EasyBuy app';
  }
}

void _backTo(BuildContext context, String? from) {
  if (from != null && from.isNotEmpty) {
    context.go('/');
    context.push(from);
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go('/account');
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: children),
        ),
      );
}

// ------------------------------------------------------------------ sign in

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  ApiError? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).signIn(_login.text.trim(), _password.text, deviceName());
      if (mounted) _backTo(context, widget.from);
    } on ApiError catch (e) {
      setState(() => _error = e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(title: 'Sign in', children: [
        const Text('Welcome back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Brand.blue)),
        const SizedBox(height: 4),
        Text('Sign in with your mobile number or email.', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 24),
        TextField(
          controller: _login,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.telephoneNumber, AutofillHints.email],
          decoration: InputDecoration(labelText: 'Mobile number or email', errorText: _error?.fieldError('login')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _hide,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit().catchError((_) {}),
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility : Icons.visibility_off)),
          ),
        ),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?'))),
        const SizedBox(height: 8),
        BusyButton(label: 'Sign in', onPressed: _submit),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('New to EasyBuy?'),
          TextButton(
            onPressed: () => context.pushReplacement('/register${widget.from != null ? '?from=${Uri.encodeComponent(widget.from!)}' : ''}'),
            child: const Text('Create an account'),
          ),
        ]),
      ]);
}

// ------------------------------------------------------------------ register

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  ApiError? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).register(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            password: _password.text,
            device: deviceName(),
          );
      if (!mounted) return;
      // A new number is unverified; checkout will need it, so ask now.
      context.pushReplacement('/verify-phone${widget.from != null ? '?from=${Uri.encodeComponent(widget.from!)}' : ''}');
    } on ApiError catch (e) {
      setState(() => _error = e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(title: 'Create account', children: [
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Your name', errorText: _error?.fieldError('name'))),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Mobile number', hintText: '01XXXXXXXXX', errorText: _error?.fieldError('phone'))),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email (optional)', errorText: _error?.fieldError('email'))),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'Password (8+ characters)', errorText: _error?.fieldError('password'))),
        const SizedBox(height: 20),
        BusyButton(label: 'Create account', onPressed: _submit),
      ]);
}

// ------------------------------------------------------------------ forgot

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _login = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  /// 'email' once a link was mailed, 'sms' once a code was texted.
  String? _channel;
  ApiError? _error;

  @override
  void dispose() {
    for (final c in [_login, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _error = null);
    try {
      final r = await ref.read(apiProvider).forgotPassword(_login.text.trim());
      setState(() => _channel = '${r['channel'] ?? 'email'}');
    } on ApiError catch (e) {
      setState(() => _error = e);
      rethrow;
    }
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    try {
      await ref.read(apiProvider).resetPassword(phone: _login.text.trim(), code: _code.text.trim(), password: _password.text);
      if (!mounted) return;
      showMessage(context, 'Password changed. Sign in with the new one.');
      context.pop();
    } on ApiError catch (e) {
      setState(() => _error = e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(title: 'Reset password', children: [
        if (_channel == null) ...[
          const Text('Enter your mobile number or email. We will send you a code or a reset link.'),
          const SizedBox(height: 16),
          TextField(controller: _login, decoration: InputDecoration(labelText: 'Mobile number or email', errorText: _error?.fieldError('login'))),
          const SizedBox(height: 16),
          BusyButton(label: 'Continue', onPressed: _request),
        ] else if (_channel == 'email') ...[
          const NoticeBox('If that email has an account, a reset link is on its way. Open it on this phone to choose a new password.', tone: NoticeTone.success),
        ] else ...[
          const NoticeBox('If that number has an account, we have texted it a 6-digit code.', tone: NoticeTone.success),
          const SizedBox(height: 16),
          TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: 'Code', errorText: _error?.fieldError('code'))),
          TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'New password (8+ characters)', errorText: _error?.fieldError('password'))),
          const SizedBox(height: 16),
          BusyButton(label: 'Set new password', onPressed: _reset),
        ],
      ]);
}

// ------------------------------------------------------------------ verify phone

class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _code = TextEditingController();
  bool _sent = false;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      final r = await ref.read(apiProvider).sendPhoneCode();
      _startWait(int.tryParse('${r['retry_after'] ?? 60}') ?? 60);
      setState(() => _sent = true);
      if (mounted) showMessage(context, '${r['message'] ?? 'Code sent.'}');
    } on ApiError catch (e) {
      if (e.code == 'phone_already_verified') {
        await ref.read(authProvider.notifier).reload();
        if (mounted) _backTo(context, widget.from);
        return;
      }
      final retry = int.tryParse('${e.meta['retry_after'] ?? ''}');
      if (retry != null) {
        _startWait(retry);
        setState(() => _sent = true);
      }
      rethrow;
    }
  }

  void _startWait(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      if (mounted) setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
    });
  }

  Future<void> _verify() async {
    final user = await ref.read(apiProvider).verifyPhone(_code.text.trim());
    ref.read(authProvider.notifier).setUser(user);
    if (!mounted) return;
    showMessage(context, 'Your number is verified.');
    _backTo(context, widget.from);
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authProvider).value?.phone ?? '';
    return _AuthScaffold(title: 'Verify your number', children: [
      Text('We send a one-time code to $phone. Placing an order needs a verified number.', style: const TextStyle(height: 1.4)),
      const SizedBox(height: 20),
      if (!_sent)
        BusyButton(label: 'Send code', onPressed: _send)
      else ...[
        TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, autofocus: true, decoration: const InputDecoration(labelText: '6-digit code')),
        const SizedBox(height: 8),
        BusyButton(label: 'Verify', onPressed: _verify),
        TextButton(onPressed: _wait > 0
              ? null
              : () => _send().catchError((Object e) {
                    if (context.mounted) showError(context, e);
                  }), child: Text(_wait > 0 ? 'Send again in $_wait s' : 'Send again')),
      ],
      const SizedBox(height: 8),
      TextButton(onPressed: () => _backTo(context, null), child: const Text('Later')),
    ]);
  }
}
