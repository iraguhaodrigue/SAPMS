# SAPMS — What's New in This Build

This adds the three missing pieces identified against the thesis proposal
(QR attendance was already fully implemented in your original code — no
changes needed there). Everything below is additive; nothing in your
existing controllers' public behaviour changed except where noted.

## 1. Offline-First Sync (Proposal §3.7.1)

**New files:**
- `sapms_app/lib/services/local_db_service.dart` — SQLite queue (`pending_scans` table)
- `sapms_app/lib/services/sync_service.dart` — watches connectivity, auto-flushes the queue
- `sapms-backend/src/controllers/attendanceController.js` — added `scanBatch()`
- `sapms-backend/src/routes/index.js` — added `POST /api/attendance/scan/batch`

**How it works:** `take_attendance_screen.dart` tries the live API first. If
that throws (no signal, timeout, server down), the scan is written to a
local SQLite table instead of being lost. A `connectivity_plus` listener
fires `syncNow()` automatically when the device reconnects, pushing every
queued scan to the new batch endpoint in one call. The UI shows a banner
with the pending count and a manual "Sync Now" button. Closing a session
while scans are still queued prompts the teacher to sync first, since
closing auto-marks any un-scanned student absent.

**Setup:** run `flutter pub get` in `sapms_app/` — `sqflite`,
`connectivity_plus`, and `path` were added to `pubspec.yaml`.

## 2. SMS + Push Notifications (Proposal §3.7.4)

**New files:**
- `sapms-backend/src/services/notificationService.js` — Africa's Talking SMS + Firebase push
- `sapms-backend/src/jobs/notificationWorker.js` — cron safety net, retries anything stuck `pending`
- `sapms-backend/database/migration_002_notifications_ml.sql` — adds `users.fcm_token`

**How it works:** your existing code already *queued* notifications into
the `notifications` table on absence/risk events — it just never sent
them. `notificationService.dispatchPendingNotifications()` now does that:
SMS via Africa's Talking, push via Firebase Admin SDK. `closeSession()`
fires dispatch in the background right after queuing (non-blocking, so a
slow SMS gateway never freezes the teacher's UI), and a 5-minute cron
job catches anything that failed or got missed.

**Runs in dry-run mode with zero config** — if `AT_API_KEY` or
`FIREBASE_SERVICE_ACCOUNT_PATH` aren't set in `.env`, messages are logged
to the console instead of sent, so you can develop/demo without live
credentials. Fill in `.env` (see `.env.example`) when you're ready to send
real messages — Africa's Talking sandbox credentials are free.

**Setup:**
1. `npm install` (adds `africastalking`, `firebase-admin`, `node-cron`)
2. `mysql -u <user> -p sapms_db < database/migration_002_notifications_ml.sql`
3. Fill in `.env` when ready for live sending (optional — dry-run works out of the box)

## 3. ML Predictive Risk Model (Proposal §3.7.5)

**New files:**
- `sapms-backend/ml_service/train_model.py` — trains LR/DT/RF, exports the best (Random Forest)
- `sapms-backend/ml_service/app.py` — Flask microservice serving `/predict`
- `sapms-backend/src/services/mlService.js` — Node.js client, called from `recalculateAnalytics()`

**How it works:** `attendanceController.recalculateAnalytics()` (unchanged
trigger points — still runs on session close) now computes the full
Table 3.3 feature set and calls the ML microservice for a Random Forest
prediction. **If the microservice is unreachable, it falls back to your
original rule-based logic automatically** — so the system degrades
gracefully rather than breaking if Python isn't running. The
`student_analytics` table now records which source (`rule_based` vs
`ml_model`) produced each score, for your Chapter 4 results section.

**Setup:**
```bash
cd ml_service
pip install -r requirements.txt --break-system-packages

# Test the pipeline immediately with synthetic data (no DB needed):
python train_model.py --source demo

# Once you have real attendance/marks data:
python train_model.py --source db --db-host localhost --db-user root --db-password <pw>

python app.py   # starts on port 8001
```
Verified working end-to-end in this environment: training completes in
seconds, the Flask service loads the model, and Node's `mlService.js`
correctly retrieves `high`/`low` risk classifications from it.

⚠️ **Port note:** the service runs on **8001**, not 6000 — Node's/browsers'
`fetch()` refuses to connect to port 6000 (it's on the standard
"bad ports" blocklist, originally reserved for X11). If you change the
port, avoid that list.

**On labelling:** `train_model.py --source demo` generates synthetic
labels using the same rule as the features (attendance<85% + gpa<50),
so it scores unrealistically well (~100%) — that's expected, it's only
there to prove the pipeline works before real data exists. Once you
switch to `--source db`, pass `--labels-csv` with genuinely independent
outcomes (which students actually dropped out / failed, from your
document review in §3.6.3) for a metrics report that means something
for Chapter 4.

## Everything else (for context)

**Already fully implemented in your original code — verified, no changes
needed:**
- QR code generation (`studentsController.getStudentQR`, SHA-256 hashed, §3.7.2)
- QR scanning UI (`take_attendance_screen.dart`, `mobile_scanner` package)
- Four-role RBAC (`middleware/auth.js`, §3.7.3)
- Rule-based attendance rate / GPA / risk flagging (now upgraded to try ML first)

## Running the whole stack together

```bash
# Terminal 1 — MySQL must be running, schema + migration applied
cd sapms-backend
npm install
npm run dev              # http://localhost:5000

# Terminal 2 — ML microservice (optional but recommended)
cd sapms-backend/ml_service
python train_model.py --source demo
python app.py            # http://localhost:8001

# Terminal 3 — Flutter app
cd sapms_app
flutter pub get
flutter run
```

At boot, the Node server logs whether it found the ML service:
```
🤖 ML microservice: connected ✅
```
or
```
🤖 ML microservice: unavailable — using rule-based risk scoring ⚠️
```
Either way, the system works — that's the whole point of the fallback.
