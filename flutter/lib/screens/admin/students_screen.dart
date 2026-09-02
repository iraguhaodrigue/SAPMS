import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/stat_card.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List _students = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({String? search}) async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getStudents(search: search);
      setState(() => _students = data['data'] ?? []);
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
        title: const Text('Students'),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear),
                    onPressed: () { _searchCtrl.clear(); _load(); })
                : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: AppConstants.bgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (v) => _load(search: v.isEmpty ? null : v),
          ),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _students.isEmpty
              ? const Center(child: Text('No students found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _students.length,
                  itemBuilder: (_, i) {
                    final s = _students[i];
                    return ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(studentId: s['id']),
                      )),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: CircleAvatar(
                        backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                        child: Text(s['name'][0],
                          style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${s['student_code']} • ${s['class_name']}',
                        style: const TextStyle(fontSize: 12)),
                      trailing: s['risk_level'] != null && s['risk_level'] != 'low'
                        ? RiskBadge(s['risk_level']) : null,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
