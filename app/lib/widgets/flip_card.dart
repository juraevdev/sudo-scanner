import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Card that follows a horizontal swipe around the Y axis and settles on
/// the nearest face with a spring. Tapping flips it to the other side.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.width,
    this.onSideChanged,
  });

  final Widget front;
  final Widget back;
  final double width;
  final ValueChanged<bool>? onSideChanged;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  /// Value is measured in half-turns: 0 = front, 1 = back, 2 = front, ...
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this)..addListener(_reportSide);

  static const _spring = SpringDescription(mass: 1, stiffness: 140, damping: 19);

  /// Fling speed (card widths per second) above which a swipe always flips.
  static const _flingThreshold = 0.8;

  bool _showingBack = false;

  static bool _isBack(double v) {
    final t = v % 2;
    return t > 0.5 && t < 1.5;
  }

  void _reportSide() {
    final back = _isBack(_controller.value);
    if (back != _showingBack) {
      _showingBack = back;
      widget.onSideChanged?.call(back);
    }
  }

  void _settle(double target, double velocity) {
    _controller.animateWith(
      SpringSimulation(_spring, _controller.value, target, velocity),
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _controller.value += d.primaryDelta! / widget.width;
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = (d.primaryVelocity ?? 0) / widget.width;
    final v = _controller.value;
    final double target;
    if (velocity.abs() > _flingThreshold) {
      target = velocity > 0 ? v.floorToDouble() + 1 : v.ceilToDouble() - 1;
    } else {
      target = v.roundToDouble();
    }
    _settle(target, velocity);
  }

  void _onTap() => _settle(_controller.value.roundToDouble() + 1, 0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _controller.stop(),
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi;
          final back = _isBack(_controller.value);
          final lift = 1 - 0.05 * math.sin(angle).abs();
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(-angle)
              ..scaleByDouble(lift, lift, 1, 1),
            child: back
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}
