import 'package:flutter/material.dart';

import '../data/student.dart';
import 'card_style.dart';
import 'qr_code_view.dart';
import 'brand_logo.dart';

class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.card});

  final StudentCard card;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      isBack: true,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 6,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [CardColors.greenDark, CardColors.green],
              ),
            ),
          ),
        ),
        const Positioned(right: 26, top: 24, child: BrandLogo(size: 24)),
        Positioned(
          left: 24,
          top: 58,
          child: Container(
            width: 146,
            height: 146,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrCodeView(data: card.toQrPayload(), size: 126),
          ),
        ),
        Positioned(
          left: 26,
          top: 220,
          child: AccentCaption(
            'SCAN TO ACCESS',
            style: CardTextStyles.accent.copyWith(fontSize: 10.5, letterSpacing: 2.6),
          ),
        ),
        Positioned(
          left: 200,
          right: 30,
          top: 82,
          child: CardField(label: 'CARD ID', value: card.cardId),
        ),
        Positioned(
          left: 200,
          right: 30,
          top: 132,
          child: CardField(label: 'ISSUE DATE', value: card.issueDateDisplay),
        ),
        Positioned(
          left: 200,
          right: 30,
          top: 188,
          child: CardField(label: 'VALID UNTIL', value: card.validUntilDisplay),
        ),
      ],
    );
  }
}
