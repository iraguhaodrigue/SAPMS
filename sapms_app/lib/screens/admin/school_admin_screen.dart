// School Administration — management & data-control screen.
// Six tabs: Teachers, Students, Parents, Classes, Subjects, Audit Log.
// Every destructive action shows a confirmation dialog with impact info.
// Matches SAPMS style (AppConstants colours, ApiService pattern).

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class SchoolAdminScreen extends StatefulWidget {
  const SchoolAdminScreen({super.key});
  @override
  State<SchoolAdminScreen> createState() => _SchoolAdminScreenState();
}

class _SchoolAdminScreenState extends State<SchoolAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 6, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('School Administration'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppConstants.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Teachers'),
            Tab(text: 'Students'),
            Tab(text: 'Parents'),
            Tab(text: 'Classes'),
            Tab(text: 'Subjects'),
            Tab(text: 'Audit Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TeachersTab(),
          _StudentsTab(),
          _ParentsTab(),
          _ClassesTab(),
          _SubjectsTab(),
          _AuditTab(),
        ],
      ),
    );
  }
}

// Shared helpers ---------------------------------------------------------
void _toast(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppConstants.dangerColor : AppConstants.successColor,
  ));
}

Future<bool> _confirm(BuildContext ctx, {required String title, required String message, String confirmText = 'Confirm', Color? color}) async {
  final r = await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color ?? AppConstants.dangerColor, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}

Widget _loadingView() => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
Widget _empty(String msg) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(msg, style: const TextStyle(color: Colors.grey))));

// ════════════════════════════════════════════════════════════════════════
// TEACHERS TAB
// ════════════════════════════════════════════════════════════════════════
class _TeachersTab extends StatefulWidget {
  const _TeachersTab();
  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}
class _TeachersTabState extends State<_TeachersTab> {
  bool _loading = true;
  List _teachers = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.adminGetTeachers();
      setState(() { _teachers = r['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast(context, e.toString(), error: true);
    }
  }

  Future<void> _viewAndManage(Map t) async {
    try {
      final r = await ApiService.adminTeacherImpact(t['id']);
      final assignments = (r['data']?['assignments'] ?? []) as List;
      if (!mounted) return;
      showModalBottomSheet(
        context: context, isScrollControlled: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['name'] ?? 'Teacher', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(t['email'] ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Text('Assignments (${assignments.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (assignments.isEmpty) const Text('No class/subject assignments.'),
            ...assignments.map((a) => Card(child: ListTile(
              dense: true,
              title: Text('${a['class_name']} / ${a['subject_name']}'),
              trailing: IconButton(
                icon: const Icon(Icons.link_off, color: AppConstants.warningColor),
                tooltip: 'Unassign',
                onPressed: () async {
                  final ok = await _confirm(context,
                    title: 'Unassign teacher',
                    message: 'Remove ${t['name']} from ${a['class_name']} / ${a['subject_name']}?',
                    confirmText: 'Unassign', color: AppConstants.warningColor);
                  if (!ok) return;
                  try {
                    await ApiService.adminUnassignTeacher(a['assignment_id']);
                    if (mounted) { Navigator.pop(context); _toast(context, 'Unassigned'); _load(); }
                  } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
                },
              ),
            ))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.dangerColor, foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Teacher'),
              onPressed: () async {
                Navigator.pop(context);
                final ok = await _confirm(context,
                  title: 'Delete teacher',
                  message: 'Delete ${t['name']}? Their ${assignments.length} assignment(s) will be removed. Classes, subjects, students and past records are kept.',
                  confirmText: 'Delete');
                if (!ok) return;
                try {
                  final res = await ApiService.adminDeleteTeacher(t['id']);
                  if (mounted) { _toast(context, res['message'] ?? 'Deleted'); _load(); }
                } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
              },
            )),
            const SizedBox(height: 8),
          ]),
        ),
      );
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_teachers.isEmpty) return _empty('No teachers found.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _teachers.length,
        itemBuilder: (_, i) {
          final t = _teachers[i];
          return Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: AppConstants.primaryColor, child: Text('${t['name']?[0] ?? '?'}', style: const TextStyle(color: Colors.white))),
            title: Text(t['name'] ?? ''),
            subtitle: Text('${t['email']}\n${t['assignment_count']} assignment(s)'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _viewAndManage(t),
          ));
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// STUDENTS TAB — move class + archive
// ════════════════════════════════════════════════════════════════════════
class _StudentsTab extends StatefulWidget {
  const _StudentsTab();
  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}
class _StudentsTabState extends State<_StudentsTab> {
  bool _loading = true;
  List _students = [];
  List _classes = [];
  String _search = '';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getStudents(search: _search.isEmpty ? null : _search);
      final c = await ApiService.getClasses();
      setState(() { _students = s['data'] ?? []; _classes = c['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast(context, e.toString(), error: true);
    }
  }

  Future<void> _moveStudent(Map st) async {
    String? destId;
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Move Student'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Student: ${st['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Current class: ${st['class_name'] ?? st['class'] ?? '—'}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Move to class', border: OutlineInputBorder()),
            items: _classes.map<DropdownMenuItem<String>>((c) =>
              DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']} (${c['level']})'))).toList(),
            onChanged: (v) => setD(() => destId = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
            onPressed: destId == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('Confirm Move')),
        ],
      ),
    ));
    if (ok != true || destId == null) return;
    try {
      final res = await ApiService.adminMoveStudent(st['id'], destId!);
      if (mounted) { _toast(context, res['message'] ?? 'Moved'); _load(); }
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  Future<void> _archive(Map st) async {
    final ok = await _confirm(context,
      title: 'Archive student',
      message: 'Mark ${st['name']} as inactive (left school)? All grades, attendance and records are kept. They can be reactivated later.',
      confirmText: 'Archive', color: AppConstants.warningColor);
    if (!ok) return;
    try {
      final res = await ApiService.adminArchiveStudent(st['id']);
      if (mounted) { _toast(context, res['message'] ?? 'Archived'); _load(); }
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search student…', prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(), isDense: true,
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load)),
          onChanged: (v) => _search = v,
          onSubmitted: (_) => _load(),
        ),
      ),
      Expanded(child: _loading
        ? _loadingView()
        : _students.isEmpty
          ? _empty('No students found.')
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _students.length,
              itemBuilder: (_, i) {
                final st = _students[i];
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppConstants.secondaryColor, child: Text('${st['name']?[0] ?? '?'}', style: const TextStyle(color: Colors.white))),
                  title: Text(st['name'] ?? ''),
                  subtitle: Text('${st['student_code'] ?? ''} · ${st['class_name'] ?? st['class'] ?? '—'}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'move') _moveStudent(st); if (v == 'archive') _archive(st); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'move', child: Row(children: [Icon(Icons.swap_horiz, color: AppConstants.primaryColor), SizedBox(width: 8), Text('Move class')])),
                      PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive, color: AppConstants.warningColor), SizedBox(width: 8), Text('Archive')])),
                    ],
                  ),
                ));
              },
            )),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// PARENTS TAB — reassign to correct student + delete
