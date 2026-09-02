# Step 1: Biometric Auth Patch — Apply & Test Guide

## What's in this patch (9 files)

Flutter app:
- `sapms_app/pubspec.yaml` — added `local_auth` dependency
- `sapms_app/android/app/build.gradle.kts` — minSdk bumped to 23 (required by local_auth)
- `sapms_app/android/app/src/main/AndroidManifest.xml` — added USE_BIOMETRIC permission
- `sapms_app/android/app/src/main/kotlin/.../MainActivity.kt` — changed to FlutterFragmentActivity (required by local_auth's dialog)
- `sapms_app/lib/services/biometric_service.dart` — NEW file, wraps local_auth
- `sapms_app/lib/screens/teacher/take_attendance_screen.dart` — fingerprint required before "Start" opens a session
- `sapms_app/lib/services/api_service.dart` — passes biometric timestamp to backend

Backend:
- `sapms-backend/src/controllers/attendanceController.js` — stores biometric_verified_at
- `sapms-backend/database/migration_003_biometric.sql` — NEW column on attendance_sessions

## How it works

The fingerprint check happens **once per session**, when the teacher taps
"Start" to open attendance for a class period — not once per student scan
(that would be unusable). If the fingerprint check fails or is cancelled,
no session is created and no attendance can be recorded. A green
"Teacher verified" badge shows on screen once it succeeds.

## How to apply

Copy each file from this patch into the same relative path inside your
existing `abraham/` project, overwriting the originals. Example (PowerShell,
from inside this patch folder):

```powershell
Copy-Item -Path "sapms_app\*" -Destination "..\sapms_app" -Recurse -Force
Copy-Item -Path "sapms-backend\*" -Destination "..\sapms-backend" -Recurse -Force
```

Adjust the destination paths to wherever your actual project lives.

## Apply the database migration

```powershell
cd SAPMS\sapms-backend
mysql -u root -p sapms_db < database\migration_003_biometric.sql
```

Verify it landed:
```powershell
mysql -u root -p sapms_db -e "DESCRIBE attendance_sessions;"
```
You should see a new `biometric_verified_at` column (TIMESTAMP, nullable).

## Test plan — run in this exact order

### 1. Dependency check
```powershell
cd sapms_app
flutter pub get
```
Confirm no version conflicts. If it fails, paste me the error.

### 2. Run on your PHYSICAL Android device
Emulators generally can't simulate a real fingerprint reliably.
```powershell
flutter devices
flutter run -d <your_device_id>
```

### 3. Standalone sanity check (before touching the real flow)
Before trusting the wired-in flow, confirm the OS dialog itself works.
Temporarily add this anywhere reachable (e.g. a debug print in `initState`
of any screen, or a throwaway button), then remove it once confirmed:

```dart
import 'services/biometric_service.dart'; // adjust path

final result = await BiometricService.instance.authenticate(
  reason: 'Test fingerprint check',
);
print('Biometric test result: ${result.success} — ${result.message}');
```

Run it and confirm:
- The Android fingerprint dialog actually appears
- A real successful scan prints `true — Verified`
- Cancelling the dialog prints `false — ...`

If this step fails, nothing downstream will work — fix it here first.

### 4. Full flow test
Log in as a teacher → go to **Take Attendance** → tap **Start**.
- The fingerprint dialog should appear immediately (before any session is created)
- On success: session opens, green "Teacher verified" badge shows, QR scanning becomes available
- Check the database: `SELECT id, teacher_id, biometric_verified_at FROM attendance_sessions ORDER BY created_at DESC LIMIT 1;` — the timestamp should be populated

### 5. Failure path test
Tap **Start** again (new session) and cancel the fingerprint prompt, or
deliberately fail it (wrong finger a few times until it errors).
- Confirm: NO session is created
- Confirm: you see a red snackbar with the specific reason (not a generic error)
- Confirm: the "Start" button is still there, ready to retry

## If the device has no fingerprint enrolled

`BiometricService.isBiometricAvailable()` returns false and you'll see:
*"No fingerprint/biometric enrolled on this device..."*
Enroll one in Android Settings → Security → Fingerprint, then retry.

## Report back with

1. Output of `flutter pub get`
2. Whether the standalone test (`Step 3`) dialog appeared and matched a real finger
3. Whether the full flow (`Step 4`) created a session with a populated `biometric_verified_at`
4. Any error text, verbatim
