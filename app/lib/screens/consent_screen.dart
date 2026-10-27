import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'scanner_screen.dart';

const _consentKey = 'face_scan_consent_v1';

Future<bool> hasFaceScanConsent() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_consentKey) ?? false;
}

Future<void> saveFaceScanConsent() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_consentKey, true);
}

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!_accepted || _saving) return;
    setState(() => _saving = true);
    await saveFaceScanConsent();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandLogo(size: 32, color: AppColors.ink),
              const SizedBox(height: 28),
              const Text(
                'Yuz skaneri haqida',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Davom etish orqali siz quyidagilarga rozilik bildirasiz:',
                style: TextStyle(color: AppColors.muted, fontSize: 14.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: const [
                    _Bullet(
                      'Kamera yuzingizni aniqlash uchun ishlatiladi va kadrlarni '
                      'serverga yuboradi.',
                    ),
                    _Bullet(
                      'Yuz shabloni va rasmi talaba e-kartasi uchun saqlanadi.',
                    ),
                    _Bullet(
                      'Ma\'lumotlar faqat tashkilot ichidagi identifikatsiya '
                      'maqsadida ishlatiladi.',
                    ),
                    _Bullet(
                      'Ro\'yxatdan o\'tish ixtiyoriy; bekor qilsangiz skaner '
                      'to\'xtatiladi.',
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _accepted,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _accepted = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Men yuz biometriyasini qayta ishlashga roziman',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _accepted && !_saving ? _continue : null,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Roziman, davom etish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
