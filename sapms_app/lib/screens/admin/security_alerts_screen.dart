import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Layer 3 in the app: the anomalies the hybrid rules + Isolation Forest
// detector flagged, presented as a security alert feed for the admin.
class SecurityAlertsScreen extends StatefulWidget {
  const SecurityAlertsScreen({super.key});
  @override
  State<SecurityAlertsScreen> createState() => _SecurityAlertsScreenState();
}

class _SecurityAlertsScreenState extends State<SecurityAlertsScreen> {
  List _alerts = [];
  Map<String, dynamic>? _meta;
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | high | medium

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getAnomalies();
      final data = res['data'] ?? {};
      setState(() {
        _alerts = data['alerts'] ?? [];
        _meta = {
          'source': res['source'],
          'models_loaded': data['models_loaded'],
          'sessions': data['total_sessions_checked'],
          'assessments': data['total_assessments_checked'],
          'note': data['note'],
        };
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List get _visible => _filter == 'all'
      ? _alerts
      : _alerts.where((a) => a['severity'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        title: const Text('Security Alerts'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Analyzing sessions and assessments…',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          ]))
        : _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load alerts:\n$_error',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ))
          : Column(children: [
              _buildSummary(),
              _buildFilters(),
              Expanded(child: _visible.isEmpty
                ? const Center(child: Text('No anomalies detected 🎉',
                    style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _visible.length,
                    itemBuilder: (_, i) => _buildAlertCard(_visible[i]),
                  )),
            ]),
    );
  }

  Widget _buildSummary() {
    final high = _alerts.where((a) => a['severity'] == 'high').length;
    final med  = _alerts.where((a) => a['severity'] == 'medium').length;
    final mlDown = _meta?['models_loaded'] == false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: high > 0 ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(high > 0 ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
            color: high > 0 ? Colors.red.shade700 : Colors.green.shade700, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${_alerts.length} anomalies flagged  •  $high high  •  $med medium',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
        if (_meta?['sessions'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Checked ${_meta!['sessions']} sessions and ${_meta!['assessments']} assessments '
              '(rules + Isolation Forest)',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        if (mlDown)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('⚠ ML service offline — showing policy-rule violations only',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
          ),
      ]),
    );
  }

  Widget _buildFilters() {
    Widget chip(String value, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        chip('all', 'All (${_alerts.length})'),
        chip('high', 'High'),
        chip('medium', 'Medium'),
      ]),
    );
  }

  Widget _buildAlertCard(dynamic a) {
    final isHigh = a['severity'] == 'high';
    final isSession = a['entity_type'] == 'attendance_session';
    final byRule = a['detected_by'] == 'rule';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isHigh ? Colors.red : Colors.orange).withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isHigh ? Colors.red : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(
              isSession ? Icons.event_busy_rounded : Icons.grading_rounded,
              size: 20, color: isHigh ? Colors.red.shade700 : Colors.orange.shade800),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSession ? 'Attendance Session' : 'Assessment',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
              [
                if ((a['class_name'] ?? '').toString().isNotEmpty) a['class_name'],
                if ((a['teacher_name'] ?? '').toString().isNotEmpty) a['teacher_name'],
                if ((a['date'] ?? '').toString().isNotEmpty) a['date'],
              ].join(' • '),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (byRule ? Colors.blueGrey : AppConstants.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Text(byRule ? 'RULE' : 'ML',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                color: byRule ? Colors.blueGrey : AppConstants.primaryColor)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(a['reason'] ?? '', style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}
