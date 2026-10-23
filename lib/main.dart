import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets/google_fonts/ so the web build works offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: LrmTrainerApp()));
}

class LrmTrainerApp extends StatelessWidget {
  const LrmTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LRM Trainer',
      debugShowCheckedModeBanner: false,
      // Let a mouse drag the mil wheel too, so the web build works in desktop browsers.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4A7C59),
          surface: Color(0xFF0D1117),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const HomeScreen(),
    );
  }
}
