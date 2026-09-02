import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});
  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  // Hardcoded demo values matching our seed data
  // In full app, teacher selects class/subject from dropdowns
  final String _classId   = 'cls-ns01-s4a';
  final String _subjectId = 'sub-math';
  final String _termId    = 'term-2';

  String? _sessionId;
  bool _sessionOpen  = false;
  bool _scanning     = false;
  bool _loading      = false;
  List _records      = [];
  final List<Map> _scanLog = [];
  final _controller  = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSession() async {
    setState(() => _loading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data  = await ApiService.createSession(
        classId:      _classId,
        subjectId:    _subjectId,
        termId:       _termId,
        sessionDate:  today,
        periodNumber: 1,
      );
      setState(() {
        _sessionId  = data['data']['session_id'];
        _sessionOpen = true;
      });
      _showSnack('Session opened — ${data['data']['student_count']} students expected', Colors.green);
    } catch (e) {
      _showSnack(e.toString(), AppConstants.dangerColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onQRDetected(BarcodeCapture capture) async {
    if (!_sessionOpen || _sessionId == null) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final qrData = barcode!.rawValue!;
    if (!qrData.startsWith('SAPMS:')) return;

    // Prevent duplicate scans
    if (_scanLog.any((s) => s['qr'] == qrData)) return;

    try {
      final result = await ApiService.scanQR(_sessionId!, qrData);
      final student = result['data'];
      setState(() => _scanLog.add({
        'qr':    qrData,
        'name':  student['student_name'],
        'status': student['status'],
        'time':  TimeOfDay.now().format(context),
      }));
      _showSnack('✓ ${student['student_name']} marked present', AppConstants.successColor);
    } catch (e) {
      _showSnack('⚠ ${e.toString()}', AppConstants.warningColor);
    }
  }

  Future<void> _closeSession() async {
    if (_sessionId == null) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.closeSession(_sessionId!);
      final absences = data['data']['absences'];
      final notifs   = data['data']['notifications_queued'];
      _showSnack('Session closed — $absences absent, $notifs parents notified', Colors.green);
      await _loadRecords();
      setState(() { _sessionOpen = false; _scanning = false; });
    } catch (e) {
      _showSnack(e.toString(), AppConstants.dangerColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecords() async {
    if (_sessionId == null) return;
    final data = await ApiService.getSessionRecords(_sessionId!);
    setState(() => _records = data['data'] ?? []);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Take Attendance'),
        actions: [
          if (_sessionOpen)
            TextButton(
              onPressed: _loading ? null : _closeSession,
              child: const Text('Close Session', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Session info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _sessionOpen ? AppConstants.successColor : Colors.grey.shade300,
              ),
            ),
            child: Row(children: [
              Icon(
                _sessionOpen ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _sessionOpen ? AppConstants.successColor : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_sessionOpen ? 'Session Active' : 'No Active Session',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _sessionOpen ? AppConstants.successColor : Colors.grey,
                  )),
                Text('S4-A • Mathematics • Period 1',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (_sessionId != null)
                  Text('Scanned: ${_scanLog.length} students',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              if (!_sessionOpen)
                ElevatedButton(
                  onPressed: _loading ? null : _openSession,
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  child: _loading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Start', style: TextStyle(color: Colors.white)),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // Scanner
          if (_sessionOpen) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('QR Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Switch(
                value: _scanning,
                activeColor: AppConstants.primaryColor,
                onChanged: (v) => setState(() => _scanning = v),
              ),
            ]),
            const SizedBox(height: 8),
            if (_scanning)
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.primaryColor, width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onQRDetected,
                  overlayBuilder: (ctx, constraints) => Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.accentColor, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(60),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _scanning = true),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2), style: BorderStyle.solid),
                  ),
                  child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 40, color: AppConstants.primaryColor),
                    SizedBox(height: 8),
                    Text('Tap to start scanning', style: TextStyle(color: AppConstants.primaryColor)),
                  ])),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Scan log
          if (_scanLog.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Scanned Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            ..._scanLog.reversed.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.check_circle, color: AppConstants.successColor, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                Text(s['time'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            )),
          ],

          // Final records after session closed
          if (!_sessionOpen && _records.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Session Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            ..._records.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(_statusIcon(r['status']), color: _statusColor(r['status']), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(r['student_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(r['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(r['status']?.toUpperCase() ?? '',
                    style: TextStyle(fontSize: 11, color: _statusColor(r['status']), fontWeight: FontWeight.bold)),
                ),
              ]),
            )),
          ],
        ]),
      ),
    );
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'present': return Icons.check_circle;
      case 'late':    return Icons.access_time;
      default:        return Icons.cancel;
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'present': return AppConstants.successColor;
      case 'late':    return AppConstants.warningColor;
      default:        return AppConstants.dangerColor;
    }
  }
}
