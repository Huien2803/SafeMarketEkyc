import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/core/constants/app_decorations.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/ekyc_models.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/ekyc_service.dart';

/// Màn hình xác thực danh tính (eKYC) - 4 bước:
///   1. intro:        hướng dẫn chuẩn bị
///   2. frontIdCard:  chụp mặt trước CCCD -> FPT.AI OCR
///   3. backIdCard:   chụp mặt sau CCCD -> FPT.AI OCR
///   4. liveness:     kiểm tra người thật
///   5. selfie:       chụp selfie -> Face Match -> submit
///   -> result
enum _EkycStep { intro, frontIdCard, backIdCard, liveness, selfie, result }

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

  // Dữ liệu giữa các bước
  File? _frontFile;
  File? _backFile;
  File? _livenessFile;
  File? _selfieFile;
  IdCardFront? _frontData;
  IdCardBack? _backData;
  FaceMatchResult? _matchResult;
  EkycStatus? _finalStatus;
  String? _livenessToken;

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
    switch (_step) {
      case _EkycStep.intro:
        return _IntroView(onStart: () => _setStep(_EkycStep.frontIdCard));
      case _EkycStep.frontIdCard:
        return _CaptureView(
          stepIndex: 1,
          totalSteps: 4,
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
          totalSteps: 4,
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
        return _CaptureView(
          stepIndex: 3,
          totalSteps: 4,
          title: 'KIỂM TRA NGƯỜI THẬT',
          subtitle:
              'Chụp selfie để xác minh bạn là người thật (chống ảnh/video giả mạo).',
          icon: Icons.verified_user_outlined,
          selectedFile: _livenessFile,
          busy: _busy,
          errorMessage: _errorMessage,
          dataPreview: _livenessToken != null
              ? const _LivenessPreview()
              : null,
          primaryLabel: _livenessToken == null ? 'Kiểm tra liveness' : 'Tiếp tục',
          onTakePhoto: () => _pickImage(
            ImageSource.camera,
            _setLiveness,
            preferFront: true,
          ),
          onPickGallery: () => _pickImage(ImageSource.gallery, _setLiveness),
          onPrimary: _livenessToken == null ? _runLiveness : () => _setStep(_EkycStep.selfie),
        );
      case _EkycStep.selfie:
        return _CaptureView(
          stepIndex: 4,
          totalSteps: 4,
          title: 'Chụp KHUÔN MẶT',
          subtitle:
              'Nhìn thẳng camera, không đeo kính/khẩu trang. Hệ thống sẽ so khớp với ảnh trên CCCD.',
          icon: Icons.face_retouching_natural,
          selectedFile: _selfieFile,
          busy: _busy,
          errorMessage: _errorMessage,
          dataPreview: _matchResult == null
              ? null
              : _MatchPreview(result: _matchResult!),
          primaryLabel: _matchResult == null
              ? 'So khớp khuôn mặt'
              : (_matchResult!.isMatch ? 'Hoàn tất xác thực' : 'Chụp lại'),
          onTakePhoto: () =>
              _pickImage(ImageSource.camera, _setSelfie, preferFront: true),
          onPickGallery: () => _pickImage(ImageSource.gallery, _setSelfie),
          onPrimary: _matchResult == null
              ? _runFaceMatch
              : (_matchResult!.isMatch
                  ? _submit
                  : () {
                      setState(() {
                        _selfieFile = null;
                        _matchResult = null;
                      });
                    }),
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
      case _EkycStep.selfie:
        _setStep(_EkycStep.liveness);
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

  void _setLiveness(File f) => setState(() {
        _livenessFile = f;
        _livenessToken = null;
        _errorMessage = null;
      });

  void _setSelfie(File f) => setState(() {
        _selfieFile = f;
        _matchResult = null;
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

  Future<void> _runLiveness() async {
    if (_livenessFile == null) {
      _showError('Chụp selfie để kiểm tra liveness');
      return;
    }
    await _runApi(() async {
      final result = await EkycService.instance.livenessCheck(_livenessFile!);
      final passed = result['passed'] == true;
      if (!passed) {
        _errorMessage = 'Liveness chưa đạt. Hãy chụp lại với khuôn mặt thật.';
        return;
      }
      _livenessToken = result['livenessToken'] as String? ?? 'live-ok';
    });
  }

  Future<void> _runFaceMatch() async {
    if (_selfieFile == null || _frontFile == null) {
      _showError('Thiếu ảnh CCCD hoặc selfie');
      return;
    }
    await _runApi(() async {
      _matchResult = await EkycService.instance.faceMatch(
        idCard: _frontFile!,
        selfie: _selfieFile!,
      );
      if (!_matchResult!.isMatch) {
        _errorMessage =
            'Khuôn mặt chưa khớp (similarity ${(_matchResult!.similarity * 100).toStringAsFixed(1)}%). Hãy chụp lại.';
      }
    });
  }

  Future<void> _submit() async {
    if (_frontData == null || _matchResult == null || _livenessToken == null) {
      _showError('Thiếu dữ liệu để submit eKYC (cần hoàn tất liveness)');
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
        faceSimilarity: _matchResult!.similarity,
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

class _LivenessPreview extends StatelessWidget {
  const _LivenessPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: const Row(
        children: [
          Icon(Icons.verified_user, color: AppColors.trustGreen, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Liveness đạt — xác thực người thật thành công',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.trustGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPreview extends StatelessWidget {
  const _MatchPreview({required this.result});
  final FaceMatchResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.isMatch;
    final color = ok ? AppColors.trustGreen : AppColors.danger;
    final pct = (result.similarity * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified : Icons.error_outline,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Khuôn mặt khớp' : 'Khuôn mặt KHÔNG khớp',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Độ giống nhau: $pct%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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
              'Hệ thống dùng AI FPT.AI để OCR CCCD và so khớp khuôn mặt. '
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
