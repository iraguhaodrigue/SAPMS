import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Admin adds a new student: pick a class (from own school), enter name,
// gender, optional DOB. The backend generates the student code + QR hash
// and scopes the class to the admin's school.
class CreateStudentScreen extends StatefulWidget {
  const CreateStudentScreen({super.key});
  @override
  State<CreateStudentScreen> createState() => _CreateStudentScreenState();
}

class _CreateStudentScreenState extends State<CreateStudentScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();

  List<Map<String, dynamic>> _classes = [];
  String? _classId;
  String _gender = 'M';
  DateTime? _dob;
  bool _loadingClasses = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadClasses(); }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _loadClasses() async {
    try {
      final res = await ApiService.getClasses();
      setState(() {
        _classes = List<Map<String, dynamic>>.from(res['data'] ?? []);
        _loadingClasses = false;
      });
    } catch (e) {
      setState(() => _loadingClasses = false);
      _snack('Could not load classes: ${e.toString().replaceFirst('Exception: ', '')}',
             AppConstants.dangerColor);
    }
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_classId == null) { _snack('Please select a class', AppConstants.dangerColor); return; }
    setState(() => _saving = true);
    try {
      final res = await ApiService.createStudent(
        classId: _classId!,
        name: _name.text.trim(),
        gender: _gender,
        dateOfBirth: _dob?.toIso8601String().split('T')[0],
      );
      final code = res['data']?['student_code'] ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Student created. Code: $code'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), AppConstants.dangerColor);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Add Student'),
      ),
      body: _loadingClasses
        ? const Center(child: CircularProgressIndicator())
        : _classes.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No classes found in your school. Create a class first.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(key: _form, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Student Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v==null||v.trim().length<3) ? 'Enter the full name' : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _classId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      prefixIcon: Icon(Icons.class_outlined),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select a class'),
                    items: _classes.map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text('${c['name']} (${c['level']}) - ${c['student_count']} students',
                        overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _classId = v),
                    validator: (v) => v==null ? 'Select a class' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Gender', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Row(children: [
                    Expanded(child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Male'), value: 'M', groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v!),
                    )),
                    Expanded(child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Female'), value: 'F', groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v!),
                    )),
                  ]),
                  const SizedBox(height: 6),

                  InkWell(
                    onTap: _pickDob,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of birth (optional)',
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_dob == null ? 'Not set'
                        : '${_dob!.day.toString().padLeft(2,'0')}/'
                          '${_dob!.month.toString().padLeft(2,'0')}/${_dob!.year}'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                      ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                      : const Icon(Icons.person_add_alt_1),
                    label: Text(_saving ? 'Saving...' : 'Create Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )),
                ],
              )),
            ),
    );
  }
}
