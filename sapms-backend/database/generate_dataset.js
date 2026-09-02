#!/usr/bin/env node
/* ─────────────────────────────────────────────────────────────────────
 * SAPMS-Secure — Synthetic Dataset Generator
 *
 * Populates the database with a realistic term of school operations for
 * two REAL secondary schools in Nyamasheke District, Western Province:
 *
 *   • Groupe Scolaire Frank Adamson Kibogora (GSFAK) — Gatare Sector,
 *     government-aided, general secondary (O-Level S1–S3, A-Level
 *     combinations MCB / PCB / PCM / MEG).
 *   • Kivu Hills Academy (KHA) — Buhongo, private, TVET institution
 *     (Building Construction, Networking & IT, Tourism).
 *
 * The school names, sectors, types and programme structures are real,
 * publicly documented information. Everything about INDIVIDUALS —
 * students, parents, teachers, names, marks, attendance — is synthetic.
 * No real person's data is used.
 *
 * The generator also injects a controlled proportion of LABELLED
 * anomalies (recorded in `anomaly_ground_truth`) so that the anomaly
 * detection model can later be scored honestly against known truth,
 * rather than against assumed figures.
 *
 * Usage:
 *   node database/generate_dataset.js            # generate
 *   node database/generate_dataset.js --wipe     # clear generated data first
 * ───────────────────────────────────────────────────────────────────── */

const db       = require('../src/config/db');
const bcrypt   = require('bcryptjs');
const crypto   = require('crypto');
const { v4: uuid } = require('uuid');

// ── Scale configuration ──────────────────────────────────────────────
const CONFIG = {
  weeks:                11,    // length of the simulated term
  studentsPerClass:     40,    // typical Rwandan secondary class size
  sessionsPerSubjectWk: 2,     // how often each subject meets per week
  baseAttendanceRate:   0.88,  // ~88% average attendance
  anomalyRate:          0.04,  // ~4% of sessions carry an injected anomaly
  assessmentsPerSubject: 3,    // CAT 1, CAT 2, End of Term
  batchSize:            1000,  // rows per bulk INSERT
};

const DEMO_PASSWORD = 'Sapms@2025';

// ── Synthetic Rwandan name pools ─────────────────────────────────────
const FAMILY = ['Uwimana','Mukamana','Niyonzima','Habimana','Nshimiyimana','Uwase',
  'Iradukunda','Ishimwe','Mugisha','Byiringiro','Nkurunziza','Hakizimana','Munyaneza',
  'Tuyishime','Uwera','Mutesi','Keza','Gasana','Rwema','Manzi','Shema','Kwizera',
  'Ineza','Cyusa','Karake','Gatete','Bizimana','Nsengimana','Ndayisaba','Umutoni',
  'Umuhoza','Uwineza','Murekatete','Dusabimana','Ntwari','Rukundo','Teta','Gisa',
  'Kalisa','Mahoro','Sibomana','Twagirayezu','Nizeyimana','Musoni','Ndagijimana',
  'Uwitonze','Mukashema','Nyiranzeyimana','Harerimana','Byukusenge'];

const GIVEN_M = ['Jean','Emmanuel','Eric','Patrick','Olivier','Fabrice','Yves','Innocent',
  'Theoneste','Kevin','Samuel','Daniel','Pascal','Felix','Alexis','Christian','Elie',
  'Moise','Thierry','Aime','Placide','Gilbert','Josue','Fidele','Anaclet'];

const GIVEN_F = ['Marie','Claudine','Diane','Alice','Josiane','Aline','Sandrine','Chantal',
  'Vestine','Immaculee','Divine','Grace','Esther','Aimee','Solange','Consolee','Beatrice',
  'Nadine','Jeanne','Clarisse','Liliane','Yvonne','Peace','Ange','Furaha'];

// ── Real school definitions ──────────────────────────────────────────
const SCHOOLS = [
  {
    code: 'NS-GSFAK',
    name: 'Groupe Scolaire Frank Adamson Kibogora',
    zone: 'lakeshore',            // near Lake Kivu / Kibogora
    sector: 'Gatare',
    type: 'government-aided',
    solar_power: 0,
    network_quality: 'intermittent',
    classes: [
      { name: 'S1-A', level: 'S1', track: 'olevel' },
      { name: 'S2-A', level: 'S2', track: 'olevel' },
      { name: 'S3-A', level: 'S3', track: 'olevel' },
      { name: 'S4-MCB', level: 'S4', track: 'MCB' },
      { name: 'S5-PCB', level: 'S5', track: 'PCB' },
      { name: 'S5-PCM', level: 'S5', track: 'PCM' },
      { name: 'S6-MEG', level: 'S6', track: 'MEG' },
    ],
  },
  {
    code: 'NS-KHA',
    name: 'Kivu Hills Academy',
    zone: 'highland',             // Buhongo hills
    sector: 'Buhongo',
    type: 'private',
    solar_power: 1,
    network_quality: 'poor',
    classes: [
      { name: 'L3-NIT', level: 'S4', track: 'TVET_NIT' },
      { name: 'L4-NIT', level: 'S5', track: 'TVET_NIT' },
      { name: 'L4-BLD', level: 'S5', track: 'TVET_BLD' },
      { name: 'L5-TRM', level: 'S6', track: 'TVET_TRM' },
    ],
  },
];

