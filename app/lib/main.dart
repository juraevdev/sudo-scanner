import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/consent_screen.dart';
import 'screens/scanner_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final consented = await hasFaceScanConsent();
  runApp(SudoScannerApp(consented: consented));
}

class SudoScannerApp extends StatelessWidget {
  const SudoScannerApp({super.key, required this.consented});

  final bool consented;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: MaterialApp(
        title: 'UzNext Scanner',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: consented ? const ScannerScreen() : const ConsentScreen(),
      ),
    );
  }
}
