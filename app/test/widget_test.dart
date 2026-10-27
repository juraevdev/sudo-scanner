import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudo_scanner/data/api.dart';
import 'package:sudo_scanner/data/student.dart';
import 'package:sudo_scanner/screens/student_screen.dart';
import 'package:sudo_scanner/theme.dart';

void main() {
  final json = {
    'id': 1,
    'student_code': 'SA-104237',
    'full_name': 'Azizbek Karimov',
    'age': 20,
    'faculty': 'Kompyuter injiniringi',
    'phone': '+998 90 123 45 67',
    'photo_url': '/api/students/1/photo',
    'created_at': '2026-10-09T15:03:56',
    'card': {
      'card_number': 'UZN-2026-0001',
      'organization': 'JizPi IT PARK',
      'access': 'STUDENT',
      'issue_date': '2026-10-09',
      'valid_until': '2027-10-09',
      'sig': 'abc123signaturevalue000',
    },
  };

  test('parses scan response', () {
    final result = ScanResult.fromJson({
      'status': 'matched',
      'message': 'Talaba topildi',
      'student': json,
    });
    expect(result.status, ScanStatus.matched);
    expect(result.student!.card.cardId, 'UZN-2026-0001');
    expect(result.student!.card.issueDateDisplay, '09 / 10 / 2026');
    expect(ScanResult.fromJson({'status': 'new', 'scan_token': 'x'}).status, ScanStatus.newFace);
  });

  testWidgets('student screen shows student details', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: StudentScreen(
        student: Student.fromJson(json),
        api: ScannerApi(baseUrl: 'http://localhost'),
        isNew: true,
      ),
    ));

    expect(find.text('Kompyuter injiniringi'), findsWidgets);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    expect(find.text('UZN-2026-0001'), findsWidgets);
    expect(find.textContaining('Karta yaratildi'), findsOneWidget);
  });
}
