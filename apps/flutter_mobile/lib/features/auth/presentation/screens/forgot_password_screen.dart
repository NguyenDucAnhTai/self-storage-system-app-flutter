import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController(),
      _otp = TextEditingController(),
      _password = TextEditingController();
  bool _sent = false, _busy = false;
  String? _message, _error;
  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        if (_sent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Email code'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
        ],
        if (_message != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const CircularProgressIndicator()
              : Text(_sent ? 'Set new password' : 'Send reset code'),
        ),
      ],
    ),
  );
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      if (!_sent) {
        await dio.post(
          '/auth/forgot-password',
          data: {'email': _email.text.trim()},
        );
        if (mounted) setState(() => _sent = true);
      } else {
        if (_otp.text.length != 6 || _password.text.length < 6) {
          throw ArgumentError(
            'Enter a 6-digit code and password of at least 6 characters.',
          );
        }
        await dio.post(
          '/auth/reset-password',
          data: {
            'email': _email.text.trim(),
            'otp': _otp.text.trim(),
            'newPassword': _password.text,
          },
        );
        if (mounted) {
          setState(() => _message = 'Password updated. Return to sign in.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
