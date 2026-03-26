-- ============================================================
--  База данных: Система управления сервисными заданиями
--  СУБД: PostgreSQL
--  Автор: на основе User Story (Сериков Шавхалов)
-- ============================================================

-- ============================================================
--  СПРАВОЧНИКИ
-- ============================================================

-- Роли пользователей системы
CREATE TABLE roles (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL UNIQUE,  -- store_manager | office_manager | hr
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO roles (code, name) VALUES
    ('store_manager',  'Управляющий магазином'),
    ('office_manager', 'Управляющий офисом'),
    ('hr',             'Специалист HR');


-- Специализации специалистов (сантехник, электрик и т.д.)
CREATE TABLE specializations (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Статусы заданий
CREATE TABLE task_statuses (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,  -- new | in_progress | done | closed | cancelled
    name VARCHAR(100) NOT NULL
);

INSERT INTO task_statuses (code, name) VALUES
    ('new',       'Новый'),
    ('in_progress','В работе'),
    ('done',      'Выполнен'),
    ('closed',    'Закрыт'),
    ('cancelled', 'Отменён');


-- Статусы заявок на подбор
CREATE TABLE recruitment_statuses (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,  -- new | in_progress | done
    name VARCHAR(100) NOT NULL
);

INSERT INTO recruitment_statuses (code, name) VALUES
    ('new',        'Новая'),
    ('in_progress','В работе'),
    ('done',       'Исполнена');


-- Статусы договора специалиста
CREATE TABLE contract_statuses (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,  -- active | expired | terminated
    name VARCHAR(100) NOT NULL
);

INSERT INTO contract_statuses (code, name) VALUES
    ('active',     'Действующий'),
    ('expired',    'Истёк'),
    ('terminated', 'Расторгнут');


-- ============================================================
--  ПОЛЬЗОВАТЕЛИ СИСТЕМЫ
-- ============================================================

-- Все пользователи системы (US-1..10: управляющий магазином,
-- управляющий офисом, HR)
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    role_id       INT          NOT NULL REFERENCES roles(id),
    username      VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name    VARCHAR(50),
    last_name     VARCHAR(50),
    phone         VARCHAR(20),
    is_active     BOOLEAN      DEFAULT TRUE,
    created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
--  МАГАЗИНЫ
-- ============================================================

-- Магазины, от которых поступают задания (US-1,2,3,10)
CREATE TABLE stores (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(150) NOT NULL,
    address    TEXT,
    region     VARCHAR(100),                       -- регион для фильтрации
    manager_id INT REFERENCES users(id),           -- текущий управляющий
    is_active  BOOLEAN   DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
--  СПЕЦИАЛИСТЫ (система «Персонал»)
-- ============================================================

-- База специалистов — физлиц (US-4,7)
CREATE TABLE specialists (
    id                   SERIAL PRIMARY KEY,
    first_name           VARCHAR(50)  NOT NULL,
    last_name            VARCHAR(50)  NOT NULL,
    middle_name          VARCHAR(50),
    specialization_id    INT          NOT NULL REFERENCES specializations(id),
    region               VARCHAR(100),             -- регион работы (US-4: фильтр)
    contract_status_id   INT          NOT NULL REFERENCES contract_statuses(id),
    phone                VARCHAR(20),
    email                VARCHAR(100),
    notes                TEXT,
    added_by_user_id     INT REFERENCES users(id), -- HR, добавивший запись (US-7)
    is_active            BOOLEAN      DEFAULT TRUE,
    created_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
--  ЗАДАНИЯ НА СЕРВИСНЫЕ РАБОТЫ
-- ============================================================

-- Задание (US-1..10)
CREATE TABLE tasks (
    id                   SERIAL PRIMARY KEY,
    store_id             INT          NOT NULL REFERENCES stores(id),
    created_by_user_id   INT          NOT NULL REFERENCES users(id), -- управляющий магазином
    status_id            INT          NOT NULL REFERENCES task_statuses(id),

    title                VARCHAR(255) NOT NULL,    -- наименование работ (US-1)
    work_description     TEXT,                     -- состав работ
    executor_wishes      TEXT,                     -- пожелания к исполнителю (US-1)
    start_date           DATE         NOT NULL,    -- дата начала (US-1)
    end_date             DATE         NOT NULL,    -- дата окончания (US-1)

    -- Назначение специалиста (US-4)
    assigned_specialist_id INT REFERENCES specialists(id),
    assigned_by_user_id    INT REFERENCES users(id), -- управляющий офисом (US-4)
    assigned_at            TIMESTAMP,

    -- Служебные поля
    sent_to_office_at    TIMESTAMP,               -- когда отправлено (US-2)
    closed_at            TIMESTAMP,               -- когда закрыто (US-8)
    cancelled_at         TIMESTAMP,               -- когда отменено (US-9)
    is_editable          BOOLEAN      DEFAULT TRUE, -- US-8: после закрытия FALSE

    created_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- История изменений статусов задания (для аудита и архива US-10)
CREATE TABLE task_status_history (
    id            SERIAL PRIMARY KEY,
    task_id       INT       NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    old_status_id INT       REFERENCES task_statuses(id),
    new_status_id INT       NOT NULL REFERENCES task_statuses(id),
    changed_by    INT       REFERENCES users(id),
    changed_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comment       TEXT
);


-- ============================================================
--  ЗАЯВКИ НА ПОДБОР
-- ============================================================

-- Заявка HR на подбор нового специалиста (US-5,6)
CREATE TABLE recruitment_requests (
    id                    SERIAL PRIMARY KEY,
    task_id               INT          NOT NULL REFERENCES tasks(id),
    specialization_id     INT          NOT NULL REFERENCES specializations(id),
    region                VARCHAR(100),
    deadline              DATE,                        -- срок поиска (US-6)
    description           TEXT,                        -- дополнительные требования
    status_id             INT          NOT NULL REFERENCES recruitment_statuses(id),

    created_by_user_id    INT          NOT NULL REFERENCES users(id), -- офис-менеджер (US-5)
    handled_by_user_id    INT          REFERENCES users(id),          -- HR (US-6)

    created_at            TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- История изменений статусов заявок на подбор
CREATE TABLE recruitment_status_history (
    id             SERIAL PRIMARY KEY,
    request_id     INT       NOT NULL REFERENCES recruitment_requests(id) ON DELETE CASCADE,
    old_status_id  INT       REFERENCES recruitment_statuses(id),
    new_status_id  INT       NOT NULL REFERENCES recruitment_statuses(id),
    changed_by     INT       REFERENCES users(id),
    changed_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
--  ИНДЕКСЫ
-- ============================================================

-- Быстрый поиск заданий по статусу и магазину (US-3, фильтрация)
CREATE INDEX idx_tasks_status    ON tasks(status_id);
CREATE INDEX idx_tasks_store     ON tasks(store_id);
CREATE INDEX idx_tasks_dates     ON tasks(start_date, end_date);
CREATE INDEX idx_tasks_created   ON tasks(created_by_user_id);

-- Быстрый поиск специалистов (US-4: специализация, регион, статус договора)
CREATE INDEX idx_spec_specialization ON specialists(specialization_id);
CREATE INDEX idx_spec_region         ON specialists(region);
CREATE INDEX idx_spec_contract       ON specialists(contract_status_id);

-- Заявки на подбор по статусу (US-6)
CREATE INDEX idx_recruit_status ON recruitment_requests(status_id);
CREATE INDEX idx_recruit_task   ON recruitment_requests(task_id);


-- ============================================================
--  ОГРАНИЧЕНИЯ БИЗНЕС-ЛОГИКИ (CHECK)
-- ============================================================

-- Дата окончания не раньше даты начала (US-1)
ALTER TABLE tasks
    ADD CONSTRAINT chk_task_dates CHECK (end_date >= start_date);

-- Закрытое задание нельзя редактировать — контролируется приложением
-- через поле is_editable; здесь фиксируем: если статус closed/cancelled,
-- assigned_specialist может быть заполнен или NULL
-- (дополнительные ограничения — на уровне приложения)
