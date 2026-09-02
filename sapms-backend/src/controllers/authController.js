const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const db       = require('../config/db');

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password required' });
    }

    const [rows] = await db.query(
      `SELECT u.*, s.name AS school_name 
       FROM users u 
       LEFT JOIN schools s ON u.school_id = s.id
       WHERE u.email = ? AND u.is_active = 1`,
      [email]
    );

    if (!rows.length) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    const user = rows[0];
    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // Self-registered accounts can't log in until an admin approves them.
    if (user.approval_status === 'pending') {
      return res.status(403).json({
        success: false,
        message: 'Your account is awaiting admin approval. Please try again later.',
      });
    }
    if (user.approval_status === 'rejected') {
      return res.status(403).json({
        success: false,
        message: 'Your registration was not approved. Contact the school administration.',
      });
    }

    const payload = {
      id:        user.id,
      role:      user.role,
      school_id: user.school_id,
      name:      user.name,
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.json({
      success: true,
      token,
      user: {
        id:          user.id,
        name:        user.name,
        email:       user.email,
        role:        user.role,
        school_id:   user.school_id,
        school_name: user.school_name,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/auth/me
const me = async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT u.id, u.name, u.email, u.phone, u.role, u.school_id, u.created_at,
              s.name AS school_name, s.code AS school_code
       FROM users u
       LEFT JOIN schools s ON u.school_id = s.id
       WHERE u.id = ?`,
      [req.user.id]
    );
    if (!rows.length) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('Me error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PUT /api/auth/change-password
const changePassword = async (req, res) => {
  try {
    const { current_password, new_password } = req.body;
    if (!current_password || !new_password) {
      return res.status(400).json({ success: false, message: 'Both passwords required' });
    }
    if (new_password.length < 8) {
      return res.status(400).json({ success: false, message: 'New password must be at least 8 characters' });
    }

    const [rows] = await db.query('SELECT password FROM users WHERE id = ?', [req.user.id]);
    const match = await bcrypt.compare(current_password, rows[0].password);
    if (!match) {
      return res.status(401).json({ success: false, message: 'Current password incorrect' });
    }

    const hashed = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE users SET password = ? WHERE id = ?', [hashed, req.user.id]);

    res.json({ success: true, message: 'Password updated successfully' });
  } catch (err) {
    console.error('Change password error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/auth/register — self-registration for teachers and parents.
// Students are staff-created; admins are sysadmin-created. Accounts land in
// 'pending' and cannot log in until an admin approves them.
const { v4: uuidv4 } = require('uuid');

const register = async (req, res) => {
  try {
    const { name, email, phone, password, role, school_id, student_code } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({ success: false, message: 'Name, email, password and role are required' });
    }
    if (!['teacher', 'parent'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Only teacher and parent accounts can self-register' });
    }
    if (password.length < 8) {
      return res.status(400).json({ success: false, message: 'Password must be at least 8 characters' });
    }

    let schoolId = school_id || null;
    let pendingCode = null;

    if (role === 'parent') {
      // A parent must name their child; we verify the code exists but do NOT
      // link parent_id yet — that happens only when an admin approves.
      if (!student_code) {
        return res.status(400).json({ success: false, message: "Your child's student code is required" });
      }
      const [students] = await db.query(
        'SELECT id, school_id FROM students WHERE student_code = ? AND is_active = 1',
        [student_code]
      );
      if (!students.length) {
        return res.status(404).json({ success: false, message: 'Student code not found. Check with the school.' });
      }
      schoolId = students[0].school_id;
      pendingCode = student_code;
    } else if (!schoolId) {
      return res.status(400).json({ success: false, message: 'Please select your school' });
    }

    const [existing] = await db.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length) {
      return res.status(409).json({ success: false, message: 'An account with this email already exists' });
    }

    const hash = await bcrypt.hash(password, 10);
    await db.query(
      `INSERT INTO users (id, school_id, name, email, phone, password, role, is_active, approval_status, pending_student_code)
       VALUES (?,?,?,?,?,?,?,1,'pending',?)`,
      [uuidv4(), schoolId, name, email, phone || null, hash, role, pendingCode]
    );

    res.status(201).json({
      success: true,
      message: 'Registration received. You can log in once the school admin approves your account.',
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/auth/pending — admins see pending registrations for THEIR school.
// school_id comes from the JWT, never from request params (no privilege escalation).
const pendingUsers = async (req, res) => {
  try {
    const scope = req.user.role === 'sysadmin' ? '' : 'AND u.school_id = ?';
    const params = req.user.role === 'sysadmin' ? [] : [req.user.school_id];

    const [rows] = await db.query(
      `SELECT u.id, u.name, u.email, u.phone, u.role, u.pending_student_code,
              u.created_at, s.name AS school_name,
              st.name AS student_name
       FROM users u
       LEFT JOIN schools s ON s.id = u.school_id
       LEFT JOIN students st ON st.student_code = u.pending_student_code
       WHERE u.approval_status = 'pending' ${scope}
       ORDER BY u.created_at ASC`, params
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error('pendingUsers error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/auth/review/:id  { action: 'approve' | 'reject' }
// Approving a parent is the moment their pending_student_code becomes a real
// parent_id link on the student record.
const reviewUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { action } = req.body;
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ success: false, message: "action must be 'approve' or 'reject'" });
    }

    const scope = req.user.role === 'sysadmin' ? '' : 'AND school_id = ?';
    const params = req.user.role === 'sysadmin' ? [id] : [id, req.user.school_id];

    const [rows] = await db.query(
      `SELECT * FROM users WHERE id = ? AND approval_status = 'pending' ${scope}`, params
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Pending user not found in your school' });
    }
    const user = rows[0];

    if (action === 'approve') {
      await db.query(`UPDATE users SET approval_status='approved' WHERE id = ?`, [id]);
      if (user.role === 'parent' && user.pending_student_code) {
        await db.query(
          `UPDATE students SET parent_id = ? WHERE student_code = ?`,
          [id, user.pending_student_code]
        );
      }
    } else {
      await db.query(`UPDATE users SET approval_status='rejected' WHERE id = ?`, [id]);
    }

    res.json({ success: true, message: action === 'approve' ? 'User approved' : 'User rejected' });
  } catch (err) {
    console.error('reviewUser error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { login, me, changePassword, register, pendingUsers, reviewUser };
