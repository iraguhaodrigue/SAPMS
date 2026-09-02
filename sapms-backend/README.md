# SAPMS Backend API
**Student Attendance & Performance Monitoring System**  
University of Kigali | NSHUTIYIMANA Abraham (Reg: 25012215)  
Supervisor: Dr. MUSABE Jean Bosco

---

## What This Is
A Node.js/Express REST API backend for SAPMS, backed by MySQL.  
This is the server that the Flutter mobile app talks to.

---

## Requirements (install these on your machine first)
- Node.js 18+ → https://nodejs.org
- MySQL 8.0 → https://dev.mysql.com/downloads/
- Git (optional)

---

## Setup — Step by Step

### 1. Install MySQL and create a database user
Open MySQL as root:
```bash
mysql -u root -p
```
Then run:
```sql
CREATE USER 'sapms_user'@'localhost' IDENTIFIED BY 'SapmsDb@2025';
GRANT ALL PRIVILEGES ON sapms_db.* TO 'sapms_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 2. Create the database schema
```bash
mysql -u sapms_user -p < database/schema.sql
```
Enter password: `SapmsDb@2025`

### 3. Load sample/demo data
```bash
mysql -u sapms_user -p < database/seed.sql
```

### 4. Configure environment
```bash
cp .env.example .env
```
Edit `.env` and set at minimum:
```
DB_USER=sapms_user
DB_PASSWORD=SapmsDb@2025
JWT_SECRET=change_this_to_something_random_and_long
```

### 5. Install Node dependencies
```bash
npm install
```

### 6. Start the server
```bash
# Development (auto-restarts on file changes)
npm run dev

# Production
npm start
```

You should see:
```
✅ MySQL connected successfully
🚀 SAPMS API running on http://localhost:5000
```

---

## Demo Accounts (from seed.sql)
All accounts use password: **`Sapms@2025`**

| Role      | Email                          | School        |
|-----------|-------------------------------|---------------|
| sysadmin  | sysadmin@sapms.rw             | All schools   |
| admin     | admin.kagano@sapms.rw         | NS-01 Kagano  |
| admin     | admin.cyato@sapms.rw          | NS-02 Cyato   |
| teacher   | teacher.math@sapms.rw         | NS-01 Kagano  |
| teacher   | teacher.eng@sapms.rw          | NS-01 Kagano  |
| parent    | parent.kamanzi@sapms.rw       | NS-01 Kagano  |

---

## API Endpoints

### Auth
| Method | Endpoint                  | Role     | Description           |
|--------|---------------------------|----------|-----------------------|
| POST   | /api/auth/login           | Public   | Login, get JWT token  |
| GET    | /api/auth/me              | Any      | Get current user info |
| PUT    | /api/auth/change-password | Any      | Change password       |

### Students
| Method | Endpoint                  | Role           | Description              |
|--------|---------------------------|----------------|--------------------------|
| GET    | /api/students             | Any            | List students (filtered) |
| GET    | /api/students/:id         | Any            | Get one student          |
| POST   | /api/students             | admin,sysadmin | Create student + QR hash |
| GET    | /api/students/:id/qr      | Any            | Get QR code as base64    |

### Attendance
| Method | Endpoint                              | Role    | Description                    |
|--------|---------------------------------------|---------|--------------------------------|
| POST   | /api/attendance/sessions              | teacher | Open attendance session        |
| POST   | /api/attendance/scan                  | teacher | Scan QR → mark present         |
| POST   | /api/attendance/sessions/:id/close    | teacher | Close session, notify parents  |
| GET    | /api/attendance/sessions/:id/records  | Any     | Full attendance sheet          |
| GET    | /api/attendance/student/:id           | Any     | Student attendance history     |

### Marks
| Method | Endpoint                                    | Role    | Description              |
|--------|---------------------------------------------|---------|--------------------------|
| POST   | /api/marks/assessments                      | teacher | Create assessment        |
| GET    | /api/marks/assessments                      | Any     | List assessments         |
| GET    | /api/marks/assessments/:id/marks            | Any     | Full class mark sheet    |
| PUT    | /api/marks/:mark_id                         | teacher | Update one student mark  |
| POST   | /api/marks/assessments/:id/bulk             | teacher | Submit whole class marks |
| GET    | /api/marks/student/:id                      | Any     | Student academic report  |

### Analytics
| Method | Endpoint                               | Role           | Description                |
|--------|----------------------------------------|----------------|----------------------------|
| GET    | /api/analytics/dashboard               | admin,teacher  | School-wide overview       |
| GET    | /api/analytics/at-risk                 | admin,teacher  | At-risk students list      |
| GET    | /api/analytics/class/:id/performance   | Any            | Class subject performance  |
| GET    | /api/analytics/notifications           | Any            | Notifications log          |

---

## How Authentication Works (for Flutter)
Every request except `/api/auth/login` needs:
```
Authorization: Bearer <token>
```

**Login flow:**
```json
POST /api/auth/login
{ "email": "teacher.math@sapms.rw", "password": "Sapms@2025" }

Response:
{
  "success": true,
  "token": "eyJhbGci...",
  "user": { "id": "...", "name": "Mugenzi Robert", "role": "teacher", ... }
}
```
Store the token in Flutter's `SharedPreferences` / `flutter_secure_storage`. Send it in every subsequent request header.

---

## QR Code Flow (for Flutter)
1. **Generate:** `GET /api/students/:id/qr` → returns base64 PNG + qr_data string
2. **Print/Show:** Flutter displays the base64 image
3. **Scan:** Flutter uses `mobile_scanner` package to read QR
4. **Submit:** `POST /api/attendance/scan` with `{ session_id, qr_data }`
5. **Server validates** the hash, marks student present

---

## Risk Level Logic (rule-based, no ML yet)
| Condition                                      | Risk Level |
|------------------------------------------------|------------|
| Attendance < 85% AND GPA < 50%                 | 🔴 High    |
| Attendance < 85% OR GPA < 50%                  | 🟡 Moderate|
| Otherwise                                       | 🟢 Low     |

ML model (Random Forest using Python/scikit-learn) will replace this  
once real school data is collected from the 6 pilot schools.

---

## Project Structure
```
sapms-backend/
├── src/
│   ├── config/db.js              # MySQL connection pool
│   ├── middleware/auth.js         # JWT verify + role guards
│   ├── controllers/
│   │   ├── authController.js      # Login, me, change-password
│   │   ├── studentsController.js  # CRUD + QR generation
│   │   ├── attendanceController.js# Sessions, scan, close, analytics
│   │   ├── marksController.js     # Assessments, marks, reports
│   │   └── analyticsController.js # Dashboard, at-risk, performance
│   ├── routes/index.js            # All routes wired
│   └── app.js                     # Express entry point
├── database/
│   ├── schema.sql                 # Full DB schema (run this first)
│   └── seed.sql                   # Demo data (6 schools, 20 students)
├── .env.example                   # Copy to .env
└── README.md                      # This file
```

---

## What's Next (Flutter App)
After this backend is running, the Flutter app needs:
- Auth screen (login form → store JWT)
- Teacher home: open session → scan QRs → close session
- Admin dashboard: pull `/api/analytics/dashboard`
- Parent view: child attendance + marks + risk alert
- Student QR display screen

---

## SMS Notifications
Currently logged to `notifications` table with `status = 'pending'`.  
To enable real SMS via Africa's Talking:
1. Register at https://africastalking.com
2. Add `AT_API_KEY` and `AT_USERNAME` to `.env`
3. A worker/cron job will process pending notifications
