import 'dart:convert';

class Student {
  const Student({
    required this.id,
    required this.studentCode,
    required this.fullName,
    required this.age,
    required this.faculty,
    required this.phone,
    required this.photoPath,
    required this.card,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    final cardRaw = json['card'];
    if (cardRaw is! Map<String, dynamic>) {
      throw const FormatException('Kartada ma\'lumot yo\'q');
    }
    final id = json['id'];
    final age = json['age'];
    if (id is! int || age is! int) {
      throw const FormatException('Talaba ma\'lumoti noto\'g\'ri');
    }
    final studentCode = json['student_code'];
    final fullName = json['full_name'];
    final faculty = json['faculty'];
    final phone = json['phone'];
    final photoPath = json['photo_url'];
    if (studentCode is! String ||
        fullName is! String ||
        faculty is! String ||
        phone is! String ||
        photoPath is! String) {
      throw const FormatException('Talaba ma\'lumoti noto\'g\'ri');
    }

    final cardNumber = cardRaw['card_number'];
    final organization = cardRaw['organization'];
    final access = cardRaw['access'];
    final issueDate = cardRaw['issue_date'];
    final validUntil = cardRaw['valid_until'];
    if (cardNumber is! String ||
        organization is! String ||
        access is! String ||
        issueDate is! String ||
        validUntil is! String) {
      throw const FormatException('Karta ma\'lumoti noto\'g\'ri');
    }

    return Student(
      id: id,
      studentCode: studentCode,
      fullName: fullName,
      age: age,
      faculty: faculty,
      phone: phone,
      photoPath: photoPath,
      card: StudentCard(
        fullName: fullName,
        studentId: studentCode,
        cardId: cardNumber,
        organization: organization,
        access: access,
        issueDate: DateTime.parse(issueDate),
        validUntil: DateTime.parse(validUntil),
        signature: cardRaw['sig'] as String? ?? '',
      ),
    );
  }

  final int id;
  final String studentCode;
  final String fullName;
  final int age;
  final String faculty;
  final String phone;

  /// Server-relative URL of the face photo.
  final String photoPath;
  final StudentCard card;
}

class StudentCard {
  const StudentCard({
    required this.fullName,
    required this.studentId,
    required this.cardId,
    required this.organization,
    required this.access,
    required this.issueDate,
    required this.validUntil,
    this.signature = '',
  });

  final String fullName;
  final String studentId;
  final String cardId;
  final String organization;
  final String access;
  final DateTime issueDate;
  final DateTime validUntil;
  final String signature;

  String get issueDateDisplay => formatDisplayDate(issueDate);
  String get validUntilDisplay => formatDisplayDate(validUntil);

  /// Compact signed payload for QR scanners.
  String toQrPayload() => jsonEncode({
        'cardId': cardId,
        'studentId': studentId,
        'fullName': fullName,
        'org': organization,
        'access': access,
        'issueDate': _formatIso(issueDate),
        'validUntil': _formatIso(validUntil),
        if (signature.isNotEmpty) 'sig': signature,
      });

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String formatDisplayDate(DateTime d) =>
      '${_two(d.day)} / ${_two(d.month)} / ${d.year}';

  static String _formatIso(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
}
