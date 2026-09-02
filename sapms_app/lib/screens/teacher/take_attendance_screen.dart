import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../utils/constants.dart';

class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});
  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  // Selected class/subject/term - chosen by the teacher from their own
  // assignments (class_subjects). No hardcoded defaults: the teacher must
  // pick before a session can open, so they only ever take attendance for
  // classes they are actually assigned to.
  String? _classId;
  String? _subjectId;
  String? _termId;
  String? _className;
  String? _subjectName;

  String? _sessionId;
  bool _sessionOpen  = false;
  bool _scanning     = false;
  bool _loading      = false;
  bool _biometricVerified = false; // teacher fingerprint-verified for this session
  DateTime? _biometricVerifiedAt;
  List _records      = [];
  final List<Map> _scanLog = [];
  final _controller  = MobileScannerController();

  int _pendingSyncCount = 0;
  SyncStatus _syncStatus = SyncStatus.upToDate;
  late final Stream<SyncStatus> _syncStream;

  @override
  void initState() {
    super.initState();
    SyncService.instance.startWatching();
    _syncStream = SyncService.instance.statusStream;
    _syncStream.listen((status) {
      if (mounted) setState(() => _syncStatus = status);
      _refreshPendingCount();
    });
    _refreshPendingCount();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshPendingCount() async {
    final count = await LocalDbService.instance.countUnsynced();
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  // Verifies the teacher's fingerprint before an attendance session can be
  // opened. Returns true only on a genuine successful biometric match -
  // never on a network error, missing hardware, etc. On failure, shows the
  // specific reason from BiometricService so it's clear during testing
  // whether the phone has no fingerprint enrolled vs. the scan itself failed.
  Future<bool> _verifyTeacherBiometric() async {
    final result = await BiometricService.instance.authenticate(
      reason: 'Verify your fingerprint to open this attendance session',
    );
    if (!result.success) {
      _showSnack(result.message, AppConstants.dangerColor);
      return false;
    }
    setState(() {
      _biometricVerified = true;
      _biometricVerifiedAt = DateTime.now();
    });
    return true;
  }

  // Loads the teacher's assigned classes and lets them pick one. Same
  // source (GET /teacher/my-classes -> class_subjects) as the marks screen,
  // so the teacher never types IDs and can only choose their own classes.
  Future<void> _pickClass() async {
    List<Map<String, dynamic>> assignments;
    try {
      final res = await ApiService.getMyClasses();
      assignments = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _showSnack('Could not load your classes: ${e.toString().replaceFirst('Exception: ', '')}',
                 AppConstants.dangerColor);
      return;
    }
    if (assignments.isEmpty) {
      _showSnack('You have no class assignments yet. Ask your school admin to assign you.',
                 Colors.orange);
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, controller) => Column(children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
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
                  backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.1),
                  child: Text(a['level']?.toString() ?? '?',
                    style: const TextStyle(color: AppConstants.primaryColor,
                      fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                title: Text('${a['class_name']} - ${a['subject_name']}'),
                subtitle: Text('Term ${a['term_number']}', style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, a),
              );
            },
          )),
        ]),
      ),
    );
    if (chosen != null) {
      setState(() {
        _classId     = chosen['class_id'];
        _subjectId   = chosen['subject_id'];
        _termId      = chosen['term_id'];
        _className   = chosen['class_name'];
        _subjectName = chosen['subject_name'];
      });
    }
  }

  Future<void> _openSession() async {
    // Must pick a class first - no default. Opens the picker if none chosen.
    if (_classId == null) {
      await _pickClass();
      if (_classId == null) return; // teacher cancelled the picker
    }

    // Gate: attendance can only be opened after a successful fingerprint
    // check for THIS session. If the teacher cancels or fails, we stop
    // here - no session is created and no attendance can be recorded.
    final verified = await _verifyTeacherBiometric();
    if (!verified) return;

    setState(() => _loading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data  = await ApiService.createSession(
        classId:      _classId!,
        subjectId:    _subjectId!,
        termId:       _termId!,
        sessionDate:  today,
        periodNumber: 1,
        biometricVerifiedAt: _biometricVerifiedAt,
      );
      final resumed = data['resumed'] == true;
      setState(() {
        _sessionId   = data['data']['session_id'];
        _sessionOpen = true;
      });
      _showSnack(
        resumed
          ? '[resumed] Resumed existing session - continue scanning where you left off'
          : '[OK] Fingerprint verified - session opened (${data['data']['student_count'] ?? 0} students expected)',
        resumed ? Colors.blue : Colors.green,
      );
    } catch (e) {
      _showSnack(e.toString(), AppConstants.dangerColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Offline-first: try the server first for an immediate confirmation
  // (nice UX when connectivity is fine); if that fails for ANY reason
  // (no network, timeout, server down) queue the scan locally instead
  // of losing it. This is the core behaviour required by proposal
  // Section 3.7.1 for the Cyato/Shangi low-connectivity zones.
  Future<void> _onQRDetected(BarcodeCapture capture) async {
    if (!_sessionOpen || _sessionId == null) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final qrData = barcode!.rawValue!;
    if (!qrData.startsWith('SAPMS:')) return;

    // Capture the display time BEFORE any await so we don't touch
    // BuildContext across an async gap (Flutter lint: use_build_context_synchronously).
    final now = TimeOfDay.now().format(context);
    final nowIso = DateTime.now().toIso8601String();

    // Prevent duplicate scans (both in-memory log and local offline queue)
    if (_scanLog.any((s) => s['qr'] == qrData)) return;
    if (await LocalDbService.instance.isAlreadyQueued(_sessionId!, qrData)) return;

    try {
      final result = await ApiService.scanQR(_sessionId!, qrData);
      final student = result['data'];
      setState(() => _scanLog.add({
        'qr':     qrData,
        'name':   student['student_name'],
        'status': student['status'],
        'time':   now,
        'queued': false,
      }));
      _showSnack('[OK] ${student['student_name']} marked present', AppConstants.successColor);
    } catch (e) {
      // Network/server failure - queue locally instead of dropping the scan.
      await LocalDbService.instance.queueScan(PendingScan(
        sessionId: _sessionId!,
        qrData: qrData,
        status: 'present',
        clientScannedAt: nowIso,
        studentNameGuess: 'Scanned student', // real name arrives once synced
      ));
      setState(() => _scanLog.add({
        'qr':     qrData,
        'name':   'Scanned student (offline)',
        'status': 'present',
        'time':   now,
        'queued': true,
      }));
      await _refreshPendingCount();
      _showSnack(' No connection - scan saved offline, will sync automatically', AppConstants.warningColor);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    final result = await SyncService.instance.syncNow();
    if (mounted) setState(() => _loading = false);
    await _refreshPendingCount();

    if (result.error != null) {
      _showSnack('Sync failed: ${result.error}', AppConstants.dangerColor);
    } else if (result.skipped && result.attempted == 0) {
      _showSnack('Still offline - will retry automatically', AppConstants.warningColor);
    } else if (result.attempted == 0) {
      _showSnack('Already up to date', Colors.green);
    } else {
      _showSnack('Synced ${result.succeeded}/${result.attempted} scans'
          '${result.failed > 0 ? " (${result.failed} failed - will retry)" : ""}',
          result.failed > 0 ? AppConstants.warningColor : Colors.green);
    }
  }

  Future<void> _closeSession() async {
    if (_sessionId == null) return;

    // Closing marks every un-scanned student absent server-side, so make
    // sure any offline-queued scans for this session go through FIRST -
    // otherwise a present student could get wrongly auto-marked absent.
    if (_pendingSyncCount > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsynced scans'),
          content: Text('$_pendingSyncCount scan(s) haven\'t synced to the server yet. '
              'Closing now may mark those students absent by mistake. '
              'Try syncing first?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close Anyway')),
          ],
        ),
      );
      if (proceed != true) {
        await _syncNow();
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final data = await ApiService.closeSession(_sessionId!);
      final absences = data['data']['absences'];
      final notifs   = data['data']['notifications_queued'];
      _showSnack('Session closed - $absences absent, $notifs parents notified', Colors.green);
      await _loadRecords();
      setState(() {
        _sessionOpen = false;
        _scanning = false;
        _biometricVerified = false; // require re-verification for the next session
        _biometricVerifiedAt = null;
      });
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
          // Offline sync status banner
          if (_pendingSyncCount > 0 || _syncStatus == SyncStatus.offline)
            _buildSyncBanner(),

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
                Text(
                  _className != null
                    ? '$_className - $_subjectName - Period 1'
                    : 'Tap "Open Session" to pick a class',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (_sessionId != null)
                  Text('Scanned: ${_scanLog.length} students',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (_sessionOpen && _biometricVerified)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fingerprint, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Teacher verified', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ])),
              if (!_sessionOpen)
                ElevatedButton(
                  onPressed: _loading ? null : _openSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    // The global theme sets minimumSize to infinite width for
                    // full-width buttons; this button lives inside a Row, where
                    // infinite width is illegal and crashes layout. Override it
                    // back to a natural, finite size.
                    minimumSize: const Size(64, 40),
                  ),
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
                Icon(
                  s['queued'] == true ? Icons.cloud_upload_outlined : Icons.check_circle,
                  color: s['queued'] == true ? AppConstants.warningColor : AppConstants.successColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                if (s['queued'] == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('queued', style: TextStyle(color: AppConstants.warningColor, fontSize: 11)),
                  ),
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

  Widget _buildSyncBanner() {
    final offline = _syncStatus == SyncStatus.offline;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: offline ? Colors.grey.shade200 : AppConstants.warningColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: offline ? Colors.grey.shade400 : AppConstants.warningColor),
      ),
      child: Row(children: [
        Icon(offline ? Icons.cloud_off : Icons.cloud_upload_outlined,
          color: offline ? Colors.grey.shade600 : AppConstants.warningColor, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          offline
            ? 'Offline - scans are being saved on this device'
            : '$_pendingSyncCount scan(s) waiting to sync',
          style: TextStyle(
            fontSize: 12.5,
            color: offline ? Colors.grey.shade700 : AppConstants.warningColor,
            fontWeight: FontWeight.w600,
          ),
        )),
        if (!offline && _pendingSyncCount > 0)
          TextButton(
            onPressed: _loading ? null : _syncNow,
            child: const Text('Sync Now'),
          ),
      ]),
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
