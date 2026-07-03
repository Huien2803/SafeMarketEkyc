import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';

/// Kết quả của bước xác minh khuôn mặt sống (active liveness).
class LivenessResult {
  LivenessResult({
    required this.selfieFile,
    required this.token,
    required this.pointCount,
  });

  /// Ảnh khuôn mặt nhìn thẳng chụp được trong quá trình thử thách.
  final File selfieFile;

  /// Token xác nhận đã vượt qua liveness (gửi kèm khi submit eKYC).
  final String token;

  /// Số điểm nhận dạng khuôn mặt (facial landmarks) thu được — thay cho
  /// việc so khớp với ảnh trên CCCD.
  final int pointCount;
}

/// Các bước thử thách kiểu Face ID.
enum _Challenge { straight, turnLeft, turnRight, done }

/// Màn xác minh khuôn mặt THẬT theo kiểu Apple Face ID:
///   1. Nhìn thẳng vào camera (phát hiện đúng 1 khuôn mặt thật, mắt mở)
///   2. Quay đầu sang TRÁI
///   3. Quay đầu sang PHẢI
///
/// Vì phải xoay đầu qua nhiều hướng nên ảnh tĩnh / đồ vật (vd: máy sấy)
/// không thể vượt qua được -> chống giả mạo.
class LivenessChallengeScreen extends StatefulWidget {
  const LivenessChallengeScreen({super.key});

  @override
  State<LivenessChallengeScreen> createState() =>
      _LivenessChallengeScreenState();
}

class _LivenessChallengeScreenState extends State<LivenessChallengeScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Timer? _loop;
  bool _processing = false;
  bool _finished = false;

  _Challenge _current = _Challenge.straight;
  String _hint = 'Đưa khuôn mặt vào khung và nhìn thẳng';
  String? _error;

  /// Ảnh nhìn thẳng đã chụp được — dùng làm ảnh đại diện hồ sơ.
  File? _straightShot;

  /// Số điểm nhận dạng khuôn mặt lấy được ở bước nhìn thẳng.
  int _pointCount = 0;

  // Ngưỡng góc quay đầu (độ).
  static const double _turnThreshold = 20;
  static const double _straightThreshold = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      _initFuture = controller.initialize();
      await _initFuture;
      if (!mounted) return;
      setState(() {});
      _startLoop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Không mở được camera trước: $e');
    }
  }

  void _startLoop() {
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _tick();
    });
  }

  Future<void> _tick() async {
    final controller = _controller;
    if (_processing ||
        _finished ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    _processing = true;
    XFile? shot;
    try {
      shot = await controller.takePicture();
      final input = InputImage.fromFilePath(shot.path);
      final faces = await _detector.processImage(input);
      await _evaluate(faces, shot);
    } catch (_) {
      // Bỏ qua frame lỗi, thử lại ở vòng sau.
    } finally {
      _processing = false;
    }
  }

  Future<void> _evaluate(List<Face> faces, XFile shot) async {
    if (_finished) return;

    if (faces.isEmpty) {
      _setHint('Không thấy khuôn mặt — hãy đưa mặt vào giữa khung');
      return;
    }
    if (faces.length > 1) {
      _setHint('Có nhiều khuôn mặt — chỉ để 1 người trong khung');
      return;
    }

    final face = faces.first;
    final yaw = face.headEulerAngleY ?? 0; // trái/phải
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    final eyesOpen =
        (leftEye == null || leftEye > 0.4) && (rightEye == null || rightEye > 0.4);

    switch (_current) {
      case _Challenge.straight:
        if (yaw.abs() <= _straightThreshold && eyesOpen) {
          // Lưu ảnh nhìn thẳng + lấy điểm nhận dạng (facial landmarks).
          _straightShot = File(shot.path);
          _pointCount = _countRecognitionPoints(face);
          _advance(_Challenge.turnLeft, 'Tốt! Bây giờ quay đầu sang TRÁI');
        } else if (!eyesOpen) {
          _setHint('Hãy mở mắt và nhìn thẳng vào camera');
        } else {
          _setHint('Nhìn thẳng vào camera');
        }
        break;
      case _Challenge.turnLeft:
        if (yaw >= _turnThreshold) {
          _advance(_Challenge.turnRight, 'Tuyệt! Giờ quay đầu sang PHẢI');
        } else {
          _setHint('Quay đầu từ từ sang TRÁI');
        }
        break;
      case _Challenge.turnRight:
        if (yaw <= -_turnThreshold) {
          _complete();
        } else {
          _setHint('Quay đầu từ từ sang PHẢI');
        }
        break;
      case _Challenge.done:
        break;
    }
  }

  /// Đếm số điểm nhận dạng khuôn mặt: các landmark (mắt, mũi, miệng, tai, má)
  /// cộng với số đường contour phát hiện được.
  int _countRecognitionPoints(Face face) {
    final landmarks =
        face.landmarks.values.where((l) => l != null).length;
    final contours =
        face.contours.values.where((c) => c != null && c.points.isNotEmpty).length;
    return landmarks + contours;
  }

  void _advance(_Challenge next, String hint) {
    if (!mounted) return;
    setState(() {
      _current = next;
      _hint = hint;
    });
  }

  void _setHint(String h) {
    if (!mounted || _hint == h) return;
    setState(() => _hint = h);
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    _loop?.cancel();
    final selfie = _straightShot;
    if (selfie == null) {
      // Hiếm khi xảy ra: chưa kịp lưu ảnh thẳng.
      setState(() {
        _finished = false;
        _current = _Challenge.straight;
        _hint = 'Hãy nhìn thẳng lại để chụp khuôn mặt';
      });
      _startLoop();
      return;
    }
    setState(() {
      _current = _Challenge.done;
      _hint = 'Xác minh khuôn mặt thành công!';
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context).pop(
        LivenessResult(
          selfieFile: selfie,
          token: 'live-${DateTime.now().millisecondsSinceEpoch}',
          pointCount: _pointCount,
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _loop?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (!_finished) _startLoop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop?.cancel();
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  int get _stepNumber {
    switch (_current) {
      case _Challenge.straight:
        return 1;
      case _Challenge.turnLeft:
        return 2;
      case _Challenge.turnRight:
        return 3;
      case _Challenge.done:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Xác minh khuôn mặt'),
      ),
      body: _error != null
          ? _buildError()
          : (_controller == null || !_controller!.value.isInitialized)
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _buildCamera(),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    final done = _current == _Challenge.done;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: ClipOval(
            child: SizedBox(
              width: 300,
              height: 380,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? 300,
                  height: _controller!.value.previewSize?.width ?? 380,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        ),
        // Vòng tròn viền
        Center(
          child: Container(
            width: 304,
            height: 384,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? AppColors.trustGreen : AppColors.primary,
                width: 4,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Column(
            children: [
              if (!done)
                Text(
                  'Bước $_stepNumber / 3',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: done ? AppColors.trustGreen : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              if (done) ...[
                const SizedBox(height: 12),
                const Icon(Icons.verified,
                    color: AppColors.trustGreen, size: 48),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
