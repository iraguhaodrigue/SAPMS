// ============================================================
// SAPMS - Sync Service (Offline-First background sync)
// ============================================================
// Watches connectivity_plus for reconnection events and flushes
// whatever is sitting in the local SQLite queue via the batch
// endpoint (POST /api/attendance/scan/batch). This is the Flutter-side
// half of proposal Section 3.7.1's "background synchronization
// service"; the thesis names Dart's Isolate API as the original plan,
// but a plain async Future queue is used here since the sync payloads
// are small (a class's worth of scans) and don't need a separate
// isolate to avoid jank — worth revisiting if bulk historical
// backfills are added later.
// ============================================================

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'local_db_service.dart';
import '../utils/constants.dart';
import 'package:http/http.dart' as http;

class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _syncing = false;
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  void startWatching() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        // Small delay lets the radio actually establish before we hammer it
        Future.delayed(const Duration(seconds: 2), syncNow);
      }
    });
  }

  void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> isOnline() async {
    // connectivity_plus itself warns that a non-none result only means a
    // network *interface* is active — the device could be joined to a
    // Wi-Fi/mobile network with no actual internet behind it (common with
    // intermittent rural towers). So we treat interface state as a cheap
    // first filter, then confirm with a real request to our own API before
    // trusting it enough to flush the queue.
    final results = await Connectivity().checkConnectivity();
    final interfaceUp = results.any((r) => r != ConnectivityResult.none);
    // interface check skipped: unreliable on USB tethering; health check below is authoritative

    try {
      final res = await http
          .get(Uri.parse('${ApiService.effectiveBaseUrl}/health'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pushes every unsynced scan to the server in one batch call.
  /// Safe to call repeatedly / concurrently — guarded by [_syncing].
  Future<SyncResult> syncNow() async {
    if (_syncing) return SyncResult(attempted: 0, succeeded: 0, failed: 0, skipped: true);
    _syncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      final online = await isOnline();
      if (!online) {
        _statusController.add(SyncStatus.offline);
        return SyncResult(attempted: 0, succeeded: 0, failed: 0, skipped: true);
      }

      final pending = await LocalDbService.instance.getUnsyncedScans();
      final pendingSheets = await LocalDbService.instance.getUnsyncedMarkSheets();
      if (pending.isEmpty && pendingSheets.isEmpty) {
        _statusController.add(SyncStatus.upToDate);
        return SyncResult(attempted: 0, succeeded: 0, failed: 0, skipped: false);
      }

      // ── Marks sheets first (idempotent server-side: UPDATE-based) ──
      int marksSynced = 0, marksFailed = 0;
      for (final entry in pendingSheets.entries) {
        try {
          await ApiService.bulkUpdateMarks(
            assessmentId: entry.key,
            marks: List<Map<String, dynamic>>.from(entry.value['marks']),
            biometricVerifiedAt: entry.value['bioAt'] != null
                ? DateTime.tryParse(entry.value['bioAt'] as String)
                : null,
          );
          await LocalDbService.instance.markSheetSynced(entry.key);
          marksSynced++;
        } catch (e) {
          await LocalDbService.instance.markSheetFailed(entry.key, e.toString());
          marksFailed++;
        }
      }

      if (pending.isEmpty) {
        _statusController.add(marksFailed == 0 ? SyncStatus.upToDate : SyncStatus.partialFailure);
        return SyncResult(attempted: marksSynced + marksFailed,
            succeeded: marksSynced, failed: marksFailed, skipped: false);
      }

      final response = await ApiService.syncScanBatch(
        pending.map((p) => p.toSyncPayload()).toList(),
      );

      int succeeded = 0, failed = 0;
      final results = (response['data'] as List?) ?? [];
      for (final r in results) {
        final localId = r['local_id'] as int?;
        if (localId == null) continue;
        if (r['success'] == true) {
          await LocalDbService.instance.markSynced(localId);
          succeeded++;
        } else {
          await LocalDbService.instance.markSyncFailed(localId, r['message']?.toString() ?? 'Unknown error');
          failed++;
        }
      }

      // Housekeeping: drop synced rows older than a week so the local
      // DB doesn't grow unbounded on a device that's rarely wiped.
      await LocalDbService.instance.clearSyncedOlderThan(const Duration(days: 7));

      _statusController.add(failed == 0 ? SyncStatus.upToDate : SyncStatus.partialFailure);
      return SyncResult(attempted: pending.length, succeeded: succeeded, failed: failed, skipped: false);
    } catch (e) {
      _statusController.add(SyncStatus.error);
      return SyncResult(attempted: 0, succeeded: 0, failed: 0, skipped: false, error: e.toString());
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

enum SyncStatus { offline, syncing, upToDate, partialFailure, error }

class SyncResult {
  final int attempted;
  final int succeeded;
  final int failed;
  final bool skipped;
  final String? error;
  SyncResult({
    required this.attempted,
    required this.succeeded,
    required this.failed,
    required this.skipped,
    this.error,
  });
}
