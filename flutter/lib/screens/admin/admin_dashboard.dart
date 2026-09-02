import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';
import '../auth/login_screen.dart';
import 'at_risk_screen.dart';
import 'students_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getMe(),
      ]);
      setState(() {
        _dashboard = results[0]['data'];
        _user      = results[1]['data'];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          const Text('SAPMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(_user?['school_name'] ?? 'Dashboard',
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: AppConstants.dangerColor),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Welcome
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.admin_panel_settings, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Welcome, ${_user?['name']?.split(' ').first ?? 'Admin'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Term 2 • 2024-2025 Academic Year',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Stats Grid
                  const SectionHeader(title: 'School Overview'),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      StatCard(
                        title: 'Total Students',
                        value: '${_dashboard?['total_students'] ?? 0}',
                        icon: Icons.people_rounded,
                        color: AppConstants.primaryColor,
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StudentsScreen())),
                      ),
                      StatCard(
                        title: 'Avg Attendance',
                        value: '${_dashboard?['avg_attendance'] ?? 0}%',
                        icon: Icons.how_to_reg_rounded,
                        color: _attendanceColor(_dashboard?['avg_attendance']),
                        subtitle: 'This term',
                      ),
                      StatCard(
                        title: 'Average GPA',
                        value: '${_dashboard?['avg_gpa'] ?? 0}%',
                        icon: Icons.bar_chart_rounded,
                        color: AppConstants.secondaryColor,
                        subtitle: 'All subjects',
                      ),
                      StatCard(
                        title: 'Absences (7d)',
                        value: '${_dashboard?['absences_last_7d'] ?? 0}',
                        icon: Icons.event_busy_rounded,
                        color: AppConstants.warningColor,
                        subtitle: 'Last 7 days',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Risk Distribution
                  const SectionHeader(title: 'Student Risk Distribution'),
                  const SizedBox(height: 12),
                  _buildRiskCard(),
                  const SizedBox(height: 20),

                  // At-Risk Quick List
                  SectionHeader(
                    title: 'At-Risk Students',
                    actionLabel: 'View All',
                    onAction: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AtRiskScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildAtRiskSummary(),
                  const SizedBox(height: 20),

                  // Classes
                  const SectionHeader(title: 'Classes'),
                  const SizedBox(height: 12),
                  _buildClassList(),
                ]),
              ),
            ),
    );
  }

  Color _attendanceColor(dynamic rate) {
    if (rate == null) return Colors.grey;
    final r = double.tryParse(rate.toString()) ?? 0;
    if (r >= 85) return AppConstants.successColor;
    if (r >= 70) return AppConstants.warningColor;
    return AppConstants.dangerColor;
  }

  Widget _buildRiskCard() {
    final risk = _dashboard?['risk_distribution'];
    if (risk == null) return const SizedBox();
    final high     = risk['high']     ?? 0;
    final moderate = risk['moderate'] ?? 0;
    final low      = risk['low']      ?? 0;
    final total    = high + moderate + low;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(children: [
        Row(children: [
          _riskItem('High Risk', high, total, AppConstants.dangerColor),
          _riskItem('Moderate', moderate, total, AppConstants.warningColor),
          _riskItem('Low Risk', low, total, AppConstants.successColor),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            if (total > 0) ...[
              Flexible(flex: high,     child: Container(height: 8, color: AppConstants.dangerColor)),
              Flexible(flex: moderate, child: Container(height: 8, color: AppConstants.warningColor)),
              Flexible(flex: low > 0 ? low : 1, child: Container(height: 8, color: AppConstants.successColor)),
            ],
          ]),
        ),
        if (high > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AtRiskScreen())),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.dangerColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.dangerColor.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.warning_rounded, color: AppConstants.dangerColor, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('$high student(s) at HIGH risk — immediate intervention needed',
                  style: TextStyle(color: AppConstants.dangerColor, fontSize: 13),
                )),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppConstants.dangerColor),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _riskItem(String label, int count, int total, Color color) {
    return Expanded(child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]));
  }

  Widget _buildAtRiskSummary() {
    final risk = _dashboard?['risk_distribution'];
    final high = risk?['high'] ?? 0;
    final mod  = risk?['moderate'] ?? 0;
    if (high == 0 && mod == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.check_circle, color: AppConstants.successColor),
          const SizedBox(width: 12),
          const Text('No at-risk students detected', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AtRiskScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppConstants.warningColor, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${high + mod} students need attention',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$high high risk • $mod moderate risk',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildClassList() {
    final classes = (_dashboard?['classes'] as List?) ?? [];
    if (classes.isEmpty) return const Text('No classes found', style: TextStyle(color: Colors.grey));
    return Column(
      children: classes.map((c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(c['class_name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['student_count']} students',
              style: const TextStyle(fontWeight: FontWeight.w500)),
            if (c['avg_attendance'] != null)
              Text('Avg attendance: ${double.tryParse(c['avg_attendance'].toString())?.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          if ((c['high_risk_count'] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${c['high_risk_count']} at risk',
                style: TextStyle(color: AppConstants.dangerColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ]),
      )).toList(),
    );
  }
}