// ════════════════════════════════════════════════════════════════════════
class _ParentsTab extends StatefulWidget {
  const _ParentsTab();
  @override
  State<_ParentsTab> createState() => _ParentsTabState();
}
class _ParentsTabState extends State<_ParentsTab> {
  bool _loading = true;
  List _parents = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.adminGetParents();
      setState(() { _parents = r['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast(context, e.toString(), error: true);
    }
  }

  Future<void> _reassign(Map p) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Reassign to correct student'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Parent: ${p['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Currently linked: ${p['student_name'] ?? 'none'}'),
        const SizedBox(height: 12),
        TextField(controller: ctrl, decoration: const InputDecoration(
          labelText: 'Correct student code', hintText: 'e.g. SPT0001', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
      ],
    ));
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      final res = await ApiService.adminReassignParent(p['id'], ctrl.text.trim());
      if (mounted) { _toast(context, res['message'] ?? 'Reassigned'); _load(); }
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  Future<void> _delete(Map p) async {
    final ok = await _confirm(context,
      title: 'Delete parent',
      message: 'Delete ${p['name']}? Their child (${p['student_name'] ?? 'none'}) will be kept and simply unlinked.',
      confirmText: 'Delete');
    if (!ok) return;
    try {
      final res = await ApiService.adminDeleteParent(p['id']);
      if (mounted) { _toast(context, res['message'] ?? 'Deleted'); _load(); }
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_parents.isEmpty) return _empty('No parents found.');
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _parents.length,
      itemBuilder: (_, i) {
        final p = _parents[i];
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: AppConstants.warningColor, child: const Icon(Icons.family_restroom, color: Colors.white, size: 20)),
          title: Text(p['name'] ?? ''),
          subtitle: Text('${p['email']}\nChild: ${p['student_name'] ?? 'none'}${p['student_code'] != null ? ' (${p['student_code']})' : ''}'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (v) { if (v == 'reassign') _reassign(p); if (v == 'delete') _delete(p); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reassign', child: Row(children: [Icon(Icons.link, color: AppConstants.primaryColor), SizedBox(width: 8), Text('Reassign child')])),
              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: AppConstants.dangerColor), SizedBox(width: 8), Text('Delete parent')])),
            ],
          ),
        ));
      },
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════
// CLASSES TAB — delete (blocked if active students)
// ════════════════════════════════════════════════════════════════════════
class _ClassesTab extends StatefulWidget {
  const _ClassesTab();
  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}
