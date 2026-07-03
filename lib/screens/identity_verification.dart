import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/ekyc_models.dart';
import 'package:safemarket_app/screens/liveness_challenge_screen.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/ekyc_service.dart';

/// Màn hình xác thực danh tính (eKYC) - các bước:
///   1. intro:        hướng dẫn chuẩn bị
///   2. frontIdCard:  chụp mặt trước CCCD -> FPT.AI OCR
///   3. backIdCard:   chụp mặt sau CCCD -> FPT.AI OCR
///   4. liveness:     xác minh khuôn mặt thật + LẤY ĐIỂM NHẬN DẠNG -> submit
///   -> result
enum _EkycStep { intro, frontIdCard, backIdCard, liveness, result }

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  _EkycStep _step = _EkycStep.intro;
  bool _busy = false;
  String? _errorMessage;

  /// Đang kiểm tra trạng thái eKYC hiện tại khi mở màn hình.
  bool _checkingStatus = true;

  /// Trạng thái eKYC đã có sẵn (Verified/Pending) -> không cho quét lại.
  EkycStatus? _existingStatus;

  @override
  void initState() {
    super.initState();
    _loadExistingStatus();
  }

  Future<void> _loadExistingStatus() async {
    try {
      final status = await EkycService.instance.getMyStatus();
      if (!mounted) return;
      // Đã Verified hoặc đang Pending -> hiển thị bảng thông tin, ẩn luồng quét.
      final locked = status.isVerified || status.status == 'Pending';
      setState(() {
        _existingStatus = locked ? status : null;
        _checkingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingStatus = false);
    }
  }

  // Dữ liệu giữa các bước
  File? _frontFile;
  File? _backFile;
  File? _faceFile;
  IdCardFront? _frontData;
  IdCardBack? _backData;
  EkycStatus? _finalStatus;
  String? _livenessToken;
  int? _recognitionPoints;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_step == _EkycStep.intro || _step == _EkycStep.result) {
              Navigator.maybePop(context);
            } else {
              _goBackStep();
            }
          },
        ),
        title: const Text(
          'Xác thực danh tính',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_checkingStatus) {
      return const Center(child: CircularProgressIndicator());
    }
    // Đã xác thực / đang chờ duyệt: hiện bảng thông báo + thông tin, không quét lại.
    if (_existingStatus != null && _step != _EkycStep.result) {
      return _AlreadyVerifiedView(
        status: _existingStatus!,
        onDone: () => Navigator.of(context).pop(true),
      );
    }
    switch (_step) {
      case _EkycStep.intro:
        return _IntroView(onStart: () => _setStep(_EkycStep.frontIdCard));
      case _EkycStep.frontIdCard:
        return _CaptureView(
          stepIndex: 1,
          totalSteps: 3,
          title: 'Chụp MẶT TRƯỚC CCCD',
          subtitle:
              'Đặt CCCD trong khung, đảm bảo rõ ảnh và 4 góc. Tránh lóa sáng.',
          icon: Icons.credit_card,
          selectedFile: _frontFile,
          busy: _busy,
          errorMessage: _errorMessage,
          dataPreview: _frontData == null
              ? null
              : _FrontDataPreview(data: _frontData!),
          primaryLabel: _frontData == null ? 'Quét bằng FPT.AI' : 'Tiếp tục',
          onTakePhoto: () => _pickImage(ImageSource.camera, _setFront),
          onPickGallery: () => _pickImage(ImageSource.gallery, _setFront),
          onPrimary: _frontData == null
              ? _scanFront
              : () => _setStep(_EkycStep.backIdCard),
        );
      case _EkycStep.backIdCard:
        return _CaptureView(
          stepIndex: 2,
          totalSteps: 3,
          title: 'Chụp MẶT SAU CCCD',
          subtitle: 'Đặt mặt sau (có MRZ + ngày cấp) trong khung.',
          icon: Icons.credit_card_outlined,
          selectedFile: _backFile,
          busy: _busy,
          errorMessage: _errorMessage,
          dataPreview:
              _backData == null ? null : _BackDataPreview(data: _backData!),
          primaryLabel: _backData == null ? 'Quét bằng FPT.AI' : 'Tiếp tục',
          onTakePhoto: () => _pickImage(ImageSource.camera, _setBack),
          onPickGallery: () => _pickImage(ImageSource.gallery, _setBack),
          onPrimary: _backData == null
              ? _scanBack
              : () => _setStep(_EkycStep.liveness),
        );
      case _EkycStep.liveness:
        return _LivenessStartView(
          busy: _busy,
          errorMessage: _errorMessage,
          passed: _recognitionPoints != null,
          pointCount: _recognitionPoints,
          faceFile: _faceFile,
          onStart: _startLiveness,
          onContinue: _submit,
        );
      case _EkycStep.result:
        return _ResultView(
          status: _finalStatus,
          onDone: () => Navigator.of(context).pop(true),
        );
    }
  }

  // ------------------- step navigation -------------------

  void _setStep(_EkycStep s) {
    setState(() {
      _step = s;
      _errorMessage = null;
    });
  }

  void _goBackStep() {
    switch (_step) {
      case _EkycStep.frontIdCard:
        _setStep(_EkycStep.intro);
        break;
      case _EkycStep.backIdCard:
        _setStep(_EkycStep.frontIdCard);
        break;
      case _EkycStep.liveness:
        _setStep(_EkycStep.backIdCard);
        break;
      case _EkycStep.intro:
      case _EkycStep.result:
        Navigator.maybePop(context);
        break;
    }
  }

  // ------------------- pick image -------------------

  Future<void> _pickImage(
    ImageSource source,
    void Function(File f) setter, {
    bool preferFront = false,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        preferredCameraDevice:
            preferFront ? CameraDevice.front : CameraDevice.rear,
      );
      if (picked == null) return;
      setter(File(picked.path));
    } catch (e) {
      _showError('Không mở được camera/album: $e');
    }
  }

  void _setFront(File f) => setState(() {
        _frontFile = f;
        _frontData = null;
        _errorMessage = null;
      });

  void _setBack(File f) => setState(() {
        _backFile = f;
        _backData = null;
        _errorMessage = null;
      });

  // ------------------- API calls -------------------

  Future<void> _scanFront() async {
    if (_frontFile == null) {
      _showError('Bạn chưa chọn ảnh mặt trước CCCD');
      return;
    }
    await _runApi(() async {
      _frontData = await EkycService.instance.scanIdFront(_frontFile!);
    });
  }

  Future<void> _scanBack() async {
    if (_backFile == null) {
      _showError('Bạn chưa chọn ảnh mặt sau CCCD');
      return;
    }
    await _runApi(() async {
      _backData = await EkycService.instance.scanIdBack(_backFile!);
    });
  }

  /// Mở màn xác minh khuôn mặt động (Face ID xoay mặt). Khi đạt, hệ thống
  /// đã LẤY ĐIỂM NHẬN DẠNG khuôn mặt (facial landmarks) thay cho việc so khớp
  /// với ảnh trên CCCD.
  Future<void> _startLiveness() async {
    setState(() => _errorMessage = null);
    final result = await Navigator.of(context).push<LivenessResult>(
      MaterialPageRoute(builder: (_) => const LivenessChallengeScreen()),
    );
    if (!mounted || result == null) return;
    setState(() {
      _faceFile = result.selfieFile;
      _livenessToken = result.token;
      _recognitionPoints = result.pointCount;
      _errorMessage = null;
      _step = _EkycStep.liveness;
    });
  }

  Future<void> _submit() async {
    if (_frontData == null ||
        _livenessToken == null ||
        _recognitionPoints == null) {
      _showError('Thiếu dữ liệu để submit eKYC (cần hoàn tất xác minh khuôn mặt)');
      return;
    }
    await _runApi(() async {
      _finalStatus = await EkycService.instance.submit(
        idNumber: _frontData!.idNumber,
        fullName: _frontData!.fullName,
        dob: _frontData!.dobIso,
        address: _frontData!.address.isNotEmpty
            ? _frontData!.address
            : _frontData!.home,
        recognitionPoints: _recognitionPoints!,
        livenessToken: _livenessToken!,
      );
      _step = _EkycStep.result;
    });
  }

  /// Wrap mọi call API: bật loading, bắt lỗi, setState.
  Future<void> _runApi(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await body();
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Lỗi: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
  }
}

