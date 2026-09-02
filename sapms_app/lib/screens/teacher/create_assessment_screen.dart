import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Teacher creates a new assessment (CAT or End-of-Term) for a class/subject.
// Previously assessments only existed because the dataset generator inserted
// them — this screen closes that gap.
class CreateAssessmentScreen extends StatefulWidget {
  final String classId;
  final String subjectId;
  final String termId;
  final String className;
  final String subjectName;

  const CreateAssessmentScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.termId,
    required this.className,
    required this.subjectName,
  });

  @override
  State<CreateAssessmentScreen> createState() => _CreateAssessmentScreenState();
}

class _CreateAssessmentScreenState extends State<CreateAssessmentScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _maxScore = TextEditingController(text: '100');
  final _description = TextEditingController();

  String _type = 'continuous';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _maxScore.dispose(); _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.createAssessment(
        classId: widget.classId,
        subjectId: widget.subjectId,
        termId: widget.termId,
        name: _name.text.trim(),
        type: _type,
        maxScore: double.parse(_maxScore.text.trim()),
        date: _date.toIso8601String().split('T')[0],
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Assessment created — you can now enter marks'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true); // true = caller should reload
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppConstants.dangerColor,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('New Assessment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Context header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.class_rounded, color: AppConstants.primaryColor),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  '${widget.className} — ${widget.subjectName}',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 20),

            // Assessment name
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Assessment title',
                hintText: 'e.g. CAT 1, Mid-Term, End of Term',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter a title' : null,
            ),
            const SizedBox(height: 14),

            // Type
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Assessment type',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'continuous', child: Text('Continuous Assessment (CAT)')),
                DropdownMenuItem(value: 'endterm',    child: Text('End of Term Exam')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 14),

            // Max score
            TextFormField(
              controller: _maxScore,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Maximum marks',
                prefixIcon: Icon(Icons.score_rounded),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0 || n > 1000) ? 'Enter a valid maximum (1–1000)' : null;
              },
            ),
            const SizedBox(height: 14),

            // Date
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Assessment date',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text('${_date.day.toString().padLeft(2,'0')}/'
                    '${_date.month.toString().padLeft(2,'0')}/${_date.year}'),
              ),
            ),
            const SizedBox(height: 14),

            // Optional description
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Instructions / description (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_task_rounded),
                label: Text(_saving ? 'Creating…' : 'Create Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
