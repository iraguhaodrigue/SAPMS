import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';

class AtRiskScreen extends StatefulWidget {
  const AtRiskScreen({super.key});
  @override
  State<AtRiskScreen> createState() => _AtRiskScreenState();
}

class _AtRiskScreenState extends State<AtRiskScreen> {
  List _students = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getAtRisk();
      setState(() => _students = data['data'] ?? []);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List get _filtered {
    if (_filter == 'all') return _students;
    return _students.where((s) => s['risk_level'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('At-Risk Students'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(children: [
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _chip('All', 'all'),
            const SizedBox(width: 8),
            _chip('High Risk', 'high'),
            const SizedBox(width: 8),
            _chip('Moderate', 'moderate'),
          ]),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? const Center(child: Text('No students match this filter'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildCard(_filtered[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(
        color: selected ? Colors.white : Colors.grey[700], fontSize: 13,
      )),
      selected: selected,
      selectedColor: AppConstants.primaryColor,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildCard(Map s) {
    final risk = s['risk_level'] ?? 'low';
    final att  = s['attendance_rate'];
    final gpa  = s['gpa'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.riskColor(risk).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: AppConstants.riskColor(risk).withOpacity(0.1),
            child: Text(s['name'][0], style: TextStyle(
              color: AppConstants.riskColor(risk), fontWeight: FontWeight.bold,
            )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${s['student_code']} • ${s['class_name']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          RiskBadge(risk),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          _metric('Attendance', att != null ? '${att.toStringAsFixed(1)}%' : 'N/A',
            att != null && att < 85 ? AppConstants.dangerColor : AppConstants.successColor),
          _metric('GPA', gpa != null ? '${gpa.toStringAsFixed(1)}%' : 'N/A',
            gpa != null && gpa < 50 ? AppConstants.dangerColor : AppConstants.successColor),
          _metric('Risk Score', s['risk_score'] != null
            ? '${(s['risk_score'] * 100).toStringAsFixed(0)}%' : 'N/A',
            AppConstants.riskColor(risk)),
        ]),
        if (s['parent_name'] != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Parent: ${s['parent_name']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (s['parent_phone'] != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(s['parent_phone'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]));
  }
}
