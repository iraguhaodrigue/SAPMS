import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../auth/login_screen.dart';
import 'take_attendance_screen.dart';
import 'marks_screen.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});
  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  Map? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getUser();
    setState(() => _user = u);
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SAPMS Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(_user?['school_name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppConstants.primaryColor, AppConstants.secondaryColor]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                radius: 28,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, ${_user?['name']?.split(' ').first ?? 'Teacher'}!',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('What would you like to do today?',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
            ]),
          ),
          const SizedBox(height: 28),

          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),

          // Take Attendance
          _actionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Take Attendance',
            subtitle: 'Open a session and scan student QR codes',
            color: AppConstants.primaryColor,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TakeAttendanceScreen())),
          ),
          const SizedBox(height: 12),

          // Enter Marks
          _actionCard(
            icon: Icons.edit_note_rounded,
            title: 'Enter Marks',
            subtitle: 'Record student assessment scores',
            color: AppConstants.secondaryColor,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MarksScreen())),
          ),
          const SizedBox(height: 28),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.accentColor.withOpacity(0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppConstants.warningColor),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Offline Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Attendance taken without internet will sync automatically when connection is restored.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}
