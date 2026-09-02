import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';
import '../auth/login_screen.dart';
import 'at_risk_screen.dart';
import 'students_screen.dart';
import 'school_management_screen.dart';
import 'blockchain_screen.dart';
import 'security_alerts_screen.dart';
import 'pending_approvals_screen.dart';
import '../../utils/locale_controller.dart';

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

  // Safe parsers — handle String, int, double from MySQL
  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

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
          const Text('SAPMS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(_user?['school_name'] ?? t.t('dashboard'),
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Pending approvals',
            icon: const Icon(Icons.how_to_reg_rounded),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PendingApprovalsScreen())),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.school_rounded), tooltip: 'School Management', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchoolManagementScreen()))),
            IconButton(icon: const Icon(Icons.logout),  onPressed: _logout),
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
              ElevatedButton(onPressed: _load, child: Text(t.t('retry'))),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Welcome banner ───────────────────────
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
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.t('welcome')}, ${_user?['name']?.toString().split(' ').first ?? t.t('admin')}',
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(t.t('academic_year_term'),
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Stats grid ───────────────────────────
                  SectionHeader(title: t.t('school_overview')),
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
                        title: t.t('total_students'),
                        value: '${_toInt(_dashboard?['total_students'])}',
                        icon: Icons.people_rounded,
                        color: AppConstants.primaryColor,
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StudentsScreen())),
                      ),
                      StatCard(
                        title: t.t('avg_attendance'),
                        value: '${_toDouble(_dashboard?['avg_attendance']).toStringAsFixed(1)}%',
                        icon: Icons.how_to_reg_rounded,
                        color: _attendanceColor(_dashboard?['avg_attendance']),
                        subtitle: t.t('this_term'),
                      ),
                      StatCard(
                        title: t.t('average_gpa'),
                        value: '${_toDouble(_dashboard?['avg_gpa']).toStringAsFixed(1)}%',
                        icon: Icons.bar_chart_rounded,
                        color: AppConstants.secondaryColor,
                        subtitle: t.t('all_subjects'),
                      ),
                      StatCard(
                        title: t.t('absences_7d'),
                        value: '${_toInt(_dashboard?['absences_last_7d'])}',
                        icon: Icons.event_busy_rounded,
                        color: AppConstants.warningColor,
                        subtitle: t.t('last_7_days'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Blockchain ledger entry ──────────────
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BlockchainScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.25)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.link_rounded, color: AppConstants.primaryColor),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Blockchain Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Tamper-proof attendance audit trail', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Security alerts entry (Layer 3) ──────
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SecurityAlertsScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.warningColor.withOpacity(0.35)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.warningColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.gpp_maybe_rounded, color: AppConstants.warningColor),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Security Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('ML + rule-based anomaly detection', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Risk distribution ────────────────────
                  SectionHeader(title: t.t('risk_distribution')),
                  const SizedBox(height: 12),
                  _buildRiskCard(),
                  const SizedBox(height: 20),

                  // ── At-risk summary ──────────────────────
                  SectionHeader(
                    title: t.t('at_risk_students'),
                    actionLabel: t.t('view_all'),
                    onAction: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AtRiskScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildAtRiskSummary(),
                  const SizedBox(height: 20),

                  // ── Classes ──────────────────────────────
                  SectionHeader(title: t.t('classes')),
                  const SizedBox(height: 12),
                  _buildClassList(),
                ]),
              ),
            ),
    );
  }

  Color _attendanceColor(dynamic rate) {
    final r = _toDouble(rate);
    if (r >= 85) return AppConstants.successColor;
    if (r >= 70) return AppConstants.warningColor;
    return AppConstants.dangerColor;
  }

  Widget _buildRiskCard() {
    final t = context.strings;
    final risk = _dashboard?['risk_distribution'];
    if (risk == null) return const SizedBox();

    final high     = _toInt(risk['high']);
    final moderate = _toInt(risk['moderate']);
    final low      = _toInt(risk['low']);
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
          _riskItem(t.t('high_risk'), high,     AppConstants.dangerColor),
          _riskItem(t.t('moderate'),  moderate, AppConstants.warningColor),
          _riskItem(t.t('low_risk'),  low,      AppConstants.successColor),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            if (total > 0) ...[
              if (high > 0)
                Flexible(flex: high,
                  child: Container(height: 8, color: AppConstants.dangerColor)),
              if (moderate > 0)
                Flexible(flex: moderate,
                  child: Container(height: 8, color: AppConstants.warningColor)),
              Flexible(flex: low > 0 ? low : 1,
                child: Container(height: 8, color: AppConstants.successColor)),
            ],
          ]),
        ),
        if (high > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AtRiskScreen())),
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
                Expanded(child: Text(
                  '$high ${t.t('high_risk_intervention')}',
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

  Widget _riskItem(String label, int count, Color color) {
    return Expanded(child: Column(children: [
      Text('$count',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]));
  }

  Widget _buildAtRiskSummary() {
    final t = context.strings;
    final risk = _dashboard?['risk_distribution'];
    final high = _toInt(risk?['high']);
    final mod  = _toInt(risk?['moderate']);

    if (high == 0 && mod == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.check_circle, color: AppConstants.successColor),
          const SizedBox(width: 12),
          Text(t.t('no_at_risk_detected'),
            style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AtRiskScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded,
            color: AppConstants.warningColor, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${high + mod} ${t.t('students_need_attention')}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$high ${t.t('high_risk_moderate_risk').replaceAll('{mod}', mod.toString())}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildClassList() {
    final t = context.strings;
    final classes = (_dashboard?['classes'] as List?) ?? [];
    if (classes.isEmpty) {
      return Text(t.t('no_classes_found'), style: const TextStyle(color: Colors.grey));
    }

    return Column(
      children: classes.map<Widget>((c) {
        final studentCount  = _toInt(c['student_count']);
        final avgAtt        = c['avg_attendance'] != null
            ? _toDouble(c['avg_attendance']) : null;
        final highRiskCount = _toInt(c['high_risk_count']);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(c['class_name']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$studentCount ${t.t('students_count')}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
              if (avgAtt != null)
                Text('${t.t('avg_attendance_label')}: ${avgAtt.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            if (highRiskCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$highRiskCount ${t.t('at_risk_count')}',
                  style: TextStyle(
                    color: AppConstants.dangerColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )),
              ),
          ]),
        );
      }).toList(),
    );
  }
}