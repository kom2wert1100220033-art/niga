const router = require('express').Router();
const pool   = require('../db');
const { authMiddleware, requireRole } = require('../middleware/auth');

router.use(authMiddleware);

// Хелпер: записать смену статуса в историю
async function logStatus(client, taskId, oldStatusId, newStatusId, userId) {
  await client.query(
    `INSERT INTO task_status_history (task_id, old_status_id, new_status_id, changed_by)
     VALUES ($1, $2, $3, $4)`,
    [taskId, oldStatusId, newStatusId, userId]
  );
}

// ───────────────────────────────────────────────────────────
// GET /api/tasks — список заданий
//   ?status=new|in_progress|done|closed|cancelled
//   ?store_id=N
// ───────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const { status, store_id } = req.query;
  const { id: userId, role_code } = req.user;

  let where = [];
  let params = [];
  let i = 1;

  // Управляющий магазином видит только свои задания
  if (role_code === 'store_manager') {
    where.push(`t.created_by_user_id = $${i++}`);
    params.push(userId);
  }

  if (status) {
    where.push(`ts.code = $${i++}`);
    params.push(status);
  }
  if (store_id) {
    where.push(`t.store_id = $${i++}`);
    params.push(store_id);
  }

  const sql = `
    SELECT t.id, t.title, t.start_date, t.end_date, t.executor_wishes,
           t.work_description, t.is_editable, t.created_at, t.sent_to_office_at,
           ts.code  AS status_code,  ts.name  AS status_name,
           s.name   AS store_name,   s.region AS store_region,
           u.first_name || ' ' || u.last_name AS created_by_name,
           sp.first_name || ' ' || sp.last_name AS specialist_name
    FROM tasks t
    JOIN task_statuses ts ON ts.id = t.status_id
    JOIN stores         s  ON s.id  = t.store_id
    JOIN users          u  ON u.id  = t.created_by_user_id
    LEFT JOIN specialists sp ON sp.id = t.assigned_specialist_id
    ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
    ORDER BY t.created_at DESC
  `;

  try {
    const result = await pool.query(sql, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка при получении заданий' });
  }
});

// ───────────────────────────────────────────────────────────
// GET /api/tasks/:id — одно задание
// ───────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.*, ts.code AS status_code, ts.name AS status_name,
              s.name AS store_name,
              u.first_name || ' ' || u.last_name AS created_by_name,
              sp.first_name || ' ' || sp.last_name AS specialist_name
       FROM tasks t
       JOIN task_statuses ts ON ts.id = t.status_id
       JOIN stores         s  ON s.id  = t.store_id
       JOIN users          u  ON u.id  = t.created_by_user_id
       LEFT JOIN specialists sp ON sp.id = t.assigned_specialist_id
       WHERE t.id = $1`,
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Задание не найдено' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка при получении задания' });
  }
});

// ───────────────────────────────────────────────────────────
// POST /api/tasks — создать задание (US-1)
// ───────────────────────────────────────────────────────────
router.post('/', requireRole('store_manager'), async (req, res) => {
  const { title, work_description, executor_wishes, start_date, end_date, store_id } = req.body;
  if (!title || !start_date || !end_date || !store_id) {
    return res.status(400).json({ error: 'Заполните обязательные поля: title, start_date, end_date, store_id' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const statusRes = await client.query(`SELECT id FROM task_statuses WHERE code = 'new'`);
    const statusId = statusRes.rows[0].id;

    const result = await client.query(
      `INSERT INTO tasks
         (store_id, created_by_user_id, status_id, title, work_description, executor_wishes, start_date, end_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [store_id, req.user.id, statusId, title, work_description, executor_wishes, start_date, end_date]
    );
    const task = result.rows[0];
    await logStatus(client, task.id, null, statusId, req.user.id);
    await client.query('COMMIT');
    res.status(201).json(task);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Ошибка при создании задания' });
  } finally {
    client.release();
  }
});

