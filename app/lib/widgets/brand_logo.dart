import 'package:flutter/material.dart';

/// UzNext lockup: "UN" mark followed by the "UzNext" wordmark.
/// [size] is the height of the mark. The artwork is white; pass [color] to
/// tint it for light backgrounds.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/uznext_mark.png',
          height: size,
          color: color,
          filterQuality: FilterQuality.medium,
        ),
        SizedBox(width: size * 0.3),
        Image.asset(
          'assets/brand/uznext_wordmark.png',
          height: size * 0.5,
          color: color,
          filterQuality: FilterQuality.medium,
        ),
      ],
    );
  }
}
