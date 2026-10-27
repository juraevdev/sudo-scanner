import 'package:flutter/material.dart';

import '../data/student.dart';
import 'card_style.dart';
import 'brand_logo.dart';

class CardFront extends StatelessWidget {
  const CardFront({super.key, required this.card});

  final StudentCard card;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      isBack: false,
      children: [
        const Positioned(left: 26, top: 26, child: BrandLogo(size: 28)),
        const Positioned(right: 26, top: 29, child: _ParkTitle(fontSize: 17)),
        const Positioned(
          left: 28,
          top: 104,
          child: AccentCaption('STUDENT ACCESS'),
        ),
        Positioned(
          left: 28,
          bottom: 30,
          width: 200,
          child: CardField(label: 'FULL NAME', value: card.fullName),
        ),
        Positioned(
          left: 256,
          bottom: 30,
          width: 112,
          child: CardField(label: 'STUDENT ID', value: card.studentId),
        ),
      ],
    );
  }
}

class _ParkTitle extends StatelessWidget {
  const _ParkTitle({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'JizPi ', style: TextStyle(color: Colors.white)),
          TextSpan(
            text: 'IT PARK',
            style: TextStyle(color: CardColors.green),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}
