// ═══════════════════════════════════════════════════════════
//  Клиентское приложение: Система сервисных заданий
//  Использует: fetch, DOM API, localStorage
// ═══════════════════════════════════════════════════════════

const API = '/api';

// ─── localStorage: токен и пользователь ─────────────────
function saveAuth(token, user) {
  localStorage.setItem('token', token);
  localStorage.setItem('user', JSON.stringify(user));
}
function getToken()   { return localStorage.getItem('token'); }
function getUser()    { const u = localStorage.getItem('user'); return u ? JSON.parse(u) : null; }
function clearAuth()  { localStorage.removeItem('token'); localStorage.removeItem('user'); }

// ─── fetch-обёртка с JWT-заголовком ─────────────────────
async function api(path, options = {}) {
  const token = getToken();
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const response = await fetch(API + path, { ...options, headers });
  if (response.status === 401) { logout(); return; }
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'Ошибка запроса');
  return data;
}

// ─── Вспомогательные DOM-функции ────────────────────────
function el(id)         { return document.getElementById(id); }
function show(id)        { el(id).classList.remove('hidden'); }
function hide(id)        { el(id).classList.add('hidden'); }
function setHtml(id, h)  { el(id).innerHTML = h; }

function statusBadge(code, name) {
  return `<span class="badge badge-${code}">${name}</span>`;
}
function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('ru-RU');
}

// ─── Модальное окно ──────────────────────────────────────
function openModal(html) {
  setHtml('modal-body', html);
  show('modal-overlay');
}
function closeModal() {
  hide('modal-overlay');
  setHtml('modal-body', '');
}
el('modal-close').addEventListener('click', closeModal);
el('modal-overlay').addEventListener('click', e => { if (e.target === el('modal-overlay')) closeModal(); });

// ─── Toast-уведомления ──────────────────────────────────
function toast(msg, type = 'success') {
  const t = document.createElement('div');
  t.className = type === 'error' ? 'error-msg' : 'success-msg';
  t.style.cssText = 'position:fixed;bottom:20px;right:20px;z-index:200;max-width:340px';
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 3500);
}

// ═══════════════════════════════════════════════════════════
//  АУТЕНТИФИКАЦИЯ
// ═══════════════════════════════════════════════════════════
el('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const loginBtn = el('login-btn');
  const errBox   = el('login-error');
  errBox.classList.add('hidden');
  loginBtn.disabled = true;
  loginBtn.textContent = 'Входим...';

  try {
    const data = await api('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        username: el('username').value.trim(),
        password: el('password').value,
      }),
    });
    saveAuth(data.token, data.user);
    showDashboard();
  } catch (err) {
    errBox.textContent = err.message;
    errBox.classList.remove('hidden');
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = 'Войти';
  }
});

function logout() {
  clearAuth();
  hide('dashboard-screen');
  show('login-screen');
  el('username').value = '';
  el('password').value = '';
}
el('logout-btn').addEventListener('click', logout);

// ═══════════════════════════════════════════════════════════
//  ДАШБОРД
// ═══════════════════════════════════════════════════════════
function showDashboard() {
  const user = getUser();
  if (!user) { show('login-screen'); return; }
  hide('login-screen');
  show('dashboard-screen');

  el('user-info').textContent = `${user.firstName} ${user.lastName} · ${user.roleName}`;
  buildSidebar(user.roleCode);
}

function buildSidebar(role) {
  const nav = el('sidebar');
  const menus = {
    store_manager: [
      { label: '📋 Мои задания',   fn: 'loadMyTasks' },
      { label: '➕ Новое задание', fn: 'showCreateTask' },
    ],
    office_manager: [
      { label: '📋 Задания в работе',  fn: 'loadOfficeTasks' },
      { label: '👷 Специалисты',       fn: 'loadSpecialists' },
      { label: '📦 Архив заданий',     fn: 'loadArchive' },
    ],
    hr: [
      { label: '🔍 Заявки на подбор',  fn: 'loadRecruitment' },
      { label: '➕ Добавить специалиста', fn: 'showAddSpecialist' },
    ],
  };

  const items = menus[role] || [];
  nav.innerHTML = items.map(m =>
    `<div class="nav-item" data-fn="${m.fn}">${m.label}</div>`
  ).join('');

  nav.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      nav.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
      item.classList.add('active');
      window[item.dataset.fn]?.();
    });
  });
}

// ─── Рендер «Загрузка...» ───────────────────────────────
function loading() { setHtml('main-content', '<div class="spinner">Загрузка...</div>'); }

