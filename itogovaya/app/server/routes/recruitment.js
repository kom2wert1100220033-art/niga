const router = require('express').Router();
const pool   = require('../db');
const { authMiddleware, requireRole } = require('../middleware/auth');

router.use(authMiddleware);

// GET /api/recruitment — список заявок (US-5,6)
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT rr.id, rr.region, rr.deadline, rr.description, rr.created_at,
              rs.code AS status_code, rs.name AS status_name,
              s.name  AS specialization,
              t.title AS task_title,
              u.first_name || ' ' || u.last_name AS created_by_name,
              h.first_name || ' ' || h.last_name AS handled_by_name
       FROM recruitment_requests rr
       JOIN recruitment_statuses rs ON rs.id = rr.status_id
       JOIN specializations       s  ON s.id  = rr.specialization_id
       JOIN tasks                 t  ON t.id  = rr.task_id
       JOIN users                 u  ON u.id  = rr.created_by_user_id
       LEFT JOIN users            h  ON h.id  = rr.handled_by_user_id
       ORDER BY rr.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка при получении заявок' });
  }
});

// POST /api/recruitment — создать заявку на подбор (US-5)
router.post('/', requireRole('office_manager'), async (req, res) => {
  const { task_id, specialization_id, region, deadline, description } = req.body;
  if (!task_id || !specialization_id) {
    return res.status(400).json({ error: 'Укажите task_id и specialization_id' });
  }

  try {
    const statusRes = await pool.query(`SELECT id FROM recruitment_statuses WHERE code = 'new'`);
    const result = await pool.query(
      `INSERT INTO recruitment_requests
         (task_id, specialization_id, region, deadline, description, status_id, created_by_user_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [task_id, specialization_id, region, deadline, description, statusRes.rows[0].id, req.user.id]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка при создании заявки' });
  }
});

// PATCH /api/recruitment/:id/status — сменить статус заявки (US-6)
router.patch('/:id/status', requireRole('hr'), async (req, res) => {
  const { status_code } = req.body; // in_progress | done
  if (!['in_progress', 'done'].includes(status_code)) {
    return res.status(400).json({ error: 'status_code должен быть in_progress или done' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const rrRes = await client.query('SELECT * FROM recruitment_requests WHERE id = $1', [req.params.id]);
    const rr = rrRes.rows[0];
    if (!rr) return res.status(404).json({ error: 'Заявка не найдена' });

    const newStatus = await client.query(`SELECT id FROM recruitment_statuses WHERE code = $1`, [status_code]);
    await client.query(
      `UPDATE recruitment_requests
       SET status_id = $1, handled_by_user_id = $2, updated_at = NOW()
       WHERE id = $3`,
      [newStatus.rows[0].id, req.user.id, rr.id]
    );
    await client.query(
      `INSERT INTO recruitment_status_history (request_id, old_status_id, new_status_id, changed_by)
       VALUES ($1,$2,$3,$4)`,
      [rr.id, rr.status_id, newStatus.rows[0].id, req.user.id]
    );
    await client.query('COMMIT');
    res.json({ message: `Статус заявки изменён на «${status_code}»` });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Ошибка при обновлении заявки' });
  } finally {
    client.release();
  }
});

module.exports = router;