// ====================================================================
//                            SUB WIDGETS
// ====================================================================

class _IntroView extends StatelessWidget {
  const _IntroView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _PhoneIllustration(),
                const SizedBox(height: 32),
                const Text(
                  'Bạn cần chuẩn bị:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const _PreparationCard(
                  icon: Icons.shield,
                  title: 'Căn cước công dân',
                  subtitle: 'Bản gốc, còn hạn sử dụng',
                ),
                const SizedBox(height: 12),
                const _PreparationCard(
                  icon: Icons.person_outline,
                  title: 'Khuôn mặt chính chủ',
                  subtitle: 'Không đeo kính, khẩu trang',
                ),
                const SizedBox(height: 24),
                _SecurityNoticeBox(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              child: const Text('Xác thực ngay'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CaptureView extends StatelessWidget {
  const _CaptureView({
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedFile,
    required this.busy,
    required this.errorMessage,
    required this.dataPreview,
    required this.primaryLabel,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onPrimary,
  });

  final int stepIndex;
  final int totalSteps;
  final String title;
  final String subtitle;
  final IconData icon;
  final File? selectedFile;
  final bool busy;
  final String? errorMessage;
  final Widget? dataPreview;
  final String primaryLabel;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StepProgress(current: stepIndex, total: totalSteps),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _PhotoPreview(file: selectedFile, icon: icon),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onTakePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Chụp ảnh'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onPickGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Từ album'),
                      ),
                    ),
                  ],
                ),
                if (dataPreview != null) ...[
                  const SizedBox(height: 16),
                  dataPreview!,
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBox(message: errorMessage!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (busy || selectedFile == null) ? null : onPrimary,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Text(primaryLabel),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i < current;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.file, required this.icon});
  final File? file;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE3EDFF),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: file == null
            ? Center(
                child: Icon(icon, color: AppColors.primary, size: 64),
              )
            : Image.file(file!, fit: BoxFit.cover),
      ),
    );
  }
}

