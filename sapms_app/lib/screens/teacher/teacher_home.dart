import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/locale_controller.dart';
import '../auth/login_screen.dart';
import 'take_attendance_screen.dart';
import '../../widgets/offline_banner.dart';
import 'marks_screen.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});
  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  Map? _user;
  int _pendingSync = 0; // unsynced scans + mark sheets

  @override
  void initState() {
    super.initState();
    _loadUser();
    _refreshPending();
    // Live-update the badge whenever a sync cycle finishes.
    SyncService.instance.statusStream.listen((_) => _refreshPending());
  }

  Future<void> _refreshPending() async {
    final scans = await LocalDbService.instance.countUnsynced();
    final sheets = await LocalDbService.instance.countUnsyncedMarks();
    if (mounted) setState(() => _pendingSync = scans + sheets);
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getUser();
    setState(() => _user = u);
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings;
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.t('sapms_teacher'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(_user?['school_name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          if (_pendingSync > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                avatar: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                backgroundColor: Colors.orange.shade700,
                label: Text('$_pendingSync pending',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () async {
                  final r = await SyncService.instance.syncNow();
                  if (mounted && !r.skipped) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(r.failed == 0
                          ? '[OK] Synced ${r.succeeded} item(s)'
                          : 'Synced ${r.succeeded}, ${r.failed} failed - will retry'),
                    ));
                  }
                  _refreshPending();
                },
              ),
            ),IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: Column(children: [
        const OfflineBanner(),
        Expanded(child: SingleChildScrollView(
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
                Text('${t.t('hello')}, ${_user?['name']?.split(' ').first ?? t.t('teacher')}!',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(t.t('what_to_do_today'),
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
            ]),
          ),
          const SizedBox(height: 28),

          Text(t.t('quick_actions'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),

          // Take Attendance
          _actionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: t.t('take_attendance'),
            subtitle: t.t('take_attendance_sub'),
            color: AppConstants.primaryColor,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TakeAttendanceScreen())),
          ),
          const SizedBox(height: 12),

          // Enter Marks
          _actionCard(
            icon: Icons.edit_note_rounded,
            title: t.t('enter_marks'),
            subtitle: t.t('enter_marks_sub'),
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
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppConstants.warningColor),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.t('offline_mode'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(t.t('offline_mode_desc'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
            ]),
          ),
        ]),
      )),
      ]),
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