// ───────────────────────────────────────────────────────────
// POST /api/tasks/:id/send — отправить в офис (US-2)
// ───────────────────────────────────────────────────────────
router.post('/:id/send', requireRole('store_manager'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const taskRes = await client.query('SELECT * FROM tasks WHERE id = $1', [req.params.id]);
    const task = taskRes.rows[0];
    if (!task) return res.status(404).json({ error: 'Задание не найдено' });

    const oldStatus = await client.query(`SELECT id,code FROM task_statuses WHERE id = $1`, [task.status_id]);
    if (oldStatus.rows[0].code !== 'new') {
      return res.status(400).json({ error: 'Можно отправить только задание в статусе «новый»' });
    }

    const newStatusRes = await client.query(`SELECT id FROM task_statuses WHERE code = 'in_progress'`);
    const newStatusId = newStatusRes.rows[0].id;

    await client.query(
      `UPDATE tasks SET status_id = $1, sent_to_office_at = NOW(), updated_at = NOW() WHERE id = $2`,
      [newStatusId, task.id]
    );
    await logStatus(client, task.id, task.status_id, newStatusId, req.user.id);
    await client.query('COMMIT');
    res.json({ message: 'Задание отправлено в офис' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Ошибка при отправке задания' });
  } finally {
    client.release();
  }
});

// ───────────────────────────────────────────────────────────
// POST /api/tasks/:id/assign — назначить специалиста (US-4)
// ───────────────────────────────────────────────────────────
router.post('/:id/assign', requireRole('office_manager'), async (req, res) => {
  const { specialist_id } = req.body;
  if (!specialist_id) return res.status(400).json({ error: 'Укажите specialist_id' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const taskRes = await client.query('SELECT * FROM tasks WHERE id = $1', [req.params.id]);
    const task = taskRes.rows[0];
    if (!task) return res.status(404).json({ error: 'Задание не найдено' });

    const curStatus = await client.query(`SELECT code FROM task_statuses WHERE id = $1`, [task.status_id]);
    if (curStatus.rows[0].code !== 'in_progress') {
      return res.status(400).json({ error: 'Назначить специалиста можно только для задания «в работе»' });
    }

    const doneStatus = await client.query(`SELECT id FROM task_statuses WHERE code = 'done'`);
    const doneId = doneStatus.rows[0].id;

    await client.query(
      `UPDATE tasks
       SET assigned_specialist_id = $1, assigned_by_user_id = $2,
           assigned_at = NOW(), status_id = $3, updated_at = NOW()
       WHERE id = $4`,
      [specialist_id, req.user.id, doneId, task.id]
    );
    await logStatus(client, task.id, task.status_id, doneId, req.user.id);
    await client.query('COMMIT');
    res.json({ message: 'Специалист назначен, задание переведено в статус «выполнен»' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Ошибка при назначении специалиста' });
  } finally {
    client.release();
  }
});

// ───────────────────────────────────────────────────────────
// POST /api/tasks/:id/close — закрыть задание (US-8)
// ───────────────────────────────────────────────────────────
router.post('/:id/close', requireRole('office_manager'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const taskRes = await client.query('SELECT * FROM tasks WHERE id = $1', [req.params.id]);
    const task = taskRes.rows[0];
    if (!task) return res.status(404).json({ error: 'Задание не найдено' });

    const curStatus = await client.query(`SELECT code FROM task_statuses WHERE id = $1`, [task.status_id]);
    if (curStatus.rows[0].code !== 'done') {
      return res.status(400).json({ error: 'Закрыть можно только задание в статусе «выполнен»' });
    }

    const closedStatus = await client.query(`SELECT id FROM task_statuses WHERE code = 'closed'`);
    await client.query(
      `UPDATE tasks SET status_id = $1, closed_at = NOW(), is_editable = FALSE, updated_at = NOW() WHERE id = $2`,
      [closedStatus.rows[0].id, task.id]
    );
    await logStatus(client, task.id, task.status_id, closedStatus.rows[0].id, req.user.id);
    await client.query('COMMIT');
    res.json({ message: 'Задание закрыто' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Ошибка при закрытии задания' });
  } finally {
    client.release();
  }
});

// ───────────────────────────────────────────────────────────
// POST /api/tasks/:id/cancel — отменить задание (US-9)
// ───────────────────────────────────────────────────────────
router.post('/:id/cancel', requireRole('store_manager'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const taskRes = await client.query('SELECT * FROM tasks WHERE id = $1', [req.params.id]);
    const task = taskRes.rows[0];
    if (!task) return res.status(404).json({ error: 'Задание не найдено' });

    const curStatus = await client.query(`SELECT code FROM task_statuses WHERE id = $1`, [task.status_id]);
    if (!['new', 'in_progress'].includes(curStatus.rows[0].code)) {
      return res.status(400).json({ error: 'Отменить можно только задание в статусе «новый» или «в работе»' });
    }

    const cancelStatus = await client.query(`SELECT id FROM task_statuses WHERE code = 'cancelled'`);
    await client.query(
      `UPDATE tasks SET status_id = $1, cancelled_at = NOW(), updated_at = NOW() WHERE id = $2`,
      [cancelStatus.rows[0].id, task.id]
    );
    await logStatus(client, task.id, task.status_id, cancelStatus.rows[0].id, req.user.id);
    await client.query('COMMIT');
    res.json({ message: 'Задание отменено' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Ошибка при отмене задания' });
  } finally {
    client.release();
  }
});

module.exports = router;