class _FrontDataPreview extends StatelessWidget {
  const _FrontDataPreview({required this.data});
  final IdCardFront data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.trustGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'FPT.AI đã nhận diện CCCD',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.trustGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _KvRow(label: 'Số CCCD', value: data.idNumber),
          _KvRow(label: 'Họ và tên', value: data.fullName),
          _KvRow(label: 'Ngày sinh', value: data.dob),
          _KvRow(label: 'Giới tính', value: data.sex),
          _KvRow(label: 'Quê quán', value: data.home),
          _KvRow(label: 'Địa chỉ', value: data.address),
        ],
      ),
    );
  }
}

class _BackDataPreview extends StatelessWidget {
  const _BackDataPreview({required this.data});
  final IdCardBack data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.trustGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Đã đọc mặt sau',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.trustGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _KvRow(label: 'Ngày cấp', value: data.issueDate),
          _KvRow(label: 'Nơi cấp', value: data.issueLoc),
          if (data.features.isNotEmpty)
            _KvRow(label: 'Đặc điểm', value: data.features),
        ],
      ),
    );
  }
}

class _LivenessStartView extends StatelessWidget {
  const _LivenessStartView({
    required this.busy,
    required this.errorMessage,
    required this.passed,
    required this.pointCount,
    required this.faceFile,
    required this.onStart,
    required this.onContinue,
  });

