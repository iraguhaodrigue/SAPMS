import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Admin school management: create subjects, create classes, and assign
// teachers to a class+subject+term. One screen, three tabs. Everything is
// scoped server-side to the admin's own school.
class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});
  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('School Management'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Subjects'),
            Tab(text: 'Classes'),
            Tab(text: 'Assign'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _SubjectsTab(),
        _ClassesTab(),
        _AssignTab(),
      ]),
    );
  }
}

const _levels = ['S1','S2','S3','S4','S5','S6'];

// -- TAB 1: Subjects --
class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab();
  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  final _name = TextEditingController();
  String _level = 'S4';
  bool _saving = false, _loading = true;
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiService.getSubjects();
      setState(() { _subjects = List<Map<String, dynamic>>.from(res['data'] ?? []); _loading = false; });
    } catch (e) { setState(() => _loading = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Load error: $e"), backgroundColor: Colors.red)); }
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      await ApiService.createSubject(name: _name.text.trim(), level: _level);
      _name.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject created'), backgroundColor: Colors.green));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppConstants.dangerColor));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Subject name',
              hintText: 'e.g. Mathematics', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.menu_book_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _level,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder()),
            items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _level = v!)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving
              ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              : const Icon(Icons.add),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16)))),
        ]),
      ),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _subjects.isEmpty
          ? const Center(child: Text('No subjects yet. Add one above.',
              style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _subjects.length,
              itemBuilder: (_, i) {
                final s = _subjects[i];
                return Card(child: ListTile(
                  leading: const Icon(Icons.menu_book_rounded, color: AppConstants.primaryColor),
                  title: Text(s['name']?.toString() ?? ''),
                  subtitle: Text('${s['code']} - ${s['level']}'),
                ));
              })),
    ]);
  }
}

// -- TAB 2: Classes --
class _ClassesTab extends StatefulWidget {
  const _ClassesTab();
  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  final _name = TextEditingController();
  String _level = 'S4';
  bool _saving = false, _loading = true;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiService.getClasses();
      setState(() { _classes = List<Map<String, dynamic>>.from(res['data'] ?? []); _loading = false; });
    } catch (e) { setState(() => _loading = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Load error: $e"), backgroundColor: Colors.red)); }
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      await ApiService.createClass(name: _name.text.trim(), level: _level);
      _name.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created'), backgroundColor: Colors.green));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppConstants.dangerColor));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _name,
            decoration: const InputDecoration(labelText: 'Class name',
              hintText: 'e.g. S4-A', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.class_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _level,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder()),
            items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _level = v!)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving
              ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              : const Icon(Icons.add),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16)))),
        ]),
      ),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _classes.isEmpty
          ? const Center(child: Text('No classes yet. Add one above.',
              style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _classes.length,
              itemBuilder: (_, i) {
                final c = _classes[i];
                return Card(child: ListTile(
                  leading: const Icon(Icons.class_rounded, color: AppConstants.primaryColor),
                  title: Text(c['name']?.toString() ?? ''),
                  subtitle: Text('${c['level']} - ${c['student_count']} students'),
                ));
              })),
    ]);
  }
}

// -- TAB 3: Assign teacher to class + subject + term --
class _AssignTab extends StatefulWidget {
  const _AssignTab();
  @override
  State<_AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<_AssignTab> {
  List<Map<String, dynamic>> _classes = [], _subjects = [], _teachers = [], _terms = [];
  String? _classId, _subjectId, _teacherId, _termId;
  bool _loading = true, _saving = false;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    try {
      final r = await Future.wait([
        ApiService.getClasses(),
        ApiService.getSubjects(),
        ApiService.getSchoolTeachers(),
        ApiService.getTerms(),
      ]);
      setState(() {
        _classes  = List<Map<String, dynamic>>.from(r[0]['data'] ?? []);
        _subjects = List<Map<String, dynamic>>.from(r[1]['data'] ?? []);
        _teachers = List<Map<String, dynamic>>.from(r[2]['data'] ?? []);
        _terms    = List<Map<String, dynamic>>.from(r[3]['data'] ?? []);
        final cur = _terms.where((t) => t['is_current'] == 1).toList();
        if (cur.isNotEmpty) _termId = cur.first['id'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Load failed: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: AppConstants.dangerColor));
    }
  }

  Future<void> _assign() async {
    if (_classId == null || _subjectId == null || _teacherId == null || _termId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please choose class, subject, teacher and term'),
        backgroundColor: Colors.orange));
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiService.assignTeacher(
        classId: _classId!, subjectId: _subjectId!,
        teacherId: _teacherId!, termId: _termId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message']?.toString() ?? 'Teacher assigned'),
        backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppConstants.dangerColor));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _dropdown(String label, String? value, List<Map<String,dynamic>> items,
      String Function(Map) labelOf, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value, isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((m) => DropdownMenuItem<String>(
          value: m['id'] as String,
          child: Text(labelOf(m), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_classes.isEmpty || _subjects.isEmpty || _teachers.isEmpty || _terms.isEmpty) {
      final missing = [
        if (_classes.isEmpty) 'classes',
        if (_subjects.isEmpty) 'subjects',
        if (_teachers.isEmpty) 'teachers',
        if (_terms.isEmpty) 'terms',
      ].join(', ');
      return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(
        'You need at least one class, one subject, one approved teacher, and one term before assigning.\n\nMissing: $missing.',
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Assign a teacher to teach a subject in a class',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        _dropdown('Class', _classId, _classes,
          (c) => '${c['name']} (${c['level']})', (v) => setState(() => _classId = v)),
        _dropdown('Subject', _subjectId, _subjects,
          (s) => '${s['name']} (${s['level']})', (v) => setState(() => _subjectId = v)),
        _dropdown('Teacher', _teacherId, _teachers,
          (t) => t['name']?.toString() ?? '', (v) => setState(() => _teacherId = v)),
        _dropdown('Term', _termId, _terms,
          (t) => 'Term ${t['term_number']} (${t['year_label']})', (v) => setState(() => _termId = v)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _saving ? null : _assign,
          icon: _saving
            ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
            : const Icon(Icons.link_rounded),
          label: Text(_saving ? 'Assigning...' : 'Assign Teacher'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14)))),
      ]),
    );
  }
}
