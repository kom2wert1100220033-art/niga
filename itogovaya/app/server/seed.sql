-- ============================================================
--  Тестовые данные для системы (запускать после db_schema.sql)
-- ============================================================

-- Специализации
INSERT INTO specializations (name) VALUES
  ('Сантехник'), ('Электрик'), ('Плиточник'),
  ('Маляр'), ('Кровельщик'), ('Сварщик');

-- Магазины
INSERT INTO stores (name, address, region) VALUES
  ('Магазин №1 — Центр', 'ул. Ленина, 1', 'Москва'),
  ('Магазин №2 — Север', 'ул. Победы, 45', 'Москва'),
  ('Магазин №3 — Самара', 'пр. Кирова, 10', 'Самара');

-- Пользователи (пароль для всех: Password123!)
-- Хеши сгенерированы через bcrypt (10 rounds)
INSERT INTO users (role_id, username, email, password_hash, first_name, last_name) VALUES
  -- Управляющий магазином
  (
    (SELECT id FROM roles WHERE code = 'store_manager'),
    'manager1', 'manager1@example.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    'Иван', 'Петров'
  ),
  -- Управляющий офисом
  (
    (SELECT id FROM roles WHERE code = 'office_manager'),
    'office1', 'office1@example.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    'Анна', 'Смирнова'
  ),
  -- HR
  (
    (SELECT id FROM roles WHERE code = 'hr'),
    'hr1', 'hr1@example.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    'Олег', 'Васильев'
  );

-- Привязываем управляющего к магазину №1
UPDATE stores SET manager_id = (SELECT id FROM users WHERE username = 'manager1')
WHERE name = 'Магазин №1 — Центр';

-- Специалисты
INSERT INTO specialists
  (first_name, last_name, specialization_id, region, phone, contract_status_id, added_by_user_id)
VALUES
  ('Дмитрий', 'Козлов',
   (SELECT id FROM specializations WHERE name = 'Электрик'),
   'Москва', '+7 900 111-22-33',
   (SELECT id FROM contract_statuses WHERE code = 'active'),
   (SELECT id FROM users WHERE username = 'hr1')),
  ('Сергей', 'Никитин',
   (SELECT id FROM specializations WHERE name = 'Сантехник'),
   'Москва', '+7 900 444-55-66',
   (SELECT id FROM contract_statuses WHERE code = 'active'),
   (SELECT id FROM users WHERE username = 'hr1')),
  ('Алексей', 'Фёдоров',
   (SELECT id FROM specializations WHERE name = 'Маляр'),
   'Самара', '+7 900 777-88-99',
   (SELECT id FROM contract_statuses WHERE code = 'active'),
   (SELECT id FROM users WHERE username = 'hr1'));

-- Тестовое задание (статус «новый»)
INSERT INTO tasks
  (store_id, created_by_user_id, status_id, title, executor_wishes, start_date, end_date)
VALUES
  (
    (SELECT id FROM stores WHERE name = 'Магазин №1 — Центр'),
    (SELECT id FROM users WHERE username = 'manager1'),
    (SELECT id FROM task_statuses WHERE code = 'new'),
    'Замена электропроводки в подсобном помещении',
    'Опыт работы в магазинах, наличие допуска по электробезопасности',
    CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days'
  );