  final bool busy;
  final String? errorMessage;
  final bool passed;
  final int? pointCount;
  final File? faceFile;
  final VoidCallback onStart;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepProgress(current: 3, total: 3),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'XÁC MINH KHUÔN MẶT & LẤY ĐIỂM NHẬN DẠNG',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hệ thống sẽ yêu cầu bạn nhìn thẳng rồi quay đầu theo hướng dẫn '
                  '(giống Face ID) để lấy các điểm nhận dạng trên khuôn mặt. '
                  'Ảnh tĩnh hoặc đồ vật sẽ không thể vượt qua.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EDFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (passed && faceFile != null)
                        ? Image.file(faceFile!, fit: BoxFit.cover)
                        : Icon(
                            passed
                                ? Icons.verified
                                : Icons.face_retouching_natural,
                            color: passed
                                ? AppColors.trustGreen
                                : AppColors.primary,
                            size: 72,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                const _LivenessStepHint(
                  index: 1,
                  text: 'Nhìn thẳng vào camera, mở mắt',
                ),
                const _LivenessStepHint(
                  index: 2,
                  text: 'Quay đầu sang TRÁI',
                ),
                const _LivenessStepHint(
                  index: 3,
                  text: 'Quay đầu sang PHẢI',
                ),
                if (passed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.card(),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint,
                            color: AppColors.trustGreen, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đã lấy điểm nhận dạng khuôn mặt',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.trustGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Thu được ${pointCount ?? 0} điểm nhận dạng',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBox(message: errorMessage!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : (passed ? onContinue : onStart),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Text(passed
                      ? 'Hoàn tất xác thực'
                      : 'Bắt đầu xác minh khuôn mặt'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LivenessStepHint extends StatelessWidget {
  const _LivenessStepHint({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.status, required this.onDone});
  final EkycStatus? status;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final verified = status?.isVerified ?? false;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.ekycVerifiedBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              color: AppColors.trustGreen,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            verified ? 'Xác thực thành công!' : 'Hồ sơ đã gửi',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verified
                ? 'Tài khoản đã được nâng cấp lên TIN CẬY (Verified). '
                    'Bạn được +50 điểm tín nhiệm.'
                : 'Hồ sơ của bạn đang chờ duyệt.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (status != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: Column(
                children: [
                  _KvRow(label: 'Họ tên', value: status!.fullName ?? '—'),
                  _KvRow(label: 'Số CCCD', value: status!.idNumber ?? '—'),
                  _KvRow(label: 'Ngày sinh', value: status!.dob ?? '—'),
                  _KvRow(label: 'Trạng thái', value: status!.status),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bảng thông báo khi tài khoản ĐÃ xác thực (hoặc đang chờ duyệt) —
/// thay cho luồng quét, không cho xác thực lại.
class _AlreadyVerifiedView extends StatelessWidget {
  const _AlreadyVerifiedView({required this.status, required this.onDone});
  final EkycStatus status;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final verified = status.isVerified;
    final pending = status.status == 'Pending';

    final Color accent =
        verified ? AppColors.trustGreen : AppColors.warningIcon;
    final IconData icon =
        verified ? Icons.verified_user : Icons.hourglass_top_rounded;
    final String title =
        verified ? 'Tài khoản đã được xác thực' : 'Hồ sơ đang chờ duyệt';
    final String subtitle = verified
        ? 'Bạn đã hoàn tất xác thực danh tính (eKYC). Không cần xác thực lại.'
        : 'Hồ sơ eKYC của bạn đã được gửi và đang chờ quản trị viên duyệt.';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Banner thông báo
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: verified
                        ? AppColors.ekycVerifiedBg
                        : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accent, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thông tin xác thực',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(),
                  child: Column(
                    children: [
                      _KvRow(label: 'Họ tên', value: status.fullName ?? '—'),
                      _KvRow(label: 'Số CCCD', value: status.idNumber ?? '—'),
                      _KvRow(label: 'Ngày sinh', value: status.dob ?? '—'),
                      _KvRow(label: 'Địa chỉ', value: status.address ?? '—'),
                      _KvRow(
                        label: 'Trạng thái',
                        value: verified
                            ? 'Đã xác thực'
                            : (pending ? 'Chờ duyệt' : status.status),
                      ),
                      if (status.submittedAt != null)
                        _KvRow(
                          label: 'Ngày gửi',
                          value: _fmtDate(status.submittedAt!),
                        ),
                      if (status.verifiedAt != null)
                        _KvRow(
                          label: 'Ngày duyệt',
                          value: _fmtDate(status.verifiedAt!),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              child: const Text('Đóng'),
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

// ====================================================================
//                       Widgets giữ nguyên từ bản cũ
// ====================================================================

class _PhoneIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFE3EDFF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Container(
            width: 80,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNoticeBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: AppColors.warningIcon, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hệ thống dùng AI FPT.AI để OCR CCCD và lấy điểm nhận dạng khuôn mặt. '
              'Thông tin được mã hóa, chỉ dùng để xác thực danh tính.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
