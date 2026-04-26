// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/detector/detector_screen.dart';
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // Lock to portrait for consistent landmark orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
 
  runApp(const LSCApp());
}
 
class LSCApp extends StatelessWidget {
  const LSCApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const DetectorScreen(),
    );
  }
}
