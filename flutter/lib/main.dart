import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/teacher/teacher_home.dart';
import 'screens/parent/parent_home.dart';

void main() {
  runApp(const SAPMSApp());
}

class SAPMSApp extends StatelessWidget {
  const SAPMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAPMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const SplashScreen(),
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
        const Text('Student Attendance &\nPerformance Monitoring System',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
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
          child: const Text('University of Kigali',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ])),
    );
  }
}
