const jwt = require('jsonwebtoken');

// Проверяет наличие и валидность JWT-токена
function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Необходима авторизация' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { id, role_code, username }
    next();
  } catch {
    return res.status(401).json({ error: 'Токен недействителен или истёк' });
  }
}

// Проверяет роль пользователя
function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role_code)) {
      return res.status(403).json({ error: 'Доступ запрещён' });
    }
    next();
  };
}

module.exports = { authMiddleware, requireRole };
