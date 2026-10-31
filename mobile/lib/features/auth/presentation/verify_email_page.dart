import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_controller.dart';
import 'verify_code_screen.dart';

/// Подтверждение email после регистрации или входа с неподтверждённым адресом.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  /// Сервер разрешает повторную отправку не чаще раза в минуту.
  static const resendCooldown = Duration(seconds: 60);

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _code = TextEditingController();
  Timer? _timer;
  var _left = VerifyEmailPage.resendCooldown;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _left = VerifyEmailPage.resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left -= const Duration(seconds: 1));
      if (_left <= Duration.zero) t.cancel();
    });
  }

  Future<void> _submit(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(code);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.userMessage);
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authControllerProvider.notifier).resendCode();
      setState(() => _error = null);
      _startCooldown();
    } on ApiException catch (e) {
      setState(() => _error = e.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final email = auth is AwaitingVerification ? auth.email : '';
    return VerifyCodeScreen(
      maskedEmail: maskEmail(email),
      controller: _code,
      resendIn: _left > Duration.zero ? _left : null,
      errorText: _error,
      busy: _busy,
      onBack: ref.read(authControllerProvider.notifier).cancelVerification,
      onSubmit: _submit,
      onResend: _resend,
    );
  }
}
