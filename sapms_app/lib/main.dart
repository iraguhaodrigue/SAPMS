import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart'; // real design-system theme (AppColors/AppRadius/GoogleFonts live behind this)

import 'utils/constants.dart';
import 'utils/locale_controller.dart';

import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/teacher/teacher_home.dart';
import 'screens/parent/parent_home.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.load(); // restore saved language before first frame
  await ApiService.loadSavedUrl();        // restore saved backend URL before any API call
  runApp(const SAPMSApp());
}

class SAPMSApp extends StatelessWidget {
  const SAPMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app whenever the language changes so every
    // screen re-reads its strings (proposal: Kinyarwanda UI option).
    return ValueListenableBuilder<String>(
      valueListenable: LocaleController.instance.languageCode,
      builder: (context, langCode, _) {
        return LocaleScope(
          languageCode: langCode,
          child: MaterialApp(
            title: 'SAPMS',
            debugShowCheckedModeBanner: false,
            // Use the shared design-system theme instead of an inline one.
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs   = await SharedPreferences.getInstance();
    final token   = prefs.getString('sapms_token');
    final userStr = prefs.getString('sapms_user');

    if (!mounted) return;

    if (token == null || userStr == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final user = jsonDecode(userStr);
    final role = user['role'];
    Widget next;
    switch (role) {
      case 'admin':
      case 'sysadmin': next = const AdminDashboard(); break;
      case 'teacher':  next = const TeacherHome();    break;
      case 'parent':   next = const ParentHome();     break;
      default:         next = const LoginScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.primaryColor,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: const Icon(Icons.school_rounded, size: 72, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text('SAPMS', style: TextStyle(
          color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 2,
        )),
        const SizedBox(height: 8),
        Text(context.tr('app_full_name'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 48),
        const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppConstants.accentColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(context.tr('university'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ])),
    );
  }
}
