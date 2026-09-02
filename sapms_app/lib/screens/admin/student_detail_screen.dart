import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';
import '../../utils/locale_controller.dart';

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
  Map? _forecast; // F2 — predicted end-of-term performance
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
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
      // Forecast is optional — if train_forecast.py hasn't run yet the
      // endpoint returns available:false and the tab explains that.
      try {
        final f = await ApiService.getStudentForecasts(widget.studentId);
        if (mounted) setState(() => _forecast = f['data']);
      } catch (_) {/* tab shows its own empty state */}
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings;
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_student?['name'] ?? t.t('student')),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppConstants.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: t.t('overview')),
            Tab(text: t.t('attendance')),
            const Tab(text: 'Forecast'),
            Tab(text: t.t('qr_code')),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _buildOverview(),
            _buildAttendance(),
            _buildForecast(),
            _buildQR(),
          ]),
    );
  }

  Widget _buildOverview() {
    final t = context.strings;
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
              title: t.t('attendance_rate'),
              value: s['attendance_rate'] != null
                ? '${double.parse(s['attendance_rate'].toString()).toStringAsFixed(1)}%' : 'N/A',
              icon: Icons.how_to_reg_rounded,
              color: _rateColor(s['attendance_rate']),
            ),
            StatCard(
              title: t.t('gpa'),
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
          Text(t.t('parent_guardian'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    final t = context.strings;
    if (_attendance == null) return const Center(child: CircularProgressIndicator());
    final summary = _attendance!['summary'];
    final records = (_attendance!['data'] as List?) ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary
        Row(children: [
          Expanded(child: StatCard(
            title: t.t('sessions'), value: '${summary['total_sessions']}',
            icon: Icons.calendar_today, color: AppConstants.primaryColor,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: t.t('present'), value: '${summary['present']}',
            icon: Icons.check_circle, color: AppConstants.successColor,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: t.t('absent'), value: '${summary['absent']}',
            icon: Icons.cancel, color: AppConstants.dangerColor,
          )),
        ]),
        const SizedBox(height: 16),
        Text('${t.t('rate')}: ${summary['attendance_rate'] ?? 'N/A'}%',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Text(t.t('recent_records'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // F2 — Academic performance forecast: predicted end-of-term score per
  // subject, from features observed before the end-of-term assessments.
  Widget _buildForecast() {
    final f = _forecast;
    if (f == null || f['available'] != true) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No forecast available yet.\nRun the forecasting model (train_forecast.py) to generate predictions.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ));
    }

    final overall = (f['overall_predicted'] as num?)?.toDouble() ?? 0;
    final atRisk = (f['subjects_at_risk'] as num?)?.toInt() ?? 0;
    final list = (f['forecasts'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: overall < 50 ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(overall < 50 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
              size: 34, color: overall < 50 ? Colors.red.shade700 : Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Predicted end-of-term average: ${overall.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(atRisk == 0
                  ? 'No subjects predicted below the pass mark'
                  : '$atRisk subject(s) predicted below 50% — early intervention advised',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Forecast is based on attendance and CAT marks recorded BEFORE the end-of-term exams.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        ...list.map((r) {
          final pred = double.tryParse(r['predicted_score'].toString()) ?? 0;
          final cat  = r['cat_average'] != null ? double.tryParse(r['cat_average'].toString()) : null;
          final failing = pred < 50;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: failing
                ? AppConstants.dangerColor.withOpacity(0.4)
                : Colors.grey.shade200),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['subject_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (cat != null)
                  Text('CAT average so far: ${cat.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${pred.toStringAsFixed(0)}%', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  color: failing ? AppConstants.dangerColor : AppConstants.successColor)),
                const Text('predicted', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ]),
          );
        }),
      ],
    );
  }

  Widget _buildQR() {
    final t = context.strings;
    if (_qr == null) return Center(child: Text(t.t('qr_not_available')));
    final base64Img = _qr!['qr_image']?.toString().split(',').last;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t.t('student_qr_code'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          Text(t.t('print_qr_note'),
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
