import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders a QR code with rounded modules and accent-colored finder eyes.
class QrCodeView extends StatefulWidget {
  const QrCodeView({
    super.key,
    required this.data,
    required this.size,
    this.moduleColor = const Color(0xFF2A2C30),
    this.eyeColor = const Color(0xFF2A2C30),
    this.eyeCenterColor = const Color(0xFF5AA02C),
  });

  final String data;
  final double size;
  final Color moduleColor;
  final Color eyeColor;

  /// Must stay dark enough against white for scanners to detect the eyes.
  final Color eyeCenterColor;

  @override
  State<QrCodeView> createState() => _QrCodeViewState();
}

class _QrCodeViewState extends State<QrCodeView> {
  late QrImage _qr;

  @override
  void initState() {
    super.initState();
    _qr = _build(widget.data);
  }

  @override
  void didUpdateWidget(QrCodeView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _qr = _build(widget.data);
  }

  static QrImage _build(String data) => QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _QrPainter(
        qr: _qr,
        moduleColor: widget.moduleColor,
        eyeColor: widget.eyeColor,
        eyeCenterColor: widget.eyeCenterColor,
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({
    required this.qr,
    required this.moduleColor,
    required this.eyeColor,
    required this.eyeCenterColor,
  });

  final QrImage qr;
  final Color moduleColor;
  final Color eyeColor;
  final Color eyeCenterColor;

  static const _eye = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final n = qr.moduleCount;
    final m = size.width / n;

    bool inEye(int r, int c) =>
        (r < _eye && c < _eye) ||
        (r < _eye && c >= n - _eye) ||
        (r >= n - _eye && c < _eye);

    final dot = Paint()..color = moduleColor;
    final inset = m * 0.08;
    final radius = Radius.circular(m * 0.22);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (inEye(r, c) || !qr.isDark(r, c)) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * m + inset, r * m + inset, m - inset * 2, m - inset * 2),
            radius,
          ),
          dot,
        );
      }
    }

    for (final origin in [
      Offset.zero,
      Offset((n - _eye) * m, 0),
      Offset(0, (n - _eye) * m),
    ]) {
      final outer = origin & Size.square(_eye * m);
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer, Radius.circular(m * 1.8)),
        Paint()..color = eyeColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.deflate(m), Radius.circular(m * 1.1)),
        Paint()..color = Colors.white,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.deflate(m * 2), Radius.circular(m * 0.8)),
        Paint()..color = eyeCenterColor,
      );
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.qr != qr ||
      old.moduleColor != moduleColor ||
      old.eyeColor != eyeColor ||
      old.eyeCenterColor != eyeCenterColor;
}