// Subjects per track. O-Level follows the Rwandan common core; A-Level
// follows the combination; TVET follows the trade modules.
const TRACK_SUBJECTS = {
  olevel:   ['Mathematics','English','Kinyarwanda','Biology','Physics','Chemistry','History','Geography'],
  MCB:      ['Mathematics','Chemistry','Biology','General Studies','English'],
  PCB:      ['Physics','Chemistry','Biology','General Studies','English'],
  PCM:      ['Physics','Chemistry','Mathematics','General Studies','English'],
  MEG:      ['Mathematics','Economics','Geography','General Studies','English'],
  TVET_NIT: ['Computer Networking','Hardware Maintenance','Internet of Things','Computer Science','English'],
  TVET_BLD: ['Masonry','Structural Engineering','Architectural Drawing','Site Safety','English'],
  TVET_TRM: ['Tour Guiding','Hospitality Operations','Eco-Tourism','Customer Service','English'],
};

// ── Helpers ──────────────────────────────────────────────────────────
const rnd    = (n) => Math.floor(Math.random() * n);
const pick   = (a) => a[rnd(a.length)];
const chance = (p) => Math.random() < p;
const pad    = (n, w = 3) => String(n).padStart(w, '0');

function gaussian(mean, sd) {
  // Box–Muller — gives realistically bell-shaped marks instead of uniform noise
  const u = 1 - Math.random(), v = Math.random();
  return mean + sd * Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

function fmtDate(d)     { return d.toISOString().slice(0, 10); }
function fmtDateTime(d) { return d.toISOString().slice(0, 19).replace('T', ' '); }

// School days only (Mon–Fri)
function* schoolDays(start, weeks) {
  const d = new Date(start);
  for (let i = 0; i < weeks * 7; i++) {
    const day = d.getDay();
    if (day !== 0 && day !== 6) yield new Date(d);
    d.setDate(d.getDate() + 1);
  }
}

// Insert rows in batches so large volumes don't blow up a single query
async function bulkInsert(table, columns, rows) {
  if (!rows.length) return;
  const colSql = columns.join(',');
  const placeholders = '(' + columns.map(() => '?').join(',') + ')';
  for (let i = 0; i < rows.length; i += CONFIG.batchSize) {
    const chunk = rows.slice(i, i + CONFIG.batchSize);
    const sql = `INSERT INTO ${table} (${colSql}) VALUES ${chunk.map(() => placeholders).join(',')}`;
    await db.query(sql, chunk.flat());
  }
}

const anomalyLabels = [];
function labelAnomaly(entityType, entityId, type, description) {
  anomalyLabels.push([uuid(), entityType, entityId, type, description]);
}

// ── Wipe (optional) ──────────────────────────────────────────────────
async function wipe() {
  console.log('⚠️  Wiping existing data…');
  await db.query('SET FOREIGN_KEY_CHECKS = 0');
  const tables = ['anomaly_ground_truth','marks','assessments','attendance_records',
    'attendance_sessions','student_analytics','notifications','class_subjects',
    'students','classes','subjects','users','terms','academic_years','schools'];
  for (const t of tables) {
    await db.query(`DELETE FROM ${t}`).catch(() => {});
  }
  await db.query('SET FOREIGN_KEY_CHECKS = 1');
  console.log('   done.\n');
}

// ── Main generation ──────────────────────────────────────────────────
async function generate() {
  const t0 = Date.now();
  const pwHash = await bcrypt.hash(DEMO_PASSWORD, 10);

  // 1. Academic year + terms ------------------------------------------------
  const yearId = uuid();
  await db.query(
    'INSERT INTO academic_years (id, year_label, is_current) VALUES (?,?,1)',
    [yearId, '2025-2026']
  );

  // Term 1 is the one we simulate in full.
  const termStart = new Date('2026-01-12');           // Monday
  const termEnd   = new Date(termStart);
  termEnd.setDate(termEnd.getDate() + CONFIG.weeks * 7);

  const termId = uuid();
  await db.query(
    `INSERT INTO terms (id, academic_year_id, term_number, start_date, end_date, is_current)
     VALUES (?,?,?,?,?,1)`,
    [termId, yearId, 1, fmtDate(termStart), fmtDate(termEnd)]
  );
  console.log(`📅 Term 1: ${fmtDate(termStart)} → ${fmtDate(termEnd)} (${CONFIG.weeks} weeks)`);

  // 2. Subjects (deduped across all tracks, per level) ----------------------
  const subjectId = {};            // key `${name}|${level}` -> id
  const subjectRows = [];
  const levelsUsed = new Set();
  for (const s of SCHOOLS) for (const c of s.classes) levelsUsed.add(c.level);

  const allSubjectNames = new Set(Object.values(TRACK_SUBJECTS).flat());
  let subjSeq = 0;
  for (const level of levelsUsed) {
    for (const name of allSubjectNames) {
      const id = uuid();
      const code = `${name.replace(/[^A-Za-z]/g, '').slice(0, 6).toUpperCase()}-${level}-${pad(++subjSeq)}`;
      subjectId[`${name}|${level}`] = id;
      subjectRows.push([id, code, name, level]);
    }
  }
  await bulkInsert('subjects', ['id','code','name','level'], subjectRows);
  console.log(`📚 Subjects: ${subjectRows.length}`);

  // 3. Schools, teachers, admins, classes, students -------------------------
  const schoolRows = [], userRows = [], classRows = [],
        studentRows = [], classSubjectRows = [];

  const classes = [];      // { id, schoolId, name, level, track, students: [] }
  const teachers = [];     // { id, schoolId }

  let teacherSeq = 0, studentSeq = 0, parentSeq = 0;

  for (const school of SCHOOLS) {
    const schoolId = uuid();
    schoolRows.push([schoolId, school.code, school.name, school.zone,
                     school.sector, school.type, school.solar_power, school.network_quality]);

    // One admin per school
    const adminId = uuid();
    userRows.push([adminId, schoolId, `${pick(GIVEN_M)} ${pick(FAMILY)}`,
      `admin.${school.code.toLowerCase()}@sapms.rw`, `+2507880${pad(++teacherSeq, 5)}`,
      pwHash, 'admin']);

    // Teachers — enough to cover the subject load
    const teacherPool = [];
    const teacherCount = school.classes.length * 2;
    for (let i = 0; i < teacherCount; i++) {
      const id = uuid();
      const male = chance(0.55);
      const name = `${male ? pick(GIVEN_M) : pick(GIVEN_F)} ${pick(FAMILY)}`;
      userRows.push([id, schoolId, name,
        `teacher${++teacherSeq}.${school.code.toLowerCase()}@sapms.rw`,
        `+2507881${pad(teacherSeq, 5)}`, pwHash, 'teacher']);
      teacherPool.push(id);
      teachers.push({ id, schoolId });
    }

    // Classes + students
    for (const cls of school.classes) {
      const classId = uuid();
      classRows.push([classId, schoolId, cls.name, cls.level, yearId]);

      const students = [];
      for (let i = 0; i < CONFIG.studentsPerClass; i++) {
        const male = chance(0.5);
        const name = `${male ? pick(GIVEN_M) : pick(GIVEN_F)} ${pick(FAMILY)}`;
        const studentId = uuid();
        const code = `${school.code.split('-')[1]}${pad(++studentSeq, 4)}`;

        // Each student gets a parent account
        const parentId = uuid();
        userRows.push([parentId, schoolId, `${chance(0.5) ? pick(GIVEN_M) : pick(GIVEN_F)} ${pick(FAMILY)}`,
          `parent${++parentSeq}@sapms.rw`, `+2507882${pad(parentSeq, 5)}`, pwHash, 'parent']);

        // QR payload mirrors the scanner format: SAPMS:studentCode:hash
        const QR_SALT = process.env.QR_SALT || 'sapms_salt_2025';
          const qrHash = crypto
            .createHash('sha256')
            .update(`${code}:${QR_SALT}`)
            .digest('hex');

        // Age appropriate to level (S1 ≈ 13 … S6 ≈ 18)
        const levelNum = parseInt(cls.level.slice(1), 10);
        const birthYear = 2026 - (12 + levelNum);
        const dob = `${birthYear}-${pad(1 + rnd(12), 2)}-${pad(1 + rnd(28), 2)}`;

        studentRows.push([studentId, schoolId, classId, code, name,
          male ? 'M' : 'F', dob, parentId, qrHash]);

        // Per-student attendance propensity — most reliable, a few chronic
        const propensity = chance(0.12)
          ? clamp(gaussian(0.62, 0.08), 0.35, 0.78)   // at-risk students
          : clamp(gaussian(0.93, 0.05), 0.75, 0.99);  // typical students

        students.push({ id: studentId, propensity });
      }

      // Subject → teacher assignment for this class
      const subjects = TRACK_SUBJECTS[cls.track];
      const subjAssign = [];
      for (const subjName of subjects) {
        const sid = subjectId[`${subjName}|${cls.level}`];
        const tid = pick(teacherPool);
        classSubjectRows.push([uuid(), classId, sid, tid, termId]);
        subjAssign.push({ subjectId: sid, teacherId: tid, name: subjName });
      }

      classes.push({ id: classId, schoolId, ...cls, students, subjects: subjAssign });
    }
  }

  await bulkInsert('schools',
    ['id','code','name','zone','sector','type','solar_power','network_quality'], schoolRows);
  await bulkInsert('users',
    ['id','school_id','name','email','phone','password','role'], userRows);
  await bulkInsert('classes',
    ['id','school_id','name','level','academic_year_id'], classRows);
  await bulkInsert('students',
    ['id','school_id','class_id','student_code','name','gender','date_of_birth','parent_id','qr_code_hash'],
    studentRows);
  await bulkInsert('class_subjects',
    ['id','class_id','subject_id','teacher_id','term_id'], classSubjectRows);

  console.log(`🏫 Schools: ${schoolRows.length}  |  Classes: ${classRows.length}`);
  console.log(`👨‍🏫 Users: ${userRows.length} (teachers, admins, parents)`);
  console.log(`🎓 Students: ${studentRows.length}`);

  // 4. Attendance sessions + records ---------------------------------------
  const days = [...schoolDays(termStart, CONFIG.weeks)];
  const sessionRows = [], recordRows = [];

  for (const cls of classes) {
    for (const subj of cls.subjects) {
      // Pick which weekdays this subject meets on
      const meetDays = [];
      while (meetDays.length < CONFIG.sessionsPerSubjectWk) {
        const d = 1 + rnd(5);                       // Mon..Fri
        if (!meetDays.includes(d)) meetDays.push(d);
      }

      for (const day of days) {
        if (!meetDays.includes(day.getDay())) continue;

        const sessionId = uuid();
        const period = 1 + rnd(8);

        // Session start time: period 1 ≈ 08:00, each period ~45 min
        const start = new Date(day);
        start.setUTCHours(8, 0, 0, 0);
        start.setUTCMinutes(start.getUTCMinutes() + (period - 1) * 45);

        // ── Anomaly injection decisions for this session ──
        let noBiometric = false, oddHours = false, bulkMarking = false, duplicateScan = false;
        if (chance(CONFIG.anomalyRate)) {
          const kind = pick(['no_biometric','odd_hours','bulk_marking','duplicate_scan']);
          if (kind === 'no_biometric')  noBiometric  = true;
          if (kind === 'odd_hours')     oddHours     = true;
          if (kind === 'bulk_marking')  bulkMarking  = true;
          if (kind === 'duplicate_scan') duplicateScan = true;
        }

        if (oddHours) {
          start.setUTCHours(2 + rnd(3), rnd(60), 0, 0);   // 02:00–04:59, well outside school hours
          labelAnomaly('attendance_session', sessionId, 'odd_hours',
            'Session opened outside normal school hours');
        }

        // Biometric verification stamp — normally present, absent when injected
        const bioAt = noBiometric ? null : fmtDateTime(new Date(start.getTime() - 60_000));
        if (noBiometric) {
          labelAnomaly('attendance_session', sessionId, 'no_biometric',
            'Session opened without biometric verification');
        }
        if (bulkMarking) {
          labelAnomaly('attendance_session', sessionId, 'bulk_marking',
            'All students scanned within a few seconds');
        }
        // NOTE: duplicate_scan is labelled on the RECORD below, not here —
        // the anomalous entity is the individual scan timestamp, and
        // labelling both would double-count it during evaluation.

        sessionRows.push([sessionId, cls.id, subj.subjectId, subj.teacherId, termId,
          fmtDate(day), period, 1, 1, bioAt]);

        // ── Attendance records ──
        let offsetSec = 0;
        for (const st of cls.students) {
          const present = chance(st.propensity * CONFIG.baseAttendanceRate / 0.88);
          let status = 'absent', scannedAt = null;

          if (present) {
            status = chance(0.07) ? 'late' : 'present';
            // Normal scanning trickles in over several minutes;
            // bulk marking compresses everyone into a few seconds.
            offsetSec += bulkMarking ? 1 : 5 + rnd(25);
            const sa = new Date(start.getTime() + offsetSec * 1000);
            scannedAt = fmtDateTime(sa);
          }

          recordRows.push([uuid(), sessionId, st.id, status, scannedAt]);
        }

        // For a duplicate-scan anomaly we cannot add a second row for the same
        // student (uq_session_student), so we model it the way it actually
        // appears in practice: an implausibly early re-scan timestamp on a
        // present student, i.e. two scans collapsed into one record.
        if (duplicateScan) {
          const idx = recordRows.length - cls.students.length + rnd(cls.students.length);
          if (recordRows[idx] && recordRows[idx][4]) {
            const impossible = new Date(start.getTime() - 3 * 3600 * 1000); // 3h before the session
            recordRows[idx][4] = fmtDateTime(impossible);
            labelAnomaly('attendance_record', recordRows[idx][0], 'duplicate_scan',
              'Scan timestamp precedes session start by hours');
          }
        }
      }
    }
  }

  await bulkInsert('attendance_sessions',
    ['id','class_id','subject_id','teacher_id','term_id','session_date','period_number',
     'is_closed','synced','biometric_verified_at'], sessionRows);
  await bulkInsert('attendance_records',
    ['id','session_id','student_id','status','scanned_at'], recordRows);

  console.log(`🗓️  Attendance sessions: ${sessionRows.length}`);
  console.log(`✅ Attendance records: ${recordRows.length}`);

  // 5. Assessments + marks --------------------------------------------------
  const assessmentRows = [], markRows = [];
  const names = ['CAT 1','CAT 2','End of Term'];
  const types = ['continuous','continuous','endterm'];

  for (const cls of classes) {
    for (const subj of cls.subjects) {
      // Each teacher has their own marking tendency — some mark generously,
      // some strictly. This is the baseline that grade-inflation must stand out from.
      const teacherMean = clamp(gaussian(62, 6), 48, 76);

      for (let a = 0; a < CONFIG.assessmentsPerSubject; a++) {
        const assessmentId = uuid();
        const dayIdx = Math.floor(((a + 1) / (CONFIG.assessmentsPerSubject + 1)) * days.length);
        const aDate = days[Math.min(dayIdx, days.length - 1)];

        assessmentRows.push([assessmentId, cls.id, subj.subjectId, subj.teacherId, termId,
          types[a], names[a], 100, fmtDate(aDate)]);

        // Inflated assessment: the whole class suddenly scores far above
        // this teacher's own norm — the pattern a committee would call fraud.
        const inflated = chance(CONFIG.anomalyRate);
        if (inflated) {
          labelAnomaly('assessment', assessmentId, 'grade_inflation',
            'Class mean far above the teacher\'s historical average');
        }

        for (const st of cls.students) {
          const absent = chance(0.04);
          if (absent) {
            markRows.push([uuid(), assessmentId, st.id, null, 1]);
            continue;
          }
          // Ability correlates loosely with attendance propensity
          const ability = (st.propensity - 0.85) * 40;
          const base = inflated ? teacherMean + 28 : teacherMean;
          const score = clamp(gaussian(base + ability, 11), 0, 100);
          markRows.push([uuid(), assessmentId, st.id, score.toFixed(2), 0]);
        }
      }
    }
  }

  await bulkInsert('assessments',
    ['id','class_id','subject_id','teacher_id','term_id','assessment_type',
     'assessment_name','max_score','assessment_date'], assessmentRows);
  await bulkInsert('marks',
    ['id','assessment_id','student_id','score','is_absent'], markRows);

  console.log(`📝 Assessments: ${assessmentRows.length}  |  Marks: ${markRows.length}`);

  // 6. Anomaly ground-truth labels -----------------------------------------
  await bulkInsert('anomaly_ground_truth',
    ['id','entity_type','entity_id','anomaly_type','description'], anomalyLabels);

  const byType = anomalyLabels.reduce((acc, r) => {
    acc[r[3]] = (acc[r[3]] || 0) + 1; return acc;
  }, {});
  console.log(`\n🔍 Injected anomalies: ${anomalyLabels.length}`);
  for (const [k, v] of Object.entries(byType)) console.log(`     ${k}: ${v}`);

  console.log(`\n⏱️  Completed in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  console.log(`🔑 All demo accounts use password: ${DEMO_PASSWORD}`);
}

(async () => {
  try {
    if (process.argv.includes('--wipe')) await wipe();
    await generate();
    process.exit(0);
  } catch (err) {
    console.error('\n❌ Generation failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
})();
