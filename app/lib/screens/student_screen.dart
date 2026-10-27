import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/student.dart';
import '../theme.dart';
import '../widgets/card_back.dart';
import '../widgets/card_front.dart';
import '../widgets/card_style.dart';
import '../widgets/flip_card.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({
    super.key,
    required this.student,
    required this.api,
    required this.isNew,
  });

  final Student student;
  final ScannerApi api;

  /// True right after registration, false when an existing student was recognised.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final card = student.card;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Talaba ma\'lumotlari',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ResultBanner(isNew: isNew),
                        const SizedBox(height: 20),
                        _ProfileHeader(student: student, api: api),
                        const SizedBox(height: 24),
                        _StudentCardView(card: card),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swipe, size: 16, color: Color(0xFFB4B9BF)),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Aylantirish uchun suring yoki bosing',
                                style: TextStyle(color: Color(0xFFB4B9BF), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _InfoGroup(
                          rows: [
                            _InfoRow(Icons.person_outline_rounded, 'Ism-familiya', student.fullName),
                            _InfoRow(Icons.cake_outlined, 'Yosh', '${student.age} yosh'),
                            _InfoRow(Icons.school_outlined, 'Fakultet', student.faculty),
                            _InfoRow(Icons.phone_outlined, 'Telefon raqam', student.phone),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _InfoGroup(
                          rows: [
                            _InfoRow(Icons.badge_outlined, 'Talaba ID', student.studentCode),
                            _InfoRow(Icons.credit_card_rounded, 'Karta ID', card.cardId),
                            _InfoRow(Icons.event_available_outlined, 'Berilgan sana', card.issueDateDisplay),
                            _InfoRow(Icons.event_outlined, 'Amal qilish muddati', card.validUntilDisplay),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: const Text('Yangi skanerlash'),
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

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isNew ? Icons.verified_rounded : Icons.how_to_reg_rounded,
            color: AppColors.greenDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isNew
                  ? 'Ro\'yxatdan muvaffaqiyatli o\'tdingiz. Karta yaratildi!'
                  : 'Xush kelibsiz! Siz ro\'yxatdan o\'tgansiz.',
              style: const TextStyle(
                color: AppColors.greenDark,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student, required this.api});

  final Student student;
  final ScannerApi api;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
          ),
          child: ClipOval(child: _AuthPhoto(api: api, student: student)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.fullName,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                student.faculty,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthPhoto extends StatefulWidget {
  const _AuthPhoto({required this.api, required this.student});

  final ScannerApi api;
  final Student student;

  @override
  State<_AuthPhoto> createState() => _AuthPhotoState();
}

class _AuthPhotoState extends State<_AuthPhoto> {
  late final Future<Uint8List> _future = widget.api.fetchPhoto(widget.student);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          );
        }
        if (snapshot.hasError) return const _PhotoFallback();
        return const ColoredBox(
          color: AppColors.field,
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.green),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.field,
      child: Icon(Icons.person_rounded, color: AppColors.muted, size: 36),
    );
  }
}

class _StudentCardView extends StatelessWidget {
  const _StudentCardView({required this.card});

  final StudentCard card;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, kCardBaseSize.width * 1.1);
        final scale = width / kCardBaseSize.width;
        final height = kCardBaseSize.height * scale;

        Widget face(Widget child) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kCardRadius * scale),
                boxShadow: cardShadow(scale),
              ),
              child: FittedBox(child: child),
            );

        return Center(
          child: FlipCard(
            width: width,
            front: face(CardFront(card: card)),
            back: face(CardBack(card: card)),
          ),
        );
      },
    );
  }
}

class _InfoRow {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 22, color: AppColors.greenDark),
                  const SizedBox(width: 18),
                  Flexible(
                    child: Text(
                      rows[i].label,
                      style: const TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
