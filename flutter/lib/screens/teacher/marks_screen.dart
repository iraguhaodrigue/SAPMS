import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});
  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  List _assessments = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getAssessments(classId: 'cls-ns01-s4a', termId: 'term-2');
      setState(() => _assessments = data['data'] ?? []);
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
        title: const Text('Assessments & Marks'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _assessments.isEmpty
          ? const Center(child: Text('No assessments found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _assessments.length,
              itemBuilder: (_, i) {
                final a = _assessments[i];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MarksSheetScreen(assessmentId: a['id'], assessmentName: a['assessment_name']),
                  )),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment, color: AppConstants.primaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a['assessment_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${a['subject_name']} • ${a['assessment_type']?.toUpperCase()}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('Max: ${a['max_score']} • Date: ${a['assessment_date']?.toString().split('T')[0]}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ])),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class MarksSheetScreen extends StatefulWidget {
  final String assessmentId;
  final String assessmentName;
  const MarksSheetScreen({super.key, required this.assessmentId, required this.assessmentName});
  @override
  State<MarksSheetScreen> createState() => _MarksSheetScreenState();
}

class _MarksSheetScreenState extends State<MarksSheetScreen> {
  Map? _sheet;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiService.getMarksSheet(widget.assessmentId);
      setState(() => _sheet = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _sheet?['summary'];
    final marks   = (_sheet?['data'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Text(widget.assessmentName),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // Summary bar
            if (summary != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  _summaryItem('Students', '${summary['total']}', Colors.blue),
                  _summaryItem('Avg', '${summary['class_average'] ?? 'N/A'}', AppConstants.primaryColor),
                  _summaryItem('Highest', '${summary['highest'] ?? 'N/A'}', AppConstants.successColor),
                  _summaryItem('Lowest', '${summary['lowest'] ?? 'N/A'}', AppConstants.dangerColor),
                ]),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: marks.length,
                itemBuilder: (_, i) {
                  final m = marks[i];
                  final score = m['score'];
                  final max   = double.tryParse(m['max_score']?.toString() ?? '100') ?? 100;
                  final pct   = score != null ? (score / max * 100) : null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      SizedBox(width: 28,
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                      Expanded(child: Text(m['student_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                      if (m['is_absent'] == 1)
                        const Text('ABSENT', style: TextStyle(color: Colors.grey, fontSize: 13))
                      else if (score != null)
                        Row(children: [
                          Text('${score.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('(${pct?.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: pct != null && pct < 50
                                ? AppConstants.dangerColor : AppConstants.successColor,
                            )),
                        ])
                      else
                        const Text('—', style: TextStyle(color: Colors.grey)),
                    ]),
                  );
                },
              ),
            ),
          ]),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]));
  }
}
