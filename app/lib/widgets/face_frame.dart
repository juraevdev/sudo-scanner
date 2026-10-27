import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Round camera window with a rotating accent ring and a sweeping scan line.
class FaceFrame extends StatefulWidget {
  const FaceFrame({
    super.key,
    required this.diameter,
    required this.child,
    this.scanning = true,
    this.color = AppColors.green,
  });

  final double diameter;
  final Widget child;
  final bool scanning;
  final Color color;

  @override
  State<FaceFrame> createState() => _FaceFrameState();
}

class _FaceFrameState extends State<FaceFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(FaceFrame old) {
    super.didUpdateWidget(old);
    if (old.scanning != widget.scanning) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.scanning) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    final outer = d + 32;
    return SizedBox.square(
      dimension: outer,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final v = _controller.value;
          final sweep = Curves.easeInOut.transform(v < 0.5 ? v * 2 : 2 - v * 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(outer),
                painter: _RingPainter(
                  rotation: v * 2 * math.pi,
                  color: widget.color,
                  active: widget.scanning,
                ),
              ),
              Container(
                width: d,
                height: d,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.field,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child!,
                    if (widget.scanning)
                      Align(
                        alignment: Alignment(0, -0.9 + 1.8 * sweep),
                        child: _ScanLine(color: widget.color),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.rotation, required this.color, required this.active});

  final double rotation;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.line,
    );

    if (!active) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color,
      );
      return;
    }

    const arc = math.pi * 0.7;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      rect,
      0,
      arc,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: arc,
          colors: [color.withValues(alpha: 0), color],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.rotation != rotation || old.color != color || old.active != active;
}
