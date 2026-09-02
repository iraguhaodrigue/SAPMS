// ============================================================
// SAPMS - Local Database Service (Offline-First)
// ============================================================
// Implements proposal Section 3.7.1: stores attendance scans (and,
// by the same pattern, marks) locally in SQLite so a teacher can keep
// working with zero connectivity — the norm in the Cyato highlands
// (NS-02) and Shangi border zone (NS-06). A background sync flushes
// the queue to the Node.js API once connectivity returns, using
// last-write-wins conflict resolution on the server side.
//
// Table: pending_scans
//   Mirrors the payload attendanceController.scanQR / scanBatch expects,
//   plus local bookkeeping (id, synced, created_at, sync_error).
// ============================================================

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class PendingScan {
  final int? localId;
  final String sessionId;
  final String qrData;
  final String status; // present/absent/late/excused
  final String clientScannedAt; // ISO8601, captured at scan time on-device
  final String studentNameGuess; // best-effort label to show in the queued list before sync
  bool synced;
  String? syncError;

  PendingScan({
    this.localId,
    required this.sessionId,
    required this.qrData,
    required this.status,
    required this.clientScannedAt,
    required this.studentNameGuess,
    this.synced = false,
    this.syncError,
  });

  Map<String, dynamic> toMap() => {
        if (localId != null) 'local_id': localId,
        'session_id': sessionId,
        'qr_data': qrData,
        'status': status,
        'client_scanned_at': clientScannedAt,
        'student_name_guess': studentNameGuess,
        'synced': synced ? 1 : 0,
        'sync_error': syncError,
      };

  factory PendingScan.fromMap(Map<String, dynamic> m) => PendingScan(
        localId: m['local_id'] as int?,
        sessionId: m['session_id'] as String,
        qrData: m['qr_data'] as String,
        status: m['status'] as String,
        clientScannedAt: m['client_scanned_at'] as String,
        studentNameGuess: m['student_name_guess'] as String? ?? 'Student',
        synced: (m['synced'] as int? ?? 0) == 1,
        syncError: m['sync_error'] as String?,
      );

  /// Payload shape expected by POST /api/attendance/scan/batch
  Map<String, dynamic> toSyncPayload() => {
        'local_id': localId,
        'session_id': sessionId,
        'qr_data': qrData,
        'status': status,
        'client_scanned_at': clientScannedAt,
      };
}

class LocalDbService {
  LocalDbService._internal();
  static final LocalDbService instance = LocalDbService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'sapms_offline.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_scans (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            qr_data TEXT NOT NULL,
            status TEXT NOT NULL,
            client_scanned_at TEXT NOT NULL,
            student_name_guess TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            sync_error TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        // Room to grow: marks queued offline follow the identical pattern.
        await db.execute('''
          CREATE TABLE pending_marks (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            assessment_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            score REAL,
            is_absent INTEGER NOT NULL DEFAULT 0,
            remarks TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            sync_error TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      },
    );
  }

  // ── Attendance scans ─────────────────────────────────────
  Future<int> queueScan(PendingScan scan) async {
    final database = await db;
    return database.insert('pending_scans', scan.toMap()..remove('local_id'));
  }

  Future<List<PendingScan>> getUnsyncedScans({String? sessionId}) async {
    final database = await db;
    final rows = await database.query(
      'pending_scans',
      where: sessionId != null ? 'synced = 0 AND session_id = ?' : 'synced = 0',
      whereArgs: sessionId != null ? [sessionId] : null,
      orderBy: 'local_id ASC',
    );
    return rows.map((r) => PendingScan.fromMap(r)).toList();
  }

  Future<List<PendingScan>> getAllScansForSession(String sessionId) async {
    final database = await db;
    final rows = await database.query(
      'pending_scans',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'local_id DESC',
    );
    return rows.map((r) => PendingScan.fromMap(r)).toList();
  }

  Future<int> countUnsynced() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS cnt FROM pending_scans WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSynced(int localId) async {
    final database = await db;
    await database.update(
      'pending_scans',
      {'synced': 1, 'sync_error': null},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markSyncFailed(int localId, String error) async {
    final database = await db;
    await database.update(
      'pending_scans',
      {'sync_error': error},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Prevents double-queueing the same student twice within one session
  /// while offline (mirrors server-side unique constraint behaviour).
  Future<bool> isAlreadyQueued(String sessionId, String qrData) async {
    final database = await db;
    final rows = await database.query(
      'pending_scans',
      where: 'session_id = ? AND qr_data = ?',
      whereArgs: [sessionId, qrData],
    );
    return rows.isNotEmpty;
  }

  Future<void> clearSyncedOlderThan(Duration age) async {
    final database = await db;
    final cutoff = DateTime.now().subtract(age).toIso8601String();
    await database.delete(
      'pending_scans',
      where: 'synced = 1 AND created_at < ?',
      whereArgs: [cutoff],
    );
  }

  // ── Marks (offline queue — same pattern as scans) ────────
  // A whole sheet submission is queued as one row per mark plus the shared
  // biometric timestamp, keyed by assessment. Server-side bulkUpdateMarks is
  // UPDATE-based, so re-syncing the same rows can never create duplicates.
  Future<void> queueMarksSheet({
    required String assessmentId,
    required List<Map<String, dynamic>> marks,
    String? biometricVerifiedAt,
  }) async {
    final database = await db;
    final batch = database.batch();
    // Replace any previous queued copy of this sheet (teacher re-edited offline)
    batch.delete('pending_marks',
        where: 'assessment_id = ? AND synced = 0', whereArgs: [assessmentId]);
    for (final m in marks) {
      batch.insert('pending_marks', {
        'assessment_id': assessmentId,
        'student_id': m['student_id'],
        'score': m['score'],
        'is_absent': (m['is_absent'] == true || m['is_absent'] == 1) ? 1 : 0,
        'remarks': biometricVerifiedAt, // reuse column to carry the timestamp
        'synced': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Unsynced marks grouped by assessment → { assessmentId: {bioAt, marks:[...]}}
  Future<Map<String, Map<String, dynamic>>> getUnsyncedMarkSheets() async {
    final database = await db;
    final rows = await database.query('pending_marks',
        where: 'synced = 0', orderBy: 'assessment_id');
    final out = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final aid = r['assessment_id'] as String;
      out.putIfAbsent(aid, () => {'bioAt': r['remarks'], 'marks': <Map<String, dynamic>>[]});
      (out[aid]!['marks'] as List).add({
        'student_id': r['student_id'],
        'score': r['score'],
        'is_absent': (r['is_absent'] as int) == 1,
      });
    }
    return out;
  }

  Future<void> markSheetSynced(String assessmentId) async {
    final database = await db;
    await database.update('pending_marks', {'synced': 1, 'sync_error': null},
        where: 'assessment_id = ? AND synced = 0', whereArgs: [assessmentId]);
  }

  Future<void> markSheetFailed(String assessmentId, String error) async {
    final database = await db;
    await database.update('pending_marks',
        {'sync_error': error.length > 200 ? error.substring(0, 200) : error},
        where: 'assessment_id = ? AND synced = 0', whereArgs: [assessmentId]);
  }

  Future<int> countUnsyncedMarks() async {
    final database = await db;
    final r = await database.rawQuery(
        'SELECT COUNT(DISTINCT assessment_id) AS cnt FROM pending_marks WHERE synced = 0');
    return (r.first['cnt'] as int?) ?? 0;
  }
}
