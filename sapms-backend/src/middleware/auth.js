const jwt = require('jsonwebtoken');

// Verify JWT token on every protected route
const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { id, role, school_id, name }
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
};

// Role-based access guard
// Usage: authorize('admin','sysadmin')  or  authorize('teacher')
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role(s): ${roles.join(', ')}`
      });
    }
    next();
  };
};

// School isolation guard — teachers/admins can only see their own school's data
// unless sysadmin
const schoolScope = (req, res, next) => {
  if (req.user.role === 'sysadmin') return next();

  const requestedSchool = req.params.school_id || req.query.school_id;
  if (requestedSchool && requestedSchool !== req.user.school_id) {
    return res.status(403).json({
      success: false,
      message: 'Access denied. You can only access your own school data.'
    });
  }
  next();
};

module.exports = { authenticate, authorize, schoolScope };
