import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Admin review queue for self-registered teachers and parents.
// Approving a parent is the moment their child link (parent_id) is applied.
class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});
  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  List _pending = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getPendingUsers();
      setState(() { _pending = res['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _review(String id, String action) async {
    setState(() => _busy.add(id));
    try {
      await ApiService.reviewUser(id, action);
      setState(() => _pending.removeWhere((u) => u['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approve' ? '✓ Approved' : 'Rejected'),
          backgroundColor: action == 'approve' ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppConstants.dangerColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.grey)))
          : _pending.isEmpty
            ? const Center(child: Text('No pending registrations',
                style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pending.length,
                itemBuilder: (_, i) => _buildCard(_pending[i]),
              ),
    );
  }

  Widget _buildCard(dynamic u) {
    final isParent = u['role'] == 'parent';
    final busy = _busy.contains(u['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: (isParent ? Colors.teal : AppConstants.primaryColor).withOpacity(0.12),
            child: Icon(isParent ? Icons.family_restroom_rounded : Icons.school_rounded,
              color: isParent ? Colors.teal : AppConstants.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${u['role']?.toString().toUpperCase()} • ${u['email'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
        ]),
        if (isParent && u['pending_student_code'] != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.link_rounded, size: 14, color: Colors.teal),
              const SizedBox(width: 6),
              Flexible(child: Text(
                'Will be linked to: ${u['student_name'] ?? 'unknown student'} (${u['pending_student_code']})',
                style: const TextStyle(fontSize: 12))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: busy ? null : () => _review(u['id'], 'reject'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Reject'),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: busy ? null : () => _review(u['id'], 'approve'),
            child: busy
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Approve'),
          )),
        ]),
      ]),
    );
  }
}
