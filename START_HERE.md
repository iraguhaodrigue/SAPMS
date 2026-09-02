# SAPMS — Complete Project (Setup & Run Guide)

This is the **full merged project**: your original SAPMS plus all the new
features built on top of it. Everything is in one place, tested together.

## What's inside

```
SAPMS/
├── sapms-backend/          Node.js + Express + MySQL API
│   ├── src/                controllers, routes, services, jobs, middleware
│   ├── ml_service/         Python ML microservice (train + serve)
│   ├── database/           schema.sql, seed.sql, migration_002_*.sql
│   ├── package.json        (updated with new deps)
│   └── .env.example        (copy to .env and fill in)
├── sapms_app/              Flutter mobile app (android/ios/etc included)
│   └── lib/                screens, services, utils, widgets
├── START_HERE.md           ← this file
├── CHANGES_README.md       details on backend features (sync/SMS/ML)
└── KINYARWANDA_GUIDE.md    details on the language feature
```

## Features added on top of your original

1. **Offline-first attendance sync** — scans save locally (SQLite) with no
   signal, auto-upload when connection returns. (§3.7.1)
2. **SMS + push notifications** — absence & risk alerts to parents via
   Africa's Talking (SMS) + Firebase (push). (§3.7.4)
3. **ML predictive risk model** — Python Random Forest predicts at-risk
   students; Node falls back to rule-based if it's offline. (§3.7.5)
4. **Full Kinyarwanda translation** — every screen, EN/RW toggle on login. (§3.7 UI option)

Your original QR attendance, RBAC, dashboards, and marks all still work
unchanged.

---

## SETUP (one time)

### 0. Prerequisites
- Node.js 18+  ·  MySQL 8.0  ·  Flutter SDK  ·  Python 3.11+
- Your `sapms_db` database already configured (you confirmed this).

### 1. Backend
```powershell
cd SAPMS\sapms-backend
npm install
copy .env.example .env      # then open .env and fill in values (see below)
mysql -u root -p sapms_db < database\migration_002_notifications_ml.sql
```

Verify the migration added the new columns:
```powershell
mysql -u root -p sapms_db -e "DESCRIBE users; DESCRIBE student_analytics;"
```
Look for `fcm_token` (users) and `risk_source`, `ml_model_version` (student_analytics).

### 2. ML microservice
```powershell
cd SAPMS\sapms-backend\ml_service
pip install -r requirements.txt
python train_model.py --source demo    # trains on synthetic data to prove the pipeline
```

### 3. Flutter app
```powershell
cd SAPMS\sapms_app
flutter pub get
flutter analyze          # <-- IMPORTANT: run this, see note at bottom
```

---

## .env values

Works out of the box in **dry-run mode** with these blank — SMS/push just
log to console instead of sending, so you can demo without credentials.
Fill them in only when you want real messages:

```
DB_PASSWORD=<your mysql password>
QR_SALT=sapms_salt_2025          # must match whatever generated existing QR codes
AT_API_KEY=                       # Africa's Talking (blank = dry-run SMS)
AT_USERNAME=sandbox
FIREBASE_SERVICE_ACCOUNT_PATH=    # blank = dry-run push
ML_SERVICE_URL=http://localhost:8001
```

---

## RUN (every time) — 3 terminals

```powershell
# Terminal 1 — Backend API
cd SAPMS\sapms-backend
npm run dev
#   → http://localhost:5000
#   → watch for: "🤖 ML microservice: connected ✅"

# Terminal 2 — ML microservice
cd SAPMS\sapms-backend\ml_service
python app.py
#   → http://localhost:8001

# Terminal 3 — Flutter app
cd SAPMS\sapms_app
flutter run
```

Demo accounts (password `Sapms@2025`): admin / teacher / parent — buttons
on the login screen fill them in. Toggle **EN / RW** on login to see the
whole app switch to Kinyarwanda.

---

## What I tested (and what I couldn't)

**Verified working in my environment on this exact merged project:**
- ✅ All 12 backend JS files — valid syntax
- ✅ `npm install` — all dependencies resolve
- ✅ All backend modules load (require chain intact)
- ✅ ML pipeline — trains, serves, predicts (high/low correct)
- ✅ **Node ↔ ML integration** — backend client connects & gets predictions
- ✅ All 17 Flutter files — brace balance, no const/interpolation errors
- ✅ Every import resolves; pubspec + package.json have all new deps
- ✅ api_service has every method the new code calls

**Could NOT verify (environment limits):**
- ❌ `flutter analyze` — the Dart SDK host is blocked in my sandbox. The
  Flutter code is checked by hand but **not compiler-verified**. Please
  run `flutter analyze` yourself and send me any errors — if something
  surfaces it'll most likely be a stray `const`, a quick fix.
- ❌ Live MySQL run — no database in my sandbox (you have yours configured).
- ❌ Real SMS/push delivery — needs your Africa's Talking / Firebase creds.

See `CHANGES_README.md` and `KINYARWANDA_GUIDE.md` for feature-level detail.
