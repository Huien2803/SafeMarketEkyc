import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/screens/marketplace_home.dart';
import 'package:safemarket_app/services/auth_service.dart';

/// Màn nhập mã OTP gửi về email khi đăng ký.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.displayName,
    required this.location,
    required this.expiresInSeconds,
    this.devOtp,
  });

  final String email;
  final String phoneNumber;
  final String password;
  final String displayName;
  final String? location;
  final int expiresInSeconds;
  final String? devOtp;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.devOtp != null) {
      _otpCtrl.text = widget.devOtp!;
    }
    _startCountdown(widget.expiresInSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
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

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ 6 chữ số OTP')),
      );
      return;
    }
    setState(() => _verifying = true);
    try {
      final auth = await AuthService.instance.verifyRegisterOtp(
        email: widget.email,
        otp: otp,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đăng ký thành công! Chào ${auth.user.displayName ?? auth.user.email}',
          ),
          backgroundColor: AppColors.trustGreen,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MarketplaceHomeScreen()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > widget.expiresInSeconds - 30) return;
    setState(() => _resending = true);
    try {
      final result = await AuthService.instance.requestRegisterOtp(
        phoneNumber: widget.phoneNumber,
        email: widget.email,
        password: widget.password,
        displayName: widget.displayName,
        location: widget.location,
      );
      if (!mounted) return;
      _startCountdown(result.expiresInSeconds);
      if (result.devOtp != null) {
        _otpCtrl.text = result.devOtp!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.devOtp != null
                ? 'Mã OTP dev: ${result.devOtp}'
                : (result.message ?? 'Đã gửi lại mã OTP tới email'),
          ),
          backgroundColor: AppColors.trustGreen,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _countdownText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= widget.expiresInSeconds - 30;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Xác thực email',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Nhập mã OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.devOtp != null
                    ? 'Chế độ dev — mã OTP: ${widget.devOtp}\n(Gửi tới ${widget.email} khi đã cấu hình SMTP)'
                    : 'Chúng tôi đã gửi mã 6 chữ số tới\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 12),
              Text(
                _secondsLeft > 0
                    ? 'Mã hết hạn sau $_countdownText'
                    : 'Mã đã hết hạn, vui lòng gửi lại',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _secondsLeft > 0
                      ? AppColors.textSecondary
                      : AppColors.danger,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Xác nhận',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (!canResend || _resending) ? null : _resend,
                child: _resending
                    ? const Text('Đang gửi lại...')
                    : Text(
                        canResend
                            ? 'Gửi lại mã'
                            : 'Gửi lại mã sau ${(_secondsLeft - (widget.expiresInSeconds - 30)).clamp(0, 30)}s',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
