import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';
import '../auth/login_screen.dart';
import '../../utils/locale_controller.dart';

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});
  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  List _children  = [];
  Map? _selected; // selected child
  Map? _attendance;
  Map? _report;
  List _notifications = [];
  bool _loading = true;
  String? _termId; // real current term, loaded from backend

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final studData = await ApiService.getStudents();
      try {
        final termData = await ApiService.getTerms();
        final terms = (termData['data'] as List?) ?? [];
        final cur = terms.firstWhere((t) => t['is_current'] == 1, orElse: () => terms.isNotEmpty ? terms.first : null);
        if (cur != null) _termId = cur['id'];
      } catch (_) {}
      final students = (studData['data'] as List?) ?? [];
      final notifData = await ApiService.getNotifications();
      setState(() {
        _children = students;
        _notifications = (notifData['data'] as List?) ?? [];
        if (_children.isNotEmpty && _selected == null) _selected = _children.first;
      });
      if (_selected != null) await _loadChildData(_selected!['id']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadChildData(String studentId) async {
    try {
      final results = await Future.wait([
        ApiService.getStudentAttendance(studentId, termId: _termId),
        ApiService.getStudentReport(studentId, termId: _termId),
      ]);
      setState(() {
        _attendance = results[0];
        _report     = results[1];
      });
    } catch (_) {}
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
          Text(t.t('sapms_parent'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(t.t('child_progress_portal'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          if (_notifications.isNotEmpty)
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications), onPressed: _showNotifications),
              Positioned(right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppConstants.dangerColor, shape: BoxShape.circle),
                  child: Text('${_notifications.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            ]),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _children.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.child_care, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(t.t('no_children_linked'), style: const TextStyle(color: Colors.grey)),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Child selector
                  if (_children.length > 1) ...[
                    Text(t.t('select_child'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _children.map((c) {
                        final selected = _selected?['id'] == c['id'];
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _selected = c);
                            await _loadChildData(c['id']);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppConstants.primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppConstants.primaryColor),
                            ),
                            child: Text(c['name'].split(' ').first,
                              style: TextStyle(
                                color: selected ? Colors.white : AppConstants.primaryColor,
                                fontWeight: FontWeight.w500,
                              )),
                          ),
                        );
                      }).toList()),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Child profile card
                  if (_selected != null) _buildChildCard(),
                  const SizedBox(height: 16),

                  // Attendance summary
                  if (_attendance != null) _buildAttendanceSummary(),
                  const SizedBox(height: 16),

                  // Academic report
                  if (_report != null) _buildAcademicReport(),
                ]),
              ),
            ),
    );
  }

  Widget _buildChildCard() {
    final t = context.strings;
    final s    = _selected!;
    final risk = s['risk_level'] ?? 'low';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.riskColor(risk), AppConstants.riskColor(risk).withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white24,
          child: Text(s['name'][0],
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${s['class_name']} • ${s['student_code']}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(AppConstants.riskIcon(risk), size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text('${risk.toUpperCase()} ${t.t('risk')}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        ])),
      ]),
    );
  }

  Widget _buildAttendanceSummary() {
    final t = context.strings;
    final summary = _attendance!['summary'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.t('attendance_this_term'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: StatCard(
          title: t.t('rate'),
          value: '${summary['attendance_rate'] ?? 'N/A'}%',
          icon: Icons.percent,
          color: _rateColor(summary['attendance_rate']),
        )),
        const SizedBox(width: 10),
        Expanded(child: StatCard(
          title: t.t('present'),
          value: '${summary['present']}',
          icon: Icons.check_circle,
          color: AppConstants.successColor,
        )),
        const SizedBox(width: 10),
        Expanded(child: StatCard(
          title: t.t('absent'),
          value: '${summary['absent']}',
          icon: Icons.cancel,
          color: AppConstants.dangerColor,
        )),
      ]),
      if (summary['attendance_rate'] != null &&
          double.tryParse(summary['attendance_rate'].toString())! < 85) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppConstants.dangerColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppConstants.dangerColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.warning, color: AppConstants.dangerColor, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              t.t('attendance_below_warning'),
              style: const TextStyle(fontSize: 13, color: AppConstants.dangerColor),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _buildAcademicReport() {
    final t = context.strings;
    final subjects = _report!['data'] as Map? ?? {};
    if (subjects.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.t('academic_performance'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 10),
      ...subjects.entries.map((e) {
        final sub = e.value as Map;
        final avg = double.tryParse(sub['average']?.toString() ?? '');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Row(children: [
            Expanded(child: Text(sub['subject'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500))),
            if (avg != null) ...[
              Text('${avg.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: avg >= 75 ? AppConstants.successColor
                    : avg >= 50 ? AppConstants.warningColor : AppConstants.dangerColor,
                )),
              const SizedBox(width: 8),
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (avg / 100).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: avg >= 75 ? AppConstants.successColor
                        : avg >= 50 ? AppConstants.warningColor : AppConstants.dangerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ] else
              Text(t.t('no_marks_yet'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        );
      }),
    ]);
  }

  void _showNotifications() {
    final t = context.strings;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(children: [
        const SizedBox(height: 16),
        Text(t.t('notifications'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        Expanded(child: ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (_, i) {
            final n = _notifications[i];
            return ListTile(
              leading: Icon(
                n['type'] == 'absence' ? Icons.event_busy : Icons.warning,
                color: n['type'] == 'absence' ? AppConstants.dangerColor : AppConstants.warningColor,
              ),
              title: Text(n['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(n['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
              trailing: Text(n['created_at']?.toString().split('T')[0] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            );
          },
        )),
      ]),
    );
  }

  Color _rateColor(dynamic v) {
    if (v == null) return Colors.grey;
    final d = double.tryParse(v.toString()) ?? 0;
    if (d >= 85) return AppConstants.successColor;
    if (d >= 70) return AppConstants.warningColor;
    return AppConstants.dangerColor;
  }
}
