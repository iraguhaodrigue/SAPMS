const db     = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const QRCode = require('qrcode');

// Generate QR hash for a student
const generateQRHash = (studentCode) => {
  const salt = process.env.QR_SALT || 'sapms_salt_2025';
  return crypto.createHash('sha256').update(`${studentCode}:${salt}`).digest('hex');
};

// GET /api/students?class_id=&school_id=
const getStudents = async (req, res) => {
  try {
    const { class_id, school_id, search } = req.query;

    // Scope to user's school unless sysadmin
    const effectiveSchool = req.user.role === 'sysadmin' ? school_id : req.user.school_id;

    let query = `
      SELECT s.id, s.student_code, s.name, s.gender, s.date_of_birth, s.is_active,
             c.name AS class_name, c.level,
             sch.name AS school_name, sch.code AS school_code,
             u.name AS parent_name, u.phone AS parent_phone,
             a.risk_level, a.attendance_rate, a.gpa
      FROM students s
      JOIN classes c ON s.class_id = c.id
      JOIN schools sch ON s.school_id = sch.id
      LEFT JOIN users u ON s.parent_id = u.id
      LEFT JOIN student_analytics a ON s.id = a.student_id
      WHERE s.is_active = 1
    `;
    const params = [];

    if (effectiveSchool) { query += ' AND s.school_id = ?'; params.push(effectiveSchool); }
    if (class_id)        { query += ' AND s.class_id = ?'; params.push(class_id); }
    if (search)          { query += ' AND s.name LIKE ?';  params.push(`%${search}%`); }

    // Parents can only see their own children
    if (req.user.role === 'parent') {
      query += ' AND s.parent_id = ?';
      params.push(req.user.id);
    }

    query += ' ORDER BY s.name ASC';

    const [rows] = await db.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('Get students error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/students/:id
const getStudent = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT s.*, c.name AS class_name, c.level, sch.name AS school_name,
             u.name AS parent_name, u.phone AS parent_phone, u.email AS parent_email,
             a.risk_level, a.attendance_rate, a.gpa, a.performance_trend,
             a.absenteeism_flag, a.subject_weakness_count, a.risk_score, a.last_calculated
      FROM students s
      JOIN classes c ON s.class_id = c.id
      JOIN schools sch ON s.school_id = sch.id
      LEFT JOIN users u ON s.parent_id = u.id
      LEFT JOIN student_analytics a ON s.id = a.student_id
      WHERE s.id = ? AND s.is_active = 1
    `, [req.params.id]);

    if (!rows.length) return res.status(404).json({ success: false, message: 'Student not found' });

    // Parent can only see their child
    const student = rows[0];
    if (req.user.role === 'parent' && student.parent_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    res.json({ success: true, data: student });
  } catch (err) {
    console.error('Get student error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/students
const createStudent = async (req, res) => {
  try {
    const { class_id, name, gender, date_of_birth, parent_id } = req.body;
    if (!class_id || !name || !gender) {
      return res.status(400).json({ success: false, message: 'class_id, name, gender required' });
    }

    // Get school from class
    const [classRows] = await db.query(
      'SELECT school_id FROM classes WHERE id = ?', [class_id]
    );
    if (!classRows.length) return res.status(404).json({ success: false, message: 'Class not found' });
    const school_id = classRows[0].school_id;

    // School isolation: a (non-sysadmin) admin may only add students to a
    // class in their OWN school. Prevents creating records across schools.
    if (req.user.role === 'admin' && school_id !== req.user.school_id) {
      return res.status(403).json({ success: false, message: 'Class not found in your school' });
    }

    // Generate student code: SCH_CODE-YEAR-SEQ
    const [schoolRows] = await db.query('SELECT code FROM schools WHERE id = ?', [school_id]);
    const schoolCode = schoolRows[0].code.replace('-', '');
    const year = new Date().getFullYear();
    const [countRows] = await db.query(
      'SELECT COUNT(*) AS cnt FROM students WHERE school_id = ?', [school_id]
    );
    const seq = String(countRows[0].cnt + 1).padStart(3, '0');
    const student_code = `${schoolCode}-${year}-${seq}`;

    const id = uuidv4();
    const qr_code_hash = generateQRHash(student_code);

    await db.query(
      `INSERT INTO students (id, school_id, class_id, student_code, name, gender, date_of_birth, parent_id, qr_code_hash)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, school_id, class_id, student_code, name, gender, date_of_birth || null, parent_id || null, qr_code_hash]
    );

    // Initialize analytics row
    await db.query(
      `INSERT INTO student_analytics (id, student_id) VALUES (?, ?)`,
      [uuidv4(), id]
    );

    res.status(201).json({
      success: true,
      message: 'Student created',
      data: { id, student_code, qr_code_hash }
    });
  } catch (err) {
    console.error('Create student error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/students/:id/qr  — returns QR code as PNG base64
const getStudentQR = async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT student_code, name, qr_code_hash FROM students WHERE id = ?',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ success: false, message: 'Student not found' });

    const { student_code, name, qr_code_hash } = rows[0];

    // QR encodes: "SAPMS:{student_code}:{qr_hash}"
    const qrData = `SAPMS:${student_code}:${qr_code_hash}`;
    const qrImage = await QRCode.toDataURL(qrData, {
      errorCorrectionLevel: 'H',
      width: 300,
      margin: 2,
    });

    res.json({
      success: true,
      data: {
        student_code,
        name,
        qr_data: qrData,
        qr_image: qrImage, // base64 PNG — Flutter can display directly
      }
    });
  } catch (err) {
    console.error('Get QR error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/classes  — list classes in the requesting admin's school
// (sysadmin may pass ?school_id= to list any school's classes)
const getClasses = async (req, res) => {
  try {
    const school_id = req.user.role === 'sysadmin'
      ? (req.query.school_id || null)
      : req.user.school_id;
    const [rows] = await db.query(
      `SELECT c.id, c.name, c.level, c.school_id, s.name AS school_name,
              (SELECT COUNT(*) FROM students st WHERE st.class_id = c.id AND st.is_active = 1) AS student_count
         FROM classes c
         JOIN schools s ON s.id = c.school_id
        WHERE (? IS NULL OR c.school_id = ?)
        ORDER BY c.level, c.name`,
      [school_id, school_id]
    );
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getClasses error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getStudents, getStudent, createStudent, getStudentQR, getClasses };