class _ClassesTabState extends State<_ClassesTab> {
  bool _loading = true;
  List _classes = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getClasses();
      setState(() { _classes = r['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map c) async {
    try {
      final imp = await ApiService.adminClassImpact(c['id']);
      final students = imp['data']?['active_students'] ?? 0;
      final assignments = (imp['data']?['assignments'] ?? []) as List;
      if (!mounted) return;
      if (students > 0) {
        _toast(context, 'Cannot delete: $students active student(s). Move or archive them first.', error: true);
        return;
      }
      final ok = await _confirm(context,
        title: 'Delete class',
        message: 'Delete ${c['name']}? It has no active students. ${assignments.length} teacher assignment(s) will be removed. Students are never deleted.',
        confirmText: 'Delete');
      if (!ok) return;
      final res = await ApiService.adminDeleteClass(c['id']);
      if (mounted) { _toast(context, res['message'] ?? 'Deleted'); _load(); }
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_classes.isEmpty) return _empty('No classes found.');
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _classes.length,
      itemBuilder: (_, i) {
        final c = _classes[i];
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: AppConstants.primaryColor, child: const Icon(Icons.class_, color: Colors.white, size: 20)),
          title: Text('${c['name']} (${c['level']})'),
          subtitle: Text('${c['student_count'] ?? 0} active student(s)'),
          trailing: IconButton(icon: const Icon(Icons.delete, color: AppConstants.dangerColor), onPressed: () => _delete(c)),
        ));
      },
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════
// SUBJECTS TAB — delete (blocked if assigned)
// ════════════════════════════════════════════════════════════════════════
class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab();
  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}
class _SubjectsTabState extends State<_SubjectsTab> {
  bool _loading = true;
  List _subjects = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getSubjects();
      setState(() { _subjects = r['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map s) async {
    try {
      final imp = await ApiService.adminSubjectImpact(s['id']);
      final assignments = (imp['data']?['assignments'] ?? []) as List;
      if (!mounted) return;
      if (assignments.isNotEmpty) {
        _toast(context, 'Cannot delete: still assigned in ${assignments.length} place(s). Unassign first.', error: true);
        return;
      }
      final ok = await _confirm(context,
        title: 'Delete subject',
        message: 'Delete ${s['name']}? It is not assigned anywhere.',
        confirmText: 'Delete');
      if (!ok) return;
      final res = await ApiService.adminDeleteSubject(s['id']);
      if (mounted) { _toast(context, res['message'] ?? 'Deleted'); _load(); }
    } catch (e) { if (mounted) _toast(context, e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_subjects.isEmpty) return _empty('No subjects found.');
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _subjects.length,
      itemBuilder: (_, i) {
        final s = _subjects[i];
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: AppConstants.secondaryColor, child: const Icon(Icons.menu_book, color: Colors.white, size: 20)),
          title: Text(s['name'] ?? ''),
          subtitle: Text('Level: ${s['level'] ?? '—'}'),
          trailing: IconButton(icon: const Icon(Icons.delete, color: AppConstants.dangerColor), onPressed: () => _delete(s)),
        ));
      },
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT LOG TAB
// ════════════════════════════════════════════════════════════════════════
class _AuditTab extends StatefulWidget {
  const _AuditTab();
  @override
  State<_AuditTab> createState() => _AuditTabState();
}
class _AuditTabState extends State<_AuditTab> {
  bool _loading = true;
  List _logs = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.adminAuditLog();
      setState(() { _logs = r['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _toast(context, e.toString(), error: true);
    }
  }

  String _pretty(String action) => action.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_logs.isEmpty) return _empty('No administrative actions recorded yet.');
    return RefreshIndicator(onRefresh: _load, child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length,
      itemBuilder: (_, i) {
        final l = _logs[i];
        return Card(child: ListTile(
          dense: true,
          leading: const Icon(Icons.history, color: AppConstants.primaryColor),
          title: Text('${_pretty(l['action'] ?? '')} — ${l['target_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            '${l['admin_name'] ?? 'admin'} · ${(l['created_at'] ?? '').toString().replaceFirst('T', ' ').split('.').first}'
            '${l['previous_value'] != null ? '\n${l['previous_value']} → ${l['new_value'] ?? ''}' : ''}',
            style: const TextStyle(fontSize: 11)),
          isThreeLine: l['previous_value'] != null,
        ));
      },
    ));
  }
}
