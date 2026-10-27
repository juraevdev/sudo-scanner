import 'package:flutter/material.dart';

/// All card faces are laid out on this fixed canvas and scaled with a
/// [FittedBox], so positions stay proportional on every screen size.
const Size kCardBaseSize = Size(428, 270);
const double kCardRadius = 18;

/// Drop shadow for a card scaled by [scale]. Applied outside any rotation so
/// it always falls downward on screen.
List<BoxShadow> cardShadow(double scale) => [
      BoxShadow(
        color: const Color(0x33000000),
        blurRadius: 30 * scale,
        offset: Offset(0, 16 * scale),
      ),
      BoxShadow(
        color: const Color(0x1A000000),
        blurRadius: 6 * scale,
        offset: Offset(0, 2 * scale),
      ),
    ];

class CardColors {
  static const green = Color(0xFF7DC242);
  static const greenDark = Color(0xFF5AA02C);
  static const label = Color(0xFF8A9099);
  static const value = Color(0xFFE4E6EA);
  static const divider = Color(0xFF4A4F58);
  static const bgTop = Color(0xFF333436);
  static const bgMid = Color(0xFF26282B);
  static const bgBottom = Color(0xFF1B2232);
}

class CardTextStyles {
  static const label = TextStyle(
    color: CardColors.label,
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );

  static const value = TextStyle(
    color: CardColors.value,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  static const accent = TextStyle(
    color: CardColors.green,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 3.6,
  );
}

/// Dark rounded card body with gradient, subtle rings and green stripes.
class CardSurface extends StatelessWidget {
  const CardSurface({super.key, required this.isBack, required this.children});

  final bool isBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: kCardBaseSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: CustomPaint(
          painter: _CardBackgroundPainter(isBack: isBack),
          child: Stack(children: children),
        ),
      ),
    );
  }
}

class _CardBackgroundPainter extends CustomPainter {
  _CardBackgroundPainter({required this.isBack});

  final bool isBack;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CardColors.bgTop, CardColors.bgMid, CardColors.bgBottom],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    final short = size.shortestSide;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.035);
    final ringCenter = Offset(w * 0.62, h * 0.8);
    canvas.drawCircle(ringCenter, short * 0.55, ring);
    canvas.drawCircle(ringCenter, short * 0.9, ring);

    // Decorations are 45° bands anchored to the bottom-right corner, so they
    // look the same in horizontal and vertical layouts. `near`/`far` are
    // distances from the corner along both edges.
    Path band(double far, double near) => Path()
      ..moveTo(w - far, h)
      ..lineTo(w, h - far)
      ..lineTo(w, h - near)
      ..lineTo(w - near, h)
      ..close();

    void stripe(double d, double width) => canvas.drawLine(
          Offset(w - d - 4, h + 4),
          Offset(w + 4, h - d - 4),
          Paint()
            ..color = CardColors.green
            ..strokeWidth = width,
        );

    canvas.drawPath(
      band(200, 135),
      Paint()..color = Colors.white.withValues(alpha: 0.025),
    );

    if (isBack) {
      stripe(60, 3.5);
      stripe(30, 2.5);
    } else {
      canvas.drawPath(
        band(126, 94),
        Paint()..color = CardColors.green.withValues(alpha: 0.14),
      );
      stripe(90, 4.5);
      stripe(56, 3);
    }
  }

  @override
  bool shouldRepaint(_CardBackgroundPainter old) => old.isBack != isBack;
}

class CardField extends StatelessWidget {
  const CardField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: CardTextStyles.label),
        const SizedBox(height: 6),
        Text(
          value,
          style: CardTextStyles.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: CardColors.divider),
      ],
    );
  }
}

/// Short green dash followed by letter-spaced caption, e.g. "— STUDENT ACCESS".
class AccentCaption extends StatelessWidget {
  const AccentCaption(this.text, {super.key, this.style = CardTextStyles.accent});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20, height: 2, color: CardColors.green),
        const SizedBox(width: 10),
        Text(text, style: style),
      ],
    );
  }
}
