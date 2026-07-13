import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/utils/input_validators.dart';

/// Quên mật khẩu: nhập email nhận OTP -> nhập OTP + mật khẩu mới.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  bool _showPassword = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Vui lòng nhập email hợp lệ', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final result =
          await AuthService.instance.requestPasswordResetOtp(email: email);
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startCountdown(result.expiresInSeconds);
      if (result.devOtp != null) {
        _otpCtrl.text = result.devOtp!;
        _snack('Mã OTP (dev): ${result.devOtp}');
      } else {
        _snack(result.message ?? 'Đã gửi mã OTP tới email của bạn.');
      }
    } on AuthException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (otp.length != 6) {
      _snack('Nhập đủ 6 chữ số OTP', error: true);
      return;
    }
    final passErr = InputValidators.strongPassword(pass);
    if (passErr != null) {
      _snack(passErr, error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final msg = await AuthService.instance.resetPassword(
        email: _emailCtrl.text.trim(),
        otp: otp,
        newPassword: pass,
      );
      if (!mounted) return;
      _snack(msg);
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : AppColors.trustGreen,
      ),
    );
  }

  String get _countdownText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Quên mật khẩu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset_outlined,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                _otpSent ? 'Đặt lại mật khẩu' : 'Khôi phục tài khoản',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Nhập mã OTP đã gửi tới ${_emailCtrl.text.trim()} và mật khẩu mới.'
                    : 'Nhập email đã đăng ký, chúng tôi sẽ gửi mã OTP để đặt lại mật khẩu.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailCtrl,
                enabled: !_otpSent,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(
                  label: 'Email',
                  icon: Icons.email_outlined,
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: _decoration(
                    label: 'Mã OTP (6 chữ số)',
                    icon: Icons.pin_outlined,
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  decoration: _decoration(
                    label: 'Mật khẩu mới',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _secondsLeft > 0
                      ? 'Mã hết hạn sau $_countdownText'
                      : 'Mã đã hết hạn, hãy gửi lại',
                  style: TextStyle(
                    fontSize: 13,
                    color: _secondsLeft > 0
                        ? AppColors.textSecondary
                        : AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : (_otpSent ? _resetPassword : _requestOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _otpSent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_loading || _secondsLeft > 0) ? null : _requestOtp,
                  child: Text(
                    _secondsLeft > 0 ? 'Gửi lại mã sau $_countdownText' : 'Gửi lại mã',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }
}
