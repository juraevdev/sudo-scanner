import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app_settings/app_settings.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/student.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/face_frame.dart';
import 'registration_sheet.dart';
import 'student_screen.dart';

enum _Tone { info, warn, error, success }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  static const _idleMessage = 'Yuzingizni doira ichiga joylashtiring';
  static const _scanInterval = Duration(milliseconds: 1200);
  static const _idleScanInterval = Duration(milliseconds: 2000);
  static const _retryInterval = Duration(seconds: 2);
  // After a result was shown, the same person standing in front of the
  // camera is ignored until they step away or this time passes.
  static const _holdDuration = Duration(seconds: 6);
  // An unknown face must be seen this many times in a row before the
  // registration form opens, so a single blurry frame can't trigger it.
  static const _newFaceConfirmations = 2;

  final _api = ScannerApi();

  CameraController? _controller;
  bool _initializing = false;
  String? _cameraError;
  bool _permissionDenied = false;

  int _session = 0;
  bool _handlingResult = false;
  int _newFaceStreak = 0;
  DateTime? _holdUntil;
  int? _holdStudentId;

  String _status = 'Kamera ishga tushirilmoqda...';
  _Tone _tone = _Tone.info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLoop();
    _controller?.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final controller = _controller;
      if (controller == null) return;
      _stopLoop();
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed && _controller == null && !_initializing) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _initializing = true;
    setState(() {
      _cameraError = null;
      _permissionDenied = false;
      _setStatus('Kamera ishga tushirilmoqda...', _Tone.info);
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'Kamera topilmadi');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _setStatus(_idleMessage, _Tone.info);
      });
      if (!_handlingResult) _startLoop();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = _cameraErrorText(e);
        _permissionDenied = _isPermissionError(e);
      });
    } finally {
      _initializing = false;
    }
  }

  bool _isPermissionError(CameraException e) => switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' ||
        'cameraPermission' =>
          true,
        _ => false,
      };

  String _cameraErrorText(CameraException e) => switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' ||
        'cameraPermission' =>
          'Kameraga ruxsat berilmagan. Sozlamalardan ruxsat bering.',
        'NoCamera' || 'cameraNotFound' => 'Qurilmada kamera topilmadi.',
        _ => 'Kamerani ishga tushirib bo\'lmadi: ${e.description ?? e.code}',
      };

  void _setStatus(String message, _Tone tone) {
    _status = message;
    _tone = tone;
  }

  void _updateStatus(String message, _Tone tone) {
    if (!mounted || (_status == message && _tone == tone)) return;
    setState(() => _setStatus(message, tone));
  }

  void _startLoop() => _runLoop(++_session);

  void _stopLoop() => _session++;

  Future<void> _deleteTemp(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // Best-effort cleanup.
    }
  }

  Future<void> _runLoop(int session) async {
    while (mounted && session == _session) {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;

      var wait = _scanInterval;
      String? shotPath;
      try {
        final shot = await controller.takePicture();
        shotPath = shot.path;
        final bytes = await shot.readAsBytes();
        if (session != _session) return;
        final result = await _api.scan(bytes);
        if (session != _session) return;
        if (result.status == ScanStatus.noFace) {
          wait = _idleScanInterval;
        }
        if (_handle(result, bytes)) return;
      } on ApiException catch (e) {
        final hint = e.message.contains('aloqa') || e.message.contains('javob')
            ? ' (${_api.baseUrl})'
            : '';
        _updateStatus('${e.message}$hint. Qayta urinilmoqda...', _Tone.error);
        wait = _retryInterval;
      } on CameraException catch (e) {
        _updateStatus('Kamera xatosi: ${e.description ?? e.code}', _Tone.error);
        wait = _retryInterval;
      } on Object {
        _updateStatus('Xato. Qayta urinilmoqda...', _Tone.error);
        wait = _retryInterval;
      } finally {
        await _deleteTemp(shotPath);
      }
      await Future<void>.delayed(wait);
    }
  }

  /// Returns true when the result takes over the screen and the loop must stop.
  bool _handle(ScanResult result, Uint8List bytes) {
    final holding = _holdUntil != null && DateTime.now().isBefore(_holdUntil!);

    if (result.status == ScanStatus.noFace) {
      _holdUntil = null;
      _newFaceStreak = 0;
      _updateStatus(_idleMessage, _Tone.info);
      return false;
    }

    if (result.status == ScanStatus.matched) {
      final student = result.student;
      if (student == null) {
        _updateStatus('Talaba ma\'lumoti kelmadi', _Tone.error);
        return false;
      }
      _newFaceStreak = 0;
      if (holding && student.id == _holdStudentId) {
        _updateStatus('Keyingi talaba kameraga qarasin', _Tone.info);
        return false;
      }
      _updateStatus('${student.fullName} topildi', _Tone.success);
      _showStudent(student, isNew: false);
      return true;
    }

    if (result.status == ScanStatus.newFace) {
      if (holding && _holdStudentId != null) {
        _updateStatus('Keyingi talaba kameraga qarasin', _Tone.info);
        return false;
      }
      final token = result.scanToken;
      if (token == null || token.isEmpty) {
        _updateStatus('Skaner tokeni kelmadi', _Tone.error);
        return false;
      }
      if (++_newFaceStreak < _newFaceConfirmations) {
        _updateStatus('Yuz tekshirilmoqda...', _Tone.info);
        return false;
      }
      _newFaceStreak = 0;
      _updateStatus('Yangi yuz aniqlandi', _Tone.success);
      _register(token, bytes);
      return true;
    }

    _newFaceStreak = 0;
    _updateStatus(result.message, _Tone.warn);
    return false;
  }

  Future<void> _showStudent(Student student, {required bool isNew}) async {
    _handlingResult = true;
    await _setPreviewPaused(true);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentScreen(student: student, api: _api, isNew: isNew),
      ),
    );
    await _resumeScanning(holdStudentId: student.id);
  }

  Future<void> _register(String scanToken, Uint8List faceImage) async {
    _handlingResult = true;
    await _setPreviewPaused(true);
    if (!mounted) return;
    final student = await showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      // Prevent accidental dismiss; Cancel button handles exit.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => RegistrationSheet(
        api: _api,
        scanToken: scanToken,
        faceImage: faceImage,
      ),
    );
    if (!mounted) return;
    if (student != null) {
      await _showStudent(student, isNew: true);
    } else {
      // Cancelled — no hold, allow immediate retry.
      await _resumeScanning(holdStudentId: null, applyHold: false);
    }
  }

  Future<void> _resumeScanning({int? holdStudentId, bool applyHold = true}) async {
    if (!mounted) return;
    _handlingResult = false;
    _newFaceStreak = 0;
    if (applyHold) {
      _holdUntil = DateTime.now().add(_holdDuration);
      _holdStudentId = holdStudentId;
    } else {
      _holdUntil = null;
      _holdStudentId = null;
    }
    await _setPreviewPaused(false);
    _updateStatus(_idleMessage, _Tone.info);
    if (_controller != null) _startLoop();
  }

  Future<void> _setPreviewPaused(bool paused) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPreviewPaused == paused) return;
    try {
      paused ? await controller.pausePreview() : await controller.resumePreview();
    } on CameraException {
      // Not every platform supports pausing; the preview simply keeps running.
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final diameter = math.min(size.width - 72, size.height * 0.42).clamp(0.0, 340.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Row(
                children: [
                  BrandLogo(size: 26, color: AppColors.ink),
                  Spacer(),
                  _Badge(text: 'SCANNER'),
                ],
              ),
              const Spacer(),
              const Text(
                'Yuzni skanerlash',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kameraga to\'g\'ri qarang, tizim sizni avtomatik taniydi',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 32),
              FaceFrame(
                diameter: diameter,
                scanning: _controller != null && _cameraError == null && !_handlingResult,
                color: _cameraError != null ? AppColors.error : AppColors.green,
                child: _buildPreview(),
              ),
              const SizedBox(height: 28),
              _cameraError == null
                  ? _StatusPill(message: _status, tone: _tone)
                  : const _StatusPill(message: 'Kamera ishlamayapti', tone: _Tone.error),
              const Spacer(flex: 2),
              const Text(
                'JizPi IT PARK  •  Student E-Card',
                style: TextStyle(color: Color(0xFFB4B9BF), fontSize: 12, letterSpacing: 0.5),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_cameraError != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _initCamera, child: const Text('Qayta urinish')),
            if (_permissionDenied)
              TextButton(
                onPressed: () => AppSettings.openAppSettings(),
                child: const Text('Sozlamalarni ochish'),
              ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.green),
        ),
      );
    }

    final mobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final ratio = mobile ? 1 / controller.value.aspectRatio : controller.value.aspectRatio;
    Widget preview = CameraPreview(controller);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      preview = Transform.flip(flipX: true, child: preview);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: 100 * ratio, height: 100, child: preview),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.greenDark,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.message, required this.tone});

  final String message;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      _Tone.info => (AppColors.muted, Icons.center_focus_weak_rounded),
      _Tone.warn => (AppColors.warn, Icons.info_outline_rounded),
      _Tone.error => (AppColors.error, Icons.wifi_off_rounded),
      _Tone.success => (AppColors.greenDark, Icons.check_circle_rounded),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey('$tone$message'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
