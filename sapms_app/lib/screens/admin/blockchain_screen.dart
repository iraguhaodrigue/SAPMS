import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Admin-facing view of the self-contained blockchain audit ledger.
// Shows each block as a linked card and provides a "Verify Integrity"
// action that walks the whole chain server-side and reports whether it
// is intact or has been tampered with — the key demo for the thesis.
class BlockchainScreen extends StatefulWidget {
  const BlockchainScreen({super.key});
  @override
  State<BlockchainScreen> createState() => _BlockchainScreenState();
}

class _BlockchainScreenState extends State<BlockchainScreen> {
  List _blocks = [];
  bool _loading = true;
  bool _verifying = false;
  Map<String, dynamic>? _verifyResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getBlockchain();
      setState(() {
        _blocks = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _verify() async {
    setState(() { _verifying = true; _verifyResult = null; });
    try {
      final res = await ApiService.verifyBlockchain();
      setState(() { _verifyResult = res['data']; _verifying = false; });
    } catch (e) {
      setState(() {
        _verifyResult = {'valid': false, 'reason': e.toString()};
        _verifying = false;
      });
    }
  }

  String _shortHash(String? h) {
    if (h == null || h.isEmpty) return '—';
    if (h.length <= 16) return h;
    return '${h.substring(0, 10)}…${h.substring(h.length - 6)}';
  }

  String _blockLabel(String? type) {
    switch (type) {
      case 'genesis':            return 'Genesis Block';
      case 'attendance_session': return 'Attendance Session';
      case 'mark_submission':    return 'Grade Submission';
      default:                   return type ?? 'Block';
    }
  }

  IconData _blockIcon(String? type) {
    switch (type) {
      case 'genesis':            return Icons.flag_rounded;
      case 'attendance_session': return Icons.how_to_reg_rounded;
      case 'mark_submission':    return Icons.grading_rounded;
      default:                   return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        title: const Text('Blockchain Ledger'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load ledger:\n$_error',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ))
          : Column(children: [
              _buildVerifyBanner(),
              Expanded(child: _blocks.isEmpty
                ? const Center(child: Text('No blocks yet. Close an attendance session to seal the first block.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blocks.length,
                    itemBuilder: (_, i) => _buildBlockCard(_blocks[i], i),
                  )),
            ]),
    );
  }

  Widget _buildVerifyBanner() {
    Color bg = Colors.blueGrey.shade50;
    Widget content;

    if (_verifyResult == null) {
      content = Row(children: [
        const Icon(Icons.shield_outlined, color: Colors.blueGrey),
        const SizedBox(width: 10),
        const Expanded(child: Text('Tap "Verify Integrity" to check the chain has not been tampered with.',
          style: TextStyle(fontSize: 13))),
      ]);
    } else {
      final valid = _verifyResult!['valid'] == true;
      bg = valid ? Colors.green.shade50 : Colors.red.shade50;
      content = Row(children: [
        Icon(valid ? Icons.verified_rounded : Icons.gpp_bad_rounded,
          color: valid ? Colors.green.shade700 : Colors.red.shade700, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valid ? 'Chain Valid ✓' : 'Chain Tampered ✗',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
              color: valid ? Colors.green.shade800 : Colors.red.shade800)),
          Text(valid
              ? 'All ${_verifyResult!['length'] ?? _blocks.length} blocks intact and cryptographically linked.'
              : 'Broken at block ${_verifyResult!['brokenAt']}: ${_verifyResult!['reason']}',
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ])),
      ]);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        content,
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _verifying ? null : _verify,
          icon: _verifying
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.security_rounded, size: 18),
          label: Text(_verifying ? 'Verifying…' : 'Verify Integrity'),
          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
        )),
      ]),
    );
  }

  Widget _buildBlockCard(dynamic b, int listIndex) {
    final type  = b['data_type']?.toString();
    final isGenesis = type == 'genesis';

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isGenesis ? Colors.amber.shade300 : AppConstants.primaryColor.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isGenesis ? Colors.amber : AppConstants.primaryColor).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(_blockIcon(type), size: 20,
                color: isGenesis ? Colors.amber.shade800 : AppConstants.primaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Block #${b['block_index']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(_blockLabel(type), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
          ]),
          const Divider(height: 20),
          _kv('Hash', _shortHash(b['block_hash']?.toString())),
          _kv('Prev', _shortHash(b['previous_hash']?.toString())),
          _kv('Nonce', '${b['nonce']}'),
          if (b['reference_id'] != null)
            _kv('Session', b['reference_id'].toString().substring(0, 8)),
        ]),
      ),
      // Chain link connector (except after the last/oldest block)
      if (listIndex < _blocks.length - 1)
        Container(
          height: 22, width: 2,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: AppConstants.primaryColor.withOpacity(0.3),
        ),
    ]);
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 64, child: Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500))),
    ]),
  );
}
