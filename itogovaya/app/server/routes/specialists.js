const router = require('express').Router();
const pool   = require('../db');
const { authMiddleware, requireRole } = require('../middleware/auth');

router.use(authMiddleware);

// GET /api/specialists — список специалистов (US-4)
// ?specialization_id=N&region=...&contract_status=active
router.get('/', async (req, res) => {
  const { specialization_id, region, contract_status } = req.query;
  let where = ['sp.is_active = TRUE'];
  let params = [];
  let i = 1;

  if (specialization_id) {
    where.push(`sp.specialization_id = $${i++}`);
    params.push(specialization_id);
  }
  if (region) {
    where.push(`sp.region ILIKE $${i++}`);
    params.push(`%${region}%`);
  }
  if (contract_status) {
    where.push(`cs.code = $${i++}`);
    params.push(contract_status);
  }

  try {
    const result = await pool.query(
      `SELECT sp.id, sp.first_name, sp.last_name, sp.middle_name,
              sp.phone, sp.email, sp.region, sp.notes,
              s.name  AS specialization,
              cs.code AS contract_code, cs.name AS contract_name
       FROM specialists sp
       JOIN specializations s  ON s.id  = sp.specialization_id
       JOIN contract_statuses cs ON cs.id = sp.contract_status_id
       WHERE ${where.join(' AND ')}
       ORDER BY sp.last_name`,
      params
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка при получении специалистов' });
  }
});

// POST /api/specialists — добавить специалиста (US-7, HR)
router.post('/', requireRole('hr'), async (req, res) => {
  const { first_name, last_name, middle_name, specialization_id, region, phone, email, notes } = req.body;
  if (!first_name || !last_name || !specialization_id) {
    return res.status(400).json({ error: 'Заполните: first_name, last_name, specialization_id' });
  }

  try {
    // Статус договора по умолчанию — active
    const csRes = await pool.query(`SELECT id FROM contract_statuses WHERE code = 'active'`);
    const contractStatusId = csRes.rows[0].id;

    const result = await pool.query(
      `INSERT INTO specialists
         (first_name, last_name, middle_name, specialization_id, region, phone, email, notes, contract_status_id, added_by_user_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [first_name, last_name, middle_name, specialization_id, region, phone, email, notes, contractStatusId, req.user.id]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка при добавлении специалиста' });
  }
});

// GET /api/specialists/specializations — справочник специализаций
router.get('/specializations', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM specializations ORDER BY name');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

module.exports = router;
