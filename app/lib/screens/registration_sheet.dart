import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/student.dart';
import '../theme.dart';

/// Bottom sheet shown when a face is scanned for the first time.
/// Pops with the created [Student] on success.
class RegistrationSheet extends StatefulWidget {
  const RegistrationSheet({
    super.key,
    required this.api,
    required this.scanToken,
    required this.faceImage,
  });

  final ScannerApi api;
  final String scanToken;
  final Uint8List faceImage;

  @override
  State<RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<RegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _faculty = TextEditingController();
  final _phone = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _faculty.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final student = await widget.api.register(
        scanToken: widget.scanToken,
        fullName: _name.text.trim(),
        age: int.parse(_age.text),
        faculty: _faculty.text.trim(),
        phone: '+998${_phone.text.replaceAll(' ', '')}',
      );
      if (mounted) Navigator.of(context).pop(student);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Header(faceImage: widget.faceImage),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ism-familiya',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) {
                        final parts = (v ?? '').trim().split(RegExp(r'\s+'));
                        if (parts.length < 2 || (v ?? '').trim().length < 5) {
                          return 'Ism va familiyani to\'liq kiriting';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _age,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Yosh',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      validator: (v) {
                        final age = int.tryParse(v ?? '');
                        if (age == null || age < 14 || age > 100) {
                          return 'Yoshni to\'g\'ri kiriting (14–100)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _faculty,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Fakultet',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().length < 2 ? 'Fakultet nomini kiriting' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      enabled: !_submitting,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [_UzPhoneFormatter()],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '90 123 45 67',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+998 ',
                      ),
                      validator: (v) => (v ?? '').replaceAll(' ', '').length != 9
                          ? 'Telefon raqamni to\'liq kiriting'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.error, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Ro\'yxatdan o\'tish va karta olish'),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                      child: const Text('Bekor qilish'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.faceImage});

  final Uint8List faceImage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green),
          child: ClipOval(
            child: faceImage.isEmpty
                ? const ColoredBox(
                    color: AppColors.field,
                    child: Icon(Icons.face_rounded, color: AppColors.muted),
                  )
                : Image.memory(
                    faceImage,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.field,
                      child: Icon(Icons.face_rounded, color: AppColors.muted),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yangi talaba',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Yuzingiz birinchi marta skanerlandi. Karta olish uchun ma\'lumotlaringizni kiriting.',
                style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Formats up to 9 digits as "90 123 45 67", preserving caret position.
class _UzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9 && digits.startsWith('998')) digits = digits.substring(3);
    if (digits.length > 9) digits = digits.substring(0, 9);

    final selectionDigits = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final digitsBeforeCursor =
        newValue.text.substring(0, selectionDigits).replaceAll(RegExp(r'\D'), '').length;

    final buffer = StringBuffer();
    var cursor = 0;
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
      if (i + 1 == digitsBeforeCursor) cursor = buffer.length;
    }
    final text = buffer.toString();
    if (digitsBeforeCursor == 0) cursor = 0;
    if (digitsBeforeCursor >= digits.length) cursor = text.length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
    );
  }
}