// ═══════════════════════════════════════════════════════════
//  УПРАВЛЯЮЩИЙ МАГАЗИНОМ
// ═══════════════════════════════════════════════════════════

// Список своих заданий
async function loadMyTasks() {
  loading();
  try {
    const tasks = await api('/tasks');
    const html = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
        <h2>Мои задания</h2>
        <button class="btn btn-primary" onclick="showCreateTask()">+ Создать задание</button>
      </div>
      ${tasks.length === 0 ? '<p class="hint">Заданий пока нет</p>' : `
      <div class="card" style="padding:0;overflow:hidden">
        <table>
          <thead><tr>
            <th>Наименование</th><th>Магазин</th><th>Сроки</th><th>Статус</th><th>Действия</th>
          </tr></thead>
          <tbody>
            ${tasks.map(t => `
              <tr>
                <td><strong>${t.title}</strong></td>
                <td>${t.store_name}</td>
                <td>${formatDate(t.start_date)} – ${formatDate(t.end_date)}</td>
                <td>${statusBadge(t.status_code, t.status_name)}</td>
                <td style="display:flex;gap:6px;flex-wrap:wrap">
                  ${t.status_code === 'new' ? `
                    <button class="btn btn-primary btn-sm" onclick="sendTask(${t.id})">Отправить</button>
                    <button class="btn btn-danger btn-sm" onclick="cancelTask(${t.id})">Отменить</button>
                  ` : ''}
                  ${t.status_code === 'in_progress' ? `
                    <button class="btn btn-danger btn-sm" onclick="cancelTask(${t.id})">Отменить</button>
                  ` : ''}
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>`}
    `;
    setHtml('main-content', html);
  } catch (err) {
    setHtml('main-content', `<p class="error-msg">${err.message}</p>`);
  }
}

// Форма создания задания
async function showCreateTask() {
  // Загружаем магазины для выпадающего списка
  let storesHtml = '';
  try {
    const me = getUser();
    // Для простоты берём store_id из профиля — либо показываем поле вручную
    storesHtml = `<input type="number" id="f-store" placeholder="ID магазина" required>`;
  } catch {}

  openModal(`
    <h2 style="margin-bottom:16px">Новое задание</h2>
    <div id="task-form-msg"></div>
    <div class="form-group"><label>Наименование работ *<input type="text" id="f-title" required></label></div>
    <div class="form-group"><label>Состав работ<textarea id="f-desc"></textarea></label></div>
    <div class="form-group"><label>Пожелания к исполнителю<textarea id="f-wishes"></textarea></label></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
      <div class="form-group"><label>Дата начала *<input type="date" id="f-start" required></label></div>
      <div class="form-group"><label>Дата окончания *<input type="date" id="f-end" required></label></div>
    </div>
    <div class="form-group"><label>ID магазина *${storesHtml}</label></div>
    <div class="form-actions">
      <button class="btn btn-primary" onclick="submitCreateTask()">Сохранить</button>
      <button class="btn btn-ghost" onclick="closeModal()">Отмена</button>
    </div>
  `);
}

async function submitCreateTask() {
  const msgEl = el('task-form-msg');
  msgEl.innerHTML = '';
  try {
    await api('/tasks', {
      method: 'POST',
      body: JSON.stringify({
        title:            el('f-title').value.trim(),
        work_description: el('f-desc').value.trim(),
        executor_wishes:  el('f-wishes').value.trim(),
        start_date:       el('f-start').value,
        end_date:         el('f-end').value,
        store_id:         Number(el('f-store').value),
      }),
    });
    closeModal();
    toast('Задание создано со статусом «Новый»');
    loadMyTasks();
  } catch (err) {
    msgEl.innerHTML = `<div class="error-msg">${err.message}</div>`;
  }
}

async function sendTask(id) {
  if (!confirm('Отправить задание в офис?')) return;
  try {
    await api(`/tasks/${id}/send`, { method: 'POST' });
    toast('Задание отправлено в офис');
    loadMyTasks();
  } catch (err) { toast(err.message, 'error'); }
}

async function cancelTask(id) {
  if (!confirm('Отменить задание?')) return;
  try {
    await api(`/tasks/${id}/cancel`, { method: 'POST' });
    toast('Задание отменено');
    loadMyTasks();
  } catch (err) { toast(err.message, 'error'); }
}

// ═══════════════════════════════════════════════════════════
//  УПРАВЛЯЮЩИЙ ОФИСОМ
// ═══════════════════════════════════════════════════════════

async function loadOfficeTasks() {
  loading();
  try {
    const tasks = await api('/tasks?status=in_progress');
    const html = `
      <h2>Задания в работе</h2>
      <div class="filters">
        <label>Статус
          <select id="filter-status" onchange="filterOfficeTasks()">
            <option value="">Все</option>
            <option value="in_progress" selected>В работе</option>
            <option value="done">Выполнен</option>
            <option value="closed">Закрыт</option>
            <option value="cancelled">Отменён</option>
          </select>
        </label>
      </div>
      <div id="office-task-list">${renderOfficeTable(tasks)}</div>
    `;
    setHtml('main-content', html);
  } catch (err) {
    setHtml('main-content', `<p class="error-msg">${err.message}</p>`);
  }
}

async function filterOfficeTasks() {
  const status = el('filter-status').value;
  try {
    const tasks = await api(`/tasks${status ? '?status=' + status : ''}`);
    setHtml('office-task-list', renderOfficeTable(tasks));
  } catch (err) { toast(err.message, 'error'); }
}

function renderOfficeTable(tasks) {
  if (!tasks.length) return '<p class="hint">Нет заданий по выбранному фильтру</p>';
  return `
    <div class="card" style="padding:0;overflow:hidden">
      <table>
        <thead><tr>
          <th>Задание</th><th>Магазин</th><th>Сроки</th><th>Статус</th><th>Специалист</th><th>Действия</th>
        </tr></thead>
        <tbody>
          ${tasks.map(t => `
            <tr>
              <td><strong>${t.title}</strong><br><small style="color:#6b7280">${t.executor_wishes || ''}</small></td>
              <td>${t.store_name}</td>
              <td>${formatDate(t.start_date)}<br>${formatDate(t.end_date)}</td>
              <td>${statusBadge(t.status_code, t.status_name)}</td>
              <td>${t.specialist_name || '—'}</td>
              <td style="display:flex;gap:6px;flex-wrap:wrap">
                ${t.status_code === 'in_progress' ? `
                  <button class="btn btn-success btn-sm" onclick="showAssign(${t.id})">Назначить</button>
                  <button class="btn btn-primary btn-sm" onclick="showCreateRecruitment(${t.id})">Заявка</button>
                ` : ''}
                ${t.status_code === 'done' ? `
                  <button class="btn btn-primary btn-sm" onclick="closeTask(${t.id})">Закрыть</button>
                ` : ''}
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
  `;
}

// Форма назначения специалиста (US-4)
async function showAssign(taskId) {
  let specsHtml = '<p>Загрузка...</p>';
  try {
    const specs = await api('/specialists?contract_status=active');
    specsHtml = specs.length === 0
      ? '<p class="hint">Подходящих специалистов не найдено.</p>'
      : `<div class="filters">
           <label>Специализация<select id="spec-filter-spec" onchange="filterSpecsInModal(${taskId})">
             <option value="">Все</option>
           </select></label>
           <label>Регион<input type="text" id="spec-filter-region" placeholder="Введите регион"
                   oninput="filterSpecsInModal(${taskId})"></label>
         </div>
         <div id="spec-list-modal">
           ${renderSpecTable(specs, taskId)}
         </div>`;
  } catch (err) { specsHtml = `<p class="error-msg">${err.message}</p>`; }

  openModal(`<h2 style="margin-bottom:14px">Назначить специалиста</h2>${specsHtml}`);

  // Заполним фильтр специализаций
  try {
    const sp = await api('/specialists/specializations');
    const sel = el('spec-filter-spec');
    if (sel) sp.forEach(s => {
      const o = document.createElement('option');
      o.value = s.id; o.textContent = s.name; sel.appendChild(o);
    });
  } catch {}
}

async function filterSpecsInModal(taskId) {
  const specId = el('spec-filter-spec')?.value || '';
  const region = el('spec-filter-region')?.value || '';
  let url = '/specialists?contract_status=active';
  if (specId) url += `&specialization_id=${specId}`;
  if (region) url += `&region=${encodeURIComponent(region)}`;
  try {
    const specs = await api(url);
    setHtml('spec-list-modal', renderSpecTable(specs, taskId));
  } catch (err) { toast(err.message, 'error'); }
}

function renderSpecTable(specs, taskId) {
  if (!specs.length) return '<p class="hint">Нет специалистов по фильтру.</p>';
  return `<table>
    <thead><tr><th>Имя</th><th>Специализация</th><th>Регион</th><th></th></tr></thead>
    <tbody>
      ${specs.map(s => `
        <tr>
          <td>${s.last_name} ${s.first_name}</td>
          <td>${s.specialization}</td>
          <td>${s.region || '—'}</td>
          <td><button class="btn btn-success btn-sm" onclick="assignSpecialist(${taskId},${s.id})">Назначить</button></td>
        </tr>
      `).join('')}
    </tbody>
  </table>`;
}

async function assignSpecialist(taskId, specialistId) {
  try {
    await api(`/tasks/${taskId}/assign`, {
      method: 'POST',
      body: JSON.stringify({ specialist_id: specialistId }),
    });
    closeModal();
    toast('Специалист назначен');
    loadOfficeTasks();
  } catch (err) { toast(err.message, 'error'); }
}

async function closeTask(id) {
  if (!confirm('Закрыть задание? Это действие необратимо.')) return;
  try {
    await api(`/tasks/${id}/close`, { method: 'POST' });
    toast('Задание закрыто');
    loadOfficeTasks();
  } catch (err) { toast(err.message, 'error'); }
}

// Форма заявки на подбор (US-5)
async function showCreateRecruitment(taskId) {
  let specsOptions = '';
  try {
    const sp = await api('/specialists/specializations');
    specsOptions = sp.map(s => `<option value="${s.id}">${s.name}</option>`).join('');
  } catch {}

  openModal(`
    <h2 style="margin-bottom:14px">Заявка на подбор специалиста</h2>
    <div id="recruit-msg"></div>
    <div class="form-group"><label>Специализация *
      <select id="r-spec"><option value="">— Выберите —</option>${specsOptions}</select>
    </label></div>
    <div class="form-group"><label>Регион<input type="text" id="r-region"></label></div>
    <div class="form-group"><label>Срок поиска<input type="date" id="r-deadline"></label></div>
    <div class="form-group"><label>Доп. требования<textarea id="r-desc"></textarea></label></div>
    <div class="form-actions">
      <button class="btn btn-primary" onclick="submitRecruitment(${taskId})">Создать заявку</button>
      <button class="btn btn-ghost" onclick="closeModal()">Отмена</button>
    </div>
  `);
}

async function submitRecruitment(taskId) {
  const msgEl = el('recruit-msg');
  try {
    await api('/recruitment', {
      method: 'POST',
      body: JSON.stringify({
        task_id:           taskId,
        specialization_id: Number(el('r-spec').value),
        region:            el('r-region').value.trim(),
        deadline:          el('r-deadline').value || null,
        description:       el('r-desc').value.trim(),
      }),
    });
    closeModal();
    toast('Заявка на подбор создана');
  } catch (err) {
    msgEl.innerHTML = `<div class="error-msg">${err.message}</div>`;
  }
}

// Архив (US-10)
async function loadArchive() {
  loading();
  try {
    const tasks = await api('/tasks?status=closed');
    const html = `
      <h2>Архив заданий</h2>
      <div class="card" style="padding:0;overflow:hidden">
        ${tasks.length === 0 ? '<p class="hint" style="padding:20px">Архив пуст</p>' : `
        <table>
          <thead><tr><th>Задание</th><th>Магазин</th><th>Сроки</th><th>Специалист</th><th>Закрыто</th></tr></thead>
          <tbody>
            ${tasks.map(t => `
              <tr>
                <td><strong>${t.title}</strong></td>
                <td>${t.store_name}</td>
                <td>${formatDate(t.start_date)} – ${formatDate(t.end_date)}</td>
                <td>${t.specialist_name || '—'}</td>
                <td>${formatDate(t.closed_at)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>`}
      </div>
    `;
    setHtml('main-content', html);
  } catch (err) {
    setHtml('main-content', `<p class="error-msg">${err.message}</p>`);
  }
}

// Список специалистов
async function loadSpecialists() {
  loading();
  try {
    const specs = await api('/specialists');
    const html = `
      <h2>База специалистов</h2>
      <div class="card" style="padding:0;overflow:hidden">
        <table>
          <thead><tr><th>ФИО</th><th>Специализация</th><th>Регион</th><th>Договор</th><th>Контакты</th></tr></thead>
          <tbody>
            ${specs.map(s => `
              <tr>
                <td>${s.last_name} ${s.first_name} ${s.middle_name || ''}</td>
                <td>${s.specialization}</td>
                <td>${s.region || '—'}</td>
                <td>${statusBadge(s.contract_code, s.contract_name)}</td>
                <td>${s.phone || ''}<br><small>${s.email || ''}</small></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
    setHtml('main-content', html);
  } catch (err) {
    setHtml('main-content', `<p class="error-msg">${err.message}</p>`);
  }
}

// ═══════════════════════════════════════════════════════════
//  HR
// ═══════════════════════════════════════════════════════════

async function loadRecruitment() {
  loading();
  try {
    const items = await api('/recruitment');
    const html = `
      <h2>Заявки на подбор</h2>
      <div class="card" style="padding:0;overflow:hidden">
        <table>
          <thead><tr><th>Задание</th><th>Специализация</th><th>Регион</th><th>Срок</th><th>Статус</th><th>Действия</th></tr></thead>
          <tbody>
            ${items.map(r => `
              <tr>
                <td>${r.task_title}</td>
                <td>${r.specialization}</td>
                <td>${r.region || '—'}</td>
                <td>${formatDate(r.deadline)}</td>
                <td>${statusBadge(r.status_code, r.status_name)}</td>
                <td style="display:flex;gap:6px">
                  ${r.status_code === 'new' ? `
                    <button class="btn btn-primary btn-sm" onclick="updateRecruitStatus(${r.id},'in_progress')">В работу</button>
                  ` : ''}
                  ${r.status_code === 'in_progress' ? `
                    <button class="btn btn-success btn-sm" onclick="updateRecruitStatus(${r.id},'done')">Исполнена</button>
                  ` : ''}
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
    setHtml('main-content', html);
  } catch (err) {
    setHtml('main-content', `<p class="error-msg">${err.message}</p>`);
  }
}

async function updateRecruitStatus(id, statusCode) {
  try {
    await api(`/recruitment/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status_code: statusCode }),
    });
    toast('Статус заявки обновлён');
    loadRecruitment();
  } catch (err) { toast(err.message, 'error'); }
}

// Форма добавления специалиста (US-7)
async function showAddSpecialist() {
  let specsOptions = '';
  try {
    const sp = await api('/specialists/specializations');
    specsOptions = sp.map(s => `<option value="${s.id}">${s.name}</option>`).join('');
  } catch {}

  openModal(`
    <h2 style="margin-bottom:14px">Добавить специалиста</h2>
    <div id="spec-msg"></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
      <div class="form-group"><label>Фамилия *<input type="text" id="s-last"></label></div>
      <div class="form-group"><label>Имя *<input type="text" id="s-first"></label></div>
    </div>
    <div class="form-group"><label>Отчество<input type="text" id="s-mid"></label></div>
    <div class="form-group"><label>Специализация *
      <select id="s-spec"><option value="">— Выберите —</option>${specsOptions}</select>
    </label></div>
    <div class="form-group"><label>Регион<input type="text" id="s-region"></label></div>
    <div class="form-group"><label>Телефон<input type="tel" id="s-phone"></label></div>
    <div class="form-group"><label>Email<input type="email" id="s-email"></label></div>
    <div class="form-group"><label>Заметки<textarea id="s-notes"></textarea></label></div>
    <div class="form-actions">
      <button class="btn btn-primary" onclick="submitAddSpecialist()">Добавить</button>
      <button class="btn btn-ghost" onclick="closeModal()">Отмена</button>
    </div>
  `);
}

async function submitAddSpecialist() {
  const msgEl = el('spec-msg');
  try {
    await api('/specialists', {
      method: 'POST',
      body: JSON.stringify({
        last_name:         el('s-last').value.trim(),
        first_name:        el('s-first').value.trim(),
        middle_name:       el('s-mid').value.trim(),
        specialization_id: Number(el('s-spec').value),
        region:            el('s-region').value.trim(),
        phone:             el('s-phone').value.trim(),
        email:             el('s-email').value.trim(),
        notes:             el('s-notes').value.trim(),
      }),
    });
    closeModal();
    toast('Специалист добавлен в базу');
  } catch (err) {
    msgEl.innerHTML = `<div class="error-msg">${err.message}</div>`;
  }
}

// ═══════════════════════════════════════════════════════════
//  ИНИЦИАЛИЗАЦИЯ
// ═══════════════════════════════════════════════════════════
(function init() {
  const user = getUser();
  const token = getToken();
  if (user && token) {
    showDashboard();
  } else {
    show('login-screen');
    hide('dashboard-screen');
  }
})();
