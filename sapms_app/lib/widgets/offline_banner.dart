import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/local_db_service.dart';
import '../utils/constants.dart';

/// A slim banner that tells the user their connection status and how many
/// records are waiting to sync. Drop it at the top of any screen's body:
///
///   Column(children: [ const OfflineBanner(), Expanded(child: ...) ])
///
/// It listens to SyncService.statusStream (already backed by connectivity_plus)
/// so it updates live as the phone goes offline/online and as the local queue
/// drains. When everything is online and synced, it renders nothing (zero height).
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<SyncStatus>? _sub;
  SyncStatus _status = SyncStatus.upToDate;
  int _pending = 0;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _sub = SyncService.instance.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final online = await SyncService.instance.isOnline();
    final scans  = await LocalDbService.instance.countUnsynced();
    int marks = 0;
    try { marks = await LocalDbService.instance.countUnsyncedMarks(); } catch (_) {}
    if (!mounted) return;
    setState(() { _online = online; _pending = scans + marks; });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Nothing to show: online, synced, idle.
    final nothingToShow = _online &&
        _pending == 0 &&
        _status != SyncStatus.syncing &&
        _status != SyncStatus.partialFailure;
    if (nothingToShow) return const SizedBox.shrink();

    // Decide colour + message
    Color bg; IconData icon; String msg;
    if (!_online) {
      bg = Colors.orange.shade700;
      icon = Icons.cloud_off_rounded;
      msg = _pending > 0
          ? "You're offline - $_pending record(s) saved on this device, will sync when back online"
          : "You're offline - records will be saved on this device and synced later";
    } else if (_status == SyncStatus.syncing) {
      bg = Colors.blue.shade600;
      icon = Icons.sync_rounded;
      msg = 'Syncing $_pending record(s)...';
    } else if (_status == SyncStatus.partialFailure) {
      bg = Colors.red.shade600;
      icon = Icons.sync_problem_rounded;
      msg = '$_pending record(s) could not sync - will retry';
    } else if (_pending > 0) {
      bg = Colors.blue.shade600;
      icon = Icons.cloud_upload_rounded;
      msg = '$_pending record(s) waiting to sync';
    } else {
      return const SizedBox.shrink();
    }

    return Material(
      color: bg,
      child: InkWell(
        // Tap to force a sync attempt now (only useful when online)
        onTap: _online ? () => SyncService.instance.syncNow() : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 18, height: 18,
              child: _status == SyncStatus.syncing
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                : Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3))),
            if (_online && _pending > 0 && _status != SyncStatus.syncing)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Tap to sync',
                  style: TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }
}
