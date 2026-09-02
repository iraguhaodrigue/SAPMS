import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/constants.dart';
import 'create_assessment_screen.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../utils/locale_controller.dart';

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
      final data = await ApiService.getAssessments();   // returns all assessments this teacher can see
      setState(() => _assessments = data['data'] ?? []);
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
        title: Text(t.t('assessments_marks')),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Assessment', style: TextStyle(color: Colors.white)),
        onPressed: _pickClassAndCreate,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _assessments.isEmpty
          ? _buildEmptyState()
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
                        Text('${a['subject_name']} * ${a['assessment_type']?.toUpperCase()}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('${t.t('max')}: ${a['max_score']} * ${t.t('date')}: ${a['assessment_date']?.toString().split('T')[0]}',
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No assessments yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            "Tap 'New Assessment' below to create a CAT or end-of-term exam. "
            "Once created, tap it to enter marks - you'll need your fingerprint "
            "to submit, and the marks are sealed on the blockchain.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickClassAndCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your first assessment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickClassAndCreate() async {
    // Show the teacher a picker of THEIR class/subject assignments so they
    // never have to type or guess UUIDs (the previous UX handed them an
    // empty form with 3 blank ID fields - no wonder it wasn't used).
    Map<String, dynamic>? chosen;
    try {
      final res = await ApiService.getMyClasses();
      final assignments = List<Map<String, dynamic>>.from(res['data'] ?? []);

      if (assignments.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'You have no class assignments yet. Ask your school admin to '
            'assign you to a class/subject in class_subjects.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
        return;
      }

      chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: const [
                Icon(Icons.class_rounded, color: AppConstants.primaryColor),
                SizedBox(width: 10),
                Text('Pick class & subject',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: ListView.builder(
              controller: controller,
              itemCount: assignments.length,
              itemBuilder: (_, i) {
                final a = assignments[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                    child: Text(a['level']?.toString() ?? '?',
                      style: const TextStyle(color: AppConstants.primaryColor,
                        fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text('${a['class_name']} - ${a['subject_name']}'),
                  subtitle: Text('Term ${a['term_number']}',
                    style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(context, a),
                );
              },
            )),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not load your classes: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: AppConstants.dangerColor,
      ));
      return;
    }

    if (chosen == null || !mounted) return;

    final created = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => CreateAssessmentScreen(
        classId:     chosen!['class_id'],
        subjectId:   chosen['subject_id'],
        termId:      chosen['term_id'],
        className:   chosen['class_name'],
        subjectName: chosen['subject_name'],
      ),
    ));
    if (created == true) _load();
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

  // ?? Edit mode (F3/F4) ??
  // Marks are read-only until the teacher explicitly enters edit mode, so an
  // accidental tap can never alter a sealed record.
  bool _editing = false;
  bool _saving = false;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _absent = {};

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getMarksSheet(widget.assessmentId);
      setState(() => _sheet = data);
      _seedEditors();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _seedEditors() {
    final marks = (_sheet?['data'] as List?) ?? [];
    for (final m in marks) {
      final sid = m['student_id']?.toString() ?? '';
      if (sid.isEmpty) continue;
      final score = m['score'];
      _controllers.putIfAbsent(sid, () => TextEditingController(
        text: score == null ? '' : (double.tryParse(score.toString())?.toStringAsFixed(0) ?? ''),
      ));
      _absent.putIfAbsent(sid, () => m['is_absent'] == 1);
    }
  }

  double _maxScore() {
    final marks = (_sheet?['data'] as List?) ?? [];
    if (marks.isEmpty) return 100;
    return double.tryParse(marks.first['max_score']?.toString() ?? '100') ?? 100;
  }

  // Save requires a successful fingerprint check first (F4). If it fails or is
  // cancelled, nothing is submitted - same gate as opening an attendance session.
  Future<void> _save() async {
    final max = _maxScore();

    // Validate before asking for a fingerprint, so the teacher isn't prompted
    // only to hit a validation error afterwards.
    final invalid = <String>[];
    _controllers.forEach((sid, ctrl) {
      if (_absent[sid] == true) return;
      final txt = ctrl.text.trim();
      if (txt.isEmpty) return;
      final v = double.tryParse(txt);
      if (v == null || v < 0 || v > max) invalid.add(sid);
    });
    if (invalid.isNotEmpty) {
      _snack('${invalid.length} mark(s) are not valid numbers between 0 and ${max.toStringAsFixed(0)}',
             AppConstants.dangerColor);
      return;
    }

    final bio = await BiometricService.instance.authenticate(
      reason: 'Verify your fingerprint to submit these marks',
    );
    if (!bio.success) {
      _snack(bio.message, AppConstants.dangerColor);
      return;
    }
    final verifiedAt = DateTime.now();

    setState(() => _saving = true);
    try {
      final payload = <Map<String, dynamic>>[];
      _controllers.forEach((sid, ctrl) {
        final isAbsent = _absent[sid] == true;
        final txt = ctrl.text.trim();
        payload.add({
          'student_id': sid,
          'is_absent': isAbsent,
          'score': isAbsent || txt.isEmpty ? null : double.tryParse(txt),
        });
      });

      final res = await ApiService.bulkUpdateMarks(
        assessmentId: widget.assessmentId,
        marks: payload,
        biometricVerifiedAt: verifiedAt,
      );

      final block = res['data']?['blockchain'];
      _snack(
        block != null
          ? '[OK] Marks saved and sealed on blockchain (block #${block['block_index']})'
          : '[OK] Marks saved',
        Colors.green,
      );

      setState(() => _editing = false);
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), AppConstants.dangerColor);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyIntegrity() async {
    try {
      final res = await ApiService.verifyAssessment(widget.assessmentId);
      final d = res['data'] ?? {};
      final certified = d['certified'] == true;
      final matches = d['matches'] == true;

      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        icon: Icon(
          !certified ? Icons.help_outline
                     : matches ? Icons.verified_rounded : Icons.gpp_bad_rounded,
          size: 40,
          color: !certified ? Colors.grey
                            : matches ? Colors.green : AppConstants.dangerColor,
        ),
        title: Text(!certified ? 'Not sealed yet'
                    : matches ? 'Marks Verified' : 'Marks Altered'),
        content: Text(
          !certified
            ? 'These marks have not been sealed on the blockchain yet. Submit them to create a sealed record.'
            : matches
              ? 'These marks match exactly what was sealed on the blockchain. Nothing has been changed since submission.'
              : 'These marks NO LONGER match what was sealed on the blockchain. A mark has been altered after submission.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), AppConstants.dangerColor);
    }
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings;
    final summary = _sheet?['summary'];
    final marks   = (_sheet?['data'] as List?) ?? [];
    final max     = _maxScore();

    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Text(widget.assessmentName),
        actions: [
          IconButton(
            tooltip: 'Verify against blockchain',
            icon: const Icon(Icons.shield_outlined),
            onPressed: _verifyIntegrity,
          ),
          if (!_editing)
            IconButton(
              tooltip: 'Enter marks',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _editing = true),
            )
          else
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded),
              onPressed: _saving ? null : () { setState(() => _editing = false); _seedEditors(); },
            ),
        ],
      ),
      bottomNavigationBar: !_editing ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.fingerprint_rounded),
              label: Text(_saving ? 'Saving...' : 'Verify fingerprint & submit'),
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            ),
          ),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            if (summary != null && !_editing)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  _summaryItem(t.t('students'), '${summary['total']}', Colors.blue),
                  _summaryItem(t.t('avg'), '${summary['class_average'] ?? 'N/A'}', AppConstants.primaryColor),
                  _summaryItem(t.t('highest'), '${summary['highest'] ?? 'N/A'}', AppConstants.successColor),
                  _summaryItem(t.t('lowest'), '${summary['lowest'] ?? 'N/A'}', AppConstants.dangerColor),
                ]),
              ),
            if (_editing)
              Container(
                width: double.infinity,
                color: AppConstants.warningColor.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Editing - marks out of ${max.toStringAsFixed(0)}. '
                  'Submission requires your fingerprint and is sealed on the blockchain.',
                  style: const TextStyle(fontSize: 12)),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: marks.length,
                itemBuilder: (_, i) => _editing
                  ? _buildEditRow(marks[i], i, max)
                  : _buildReadRow(marks[i], i, t),
              ),
            ),
          ]),
    );
  }

  Widget _buildReadRow(dynamic m, int i, dynamic t) {
    final score = m['score'] != null
        ? (double.tryParse(m['score'].toString()) ?? 0.0)
        : null;
    final max   = double.tryParse(m['max_score']?.toString() ?? '100') ?? 100;
    final pct   = score != null ? (score / max * 100) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(width: 28,
          child: Text('${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text(m['student_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        if (m['is_absent'] == 1)
          Text(t.t('absent').toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 13))
        else if (score != null)
          Row(children: [
            Text('${score.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('(${pct?.toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12,
                color: pct != null && pct < 50
                  ? AppConstants.dangerColor : AppConstants.successColor)),
          ])
        else
          const Text('-', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _buildEditRow(dynamic m, int i, double max) {
    final sid = m['student_id']?.toString() ?? '';
    final ctrl = _controllers[sid];
    final isAbsent = _absent[sid] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(width: 24,
          child: Text('${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text(m['student_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        SizedBox(
          width: 70,
          child: TextField(
            controller: ctrl,
            enabled: !isAbsent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true,
              hintText: '/${max.toStringAsFixed(0)}',
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(
            value: isAbsent,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => setState(() => _absent[sid] = v ?? false),
          ),
          const Text('Abs', style: TextStyle(fontSize: 9, color: Colors.grey)),
        ]),
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
