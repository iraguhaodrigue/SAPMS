import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});
  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  Map? _student;
  Map? _attendance;
  Map? _qr;
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getStudent(widget.studentId),
        ApiService.getStudentAttendance(widget.studentId, termId: 'term-2'),
        ApiService.getStudentQR(widget.studentId),
      ]);
      setState(() {
        _student    = results[0]['data'];
        _attendance = results[1];
        _qr         = results[2]['data'];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_student?['name'] ?? 'Student'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppConstants.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
            Tab(text: 'QR Code'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _buildOverview(),
            _buildAttendance(),
            _buildQR(),
          ]),
    );
  }

  Widget _buildOverview() {
    final s = _student!;
    final risk = s['risk_level'] ?? 'low';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
          ),
          child: Column(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
              child: Text(s['name'][0],
                style: const TextStyle(fontSize: 28, color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(s['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${s['student_code']} • ${s['class_name']} • ${s['gender']}',
              style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            RiskBadge(risk),
          ]),
        ),
        const SizedBox(height: 16),

        // Analytics
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            StatCard(
              title: 'Attendance Rate',
              value: s['attendance_rate'] != null
                ? '${double.parse(s['attendance_rate'].toString()).toStringAsFixed(1)}%' : 'N/A',
              icon: Icons.how_to_reg_rounded,
              color: _rateColor(s['attendance_rate']),
            ),
            StatCard(
              title: 'GPA',
              value: s['gpa'] != null
                ? '${double.parse(s['gpa'].toString()).toStringAsFixed(1)}%' : 'N/A',
              icon: Icons.grade_rounded,
              color: _rateColor(s['gpa']),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Parent info
        if (s['parent_name'] != null) ...[
          const Text('Parent / Guardian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.person, color: AppConstants.primaryColor),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['parent_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                if (s['parent_phone'] != null)
                  Text(s['parent_phone'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildAttendance() {
    if (_attendance == null) return const Center(child: CircularProgressIndicator());
    final summary = _attendance!['summary'];
    final records = (_attendance!['data'] as List?) ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary
        Row(children: [
          Expanded(child: StatCard(
            title: 'Sessions', value: '${summary['total_sessions']}',
            icon: Icons.calendar_today, color: AppConstants.primaryColor,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: 'Present', value: '${summary['present']}',
            icon: Icons.check_circle, color: AppConstants.successColor,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: 'Absent', value: '${summary['absent']}',
            icon: Icons.cancel, color: AppConstants.dangerColor,
          )),
        ]),
        const SizedBox(height: 16),
        Text('Rate: ${summary['attendance_rate'] ?? 'N/A'}%',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        const Text('Recent Records', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...records.take(20).map((r) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(_statusIcon(r['status']), color: _statusColor(r['status']), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(r['subject_name'] ?? '', style: const TextStyle(fontSize: 13))),
            Text(r['session_date']?.toString().split('T')[0] ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQR() {
    if (_qr == null) return const Center(child: Text('QR code not available'));
    final base64Img = _qr!['qr_image']?.toString().split(',').last;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Student QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_qr!['student_code'] ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
            ),
            child: base64Img != null
              ? Image.memory(base64Decode(base64Img), width: 220, height: 220)
              : const Icon(Icons.qr_code, size: 200, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text('Print this QR code on the student ID card.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(_qr!['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ),
    );
  }

  Color _rateColor(dynamic v) {
    if (v == null) return Colors.grey;
    final d = double.tryParse(v.toString()) ?? 0;
    if (d >= 75) return AppConstants.successColor;
    if (d >= 50) return AppConstants.warningColor;
    return AppConstants.dangerColor;
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'present': return Icons.check_circle;
      case 'late':    return Icons.access_time;
      case 'excused': return Icons.info;
      default:        return Icons.cancel;
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'present': return AppConstants.successColor;
      case 'late':    return AppConstants.warningColor;
      case 'excused': return Colors.blue;
      default:        return AppConstants.dangerColor;
    }
  }
}
