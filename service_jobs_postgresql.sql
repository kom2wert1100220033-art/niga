
-- ============================================
-- База данных для управления сервисными работами
-- СУБД: PostgreSQL
-- Предметная область: задания от магазинов,
-- подбор исполнителей и HR-заявки
-- ============================================

CREATE SCHEMA IF NOT EXISTS service_jobs;
SET search_path TO service_jobs, public;

-- ----------------------------
-- Перечисления
-- ----------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role_enum') THEN
        CREATE TYPE user_role_enum AS ENUM (
            'store_manager',
            'office_manager',
            'hr_specialist'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status_enum') THEN
        CREATE TYPE task_status_enum AS ENUM (
            'new',
            'in_work',
            'completed',
            'closed',
            'cancelled'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contract_status_enum') THEN
        CREATE TYPE contract_status_enum AS ENUM (
            'pending',
            'active',
            'suspended',
            'terminated'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'recruitment_status_enum') THEN
        CREATE TYPE recruitment_status_enum AS ENUM (
            'new',
            'in_work',
            'fulfilled',
            'cancelled'
        );
    END IF;
END $$;

-- ----------------------------
-- Пользователи системы
-- ----------------------------
CREATE TABLE IF NOT EXISTS app_users (
    user_id           BIGSERIAL PRIMARY KEY,
    role_code         user_role_enum NOT NULL,
    login             VARCHAR(50) NOT NULL UNIQUE,
    email             VARCHAR(120) NOT NULL UNIQUE,
    password_hash     VARCHAR(255) NOT NULL,
    first_name        VARCHAR(50) NOT NULL,
    last_name         VARCHAR(50) NOT NULL,
    phone             VARCHAR(20),
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------
-- Регионы
-- ----------------------------
CREATE TABLE IF NOT EXISTS regions (
    region_id         BIGSERIAL PRIMARY KEY,
    region_name       VARCHAR(100) NOT NULL UNIQUE
);

-- ----------------------------
-- Магазины
-- ----------------------------
CREATE TABLE IF NOT EXISTS stores (
    store_id          BIGSERIAL PRIMARY KEY,
    store_name        VARCHAR(150) NOT NULL UNIQUE,
    region_id         BIGINT NOT NULL REFERENCES regions(region_id),
    address           TEXT NOT NULL,
    manager_user_id   BIGINT UNIQUE REFERENCES app_users(user_id),
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------
-- Справочник специализаций
-- ----------------------------
CREATE TABLE IF NOT EXISTS specialties (
    specialty_id      BIGSERIAL PRIMARY KEY,
    specialty_name    VARCHAR(100) NOT NULL UNIQUE,
    description       TEXT
);

-- ----------------------------
-- База специалистов (система "Персонал")
-- ----------------------------
CREATE TABLE IF NOT EXISTS specialists (
    specialist_id       BIGSERIAL PRIMARY KEY,
    last_name           VARCHAR(50) NOT NULL,
    first_name          VARCHAR(50) NOT NULL,
    middle_name         VARCHAR(50),
    phone               VARCHAR(20),
    email               VARCHAR(120) UNIQUE,
    region_id           BIGINT NOT NULL REFERENCES regions(region_id),
    contract_status     contract_status_enum NOT NULL DEFAULT 'pending',
    is_available        BOOLEAN NOT NULL DEFAULT TRUE,
    hire_date           DATE,
    contract_number     VARCHAR(50),
    notes               TEXT,
    created_by_user_id  BIGINT REFERENCES app_users(user_id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Один специалист может иметь несколько специализаций
CREATE TABLE IF NOT EXISTS specialist_specialties (
    specialist_id      BIGINT NOT NULL REFERENCES specialists(specialist_id) ON DELETE CASCADE,
    specialty_id       BIGINT NOT NULL REFERENCES specialties(specialty_id),
    proficiency_level  SMALLINT CHECK (proficiency_level BETWEEN 1 AND 5),
    PRIMARY KEY (specialist_id, specialty_id)
);

-- ----------------------------
-- Задания на сервисные работы
-- ----------------------------
CREATE TABLE IF NOT EXISTS tasks (
    task_id                BIGSERIAL PRIMARY KEY,
    store_id               BIGINT NOT NULL REFERENCES stores(store_id),
    created_by_user_id     BIGINT NOT NULL REFERENCES app_users(user_id),
    title                  VARCHAR(200) NOT NULL,
    description            TEXT,
    date_start             DATE NOT NULL,
    date_end               DATE NOT NULL,
    performer_wishes       TEXT,
    status                 task_status_enum NOT NULL DEFAULT 'new',
    submitted_at           TIMESTAMPTZ,
    assigned_specialist_id BIGINT REFERENCES specialists(specialist_id),
    assigned_by_user_id    BIGINT REFERENCES app_users(user_id),
    assigned_at            TIMESTAMPTZ,
    closed_at              TIMESTAMPTZ,
    cancelled_at           TIMESTAMPTZ,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_task_dates CHECK (date_end >= date_start)
);

-- Состав работ по заданию
CREATE TABLE IF NOT EXISTS task_work_items (
    task_work_item_id    BIGSERIAL PRIMARY KEY,
    task_id              BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    line_no              INTEGER NOT NULL,
    work_name            VARCHAR(200) NOT NULL,
    specialty_id         BIGINT NOT NULL REFERENCES specialties(specialty_id),
    quantity             NUMERIC(10,2) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    comment_text         TEXT,
    CONSTRAINT uq_task_line UNIQUE (task_id, line_no)
);

-- История смены статусов задания
CREATE TABLE IF NOT EXISTS task_status_history (
    history_id           BIGSERIAL PRIMARY KEY,
    task_id              BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    old_status           task_status_enum,
    new_status           task_status_enum NOT NULL,
    changed_by_user_id   BIGINT REFERENCES app_users(user_id),
    change_comment       TEXT,
    changed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------
-- Заявки на подбор персонала
-- ----------------------------
CREATE TABLE IF NOT EXISTS recruitment_requests (
    recruitment_request_id BIGSERIAL PRIMARY KEY,
    task_id                BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
    specialty_id           BIGINT NOT NULL REFERENCES specialties(specialty_id),
    region_id              BIGINT NOT NULL REFERENCES regions(region_id),
    created_by_user_id     BIGINT NOT NULL REFERENCES app_users(user_id),
    hr_user_id             BIGINT REFERENCES app_users(user_id),
    status                 recruitment_status_enum NOT NULL DEFAULT 'new',
    notes                  TEXT,
    needed_from            DATE NOT NULL,
    needed_to              DATE NOT NULL,
    fulfilled_specialist_id BIGINT REFERENCES specialists(specialist_id),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at             TIMESTAMPTZ,
    fulfilled_at           TIMESTAMPTZ,
    CONSTRAINT uq_recruitment_task_spec UNIQUE (task_id, specialty_id),
    CONSTRAINT chk_recruitment_dates CHECK (needed_to >= needed_from)
);

-- История статусов HR-заявки
CREATE TABLE IF NOT EXISTS recruitment_request_status_history (
    history_id              BIGSERIAL PRIMARY KEY,
    recruitment_request_id  BIGINT NOT NULL REFERENCES recruitment_requests(recruitment_request_id) ON DELETE CASCADE,
    old_status              recruitment_status_enum,
    new_status              recruitment_status_enum NOT NULL,
    changed_by_user_id      BIGINT REFERENCES app_users(user_id),
    change_comment          TEXT,
    changed_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------
-- Индексы
-- ----------------------------
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_store_dates ON tasks(store_id, date_start, date_end);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_specialist ON tasks(assigned_specialist_id);
CREATE INDEX IF NOT EXISTS idx_task_work_items_specialty ON task_work_items(specialty_id);
CREATE INDEX IF NOT EXISTS idx_specialists_region_contract ON specialists(region_id, contract_status, is_available);
CREATE INDEX IF NOT EXISTS idx_specialist_specialties_specialty ON specialist_specialties(specialty_id);
CREATE INDEX IF NOT EXISTS idx_recruitment_status_region ON recruitment_requests(status, region_id);
CREATE INDEX IF NOT EXISTS idx_recruitment_task ON recruitment_requests(task_id);

-- ----------------------------
-- Вспомогательные функции
-- ----------------------------

-- Автообновление updated_at
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_app_users_updated_at
BEFORE UPDATE ON app_users
FOR EACH ROW
EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_specialists_updated_at
BEFORE UPDATE ON specialists
FOR EACH ROW
EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_tasks_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_recruitment_updated_at
BEFORE UPDATE ON recruitment_requests
FOR EACH ROW
EXECUTE FUNCTION fn_set_updated_at();

-- Идентификатор текущего пользователя можно передавать из приложения:
-- SET app.current_user_id = '15';
CREATE OR REPLACE FUNCTION fn_current_app_user_id()
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id TEXT;
BEGIN
    v_user_id := current_setting('app.current_user_id', TRUE);

    IF v_user_id IS NULL OR btrim(v_user_id) = '' THEN
        RETURN NULL;
    END IF;

    RETURN v_user_id::BIGINT;
EXCEPTION
    WHEN others THEN
        RETURN NULL;
END;
$$;

-- Проверка жизненного цикла задания
CREATE OR REPLACE FUNCTION fn_validate_task_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- После закрытия или отмены редактирование запрещено
    IF OLD.status IN ('closed', 'cancelled')
       AND (to_jsonb(NEW) - 'updated_at') IS DISTINCT FROM (to_jsonb(OLD) - 'updated_at') THEN
        RAISE EXCEPTION 'Задание в статусе "%" недоступно для редактирования', OLD.status;
    END IF;

    IF NEW.status <> OLD.status THEN
        CASE OLD.status
            WHEN 'new' THEN
                IF NEW.status NOT IN ('in_work', 'cancelled') THEN
                    RAISE EXCEPTION 'Недопустимый переход статуса задания: % -> %', OLD.status, NEW.status;
                END IF;

                IF NEW.status = 'in_work' THEN
                    NEW.submitted_at := COALESCE(NEW.submitted_at, NOW());
                END IF;

                IF NEW.status = 'cancelled' THEN
                    NEW.cancelled_at := COALESCE(NEW.cancelled_at, NOW());
                END IF;

            WHEN 'in_work' THEN
                IF NEW.status NOT IN ('completed', 'cancelled') THEN
                    RAISE EXCEPTION 'Недопустимый переход статуса задания: % -> %', OLD.status, NEW.status;
                END IF;

                IF NEW.status = 'completed' THEN
                    IF NEW.assigned_specialist_id IS NULL THEN
                        RAISE EXCEPTION 'Нельзя перевести задание в "completed" без назначенного специалиста';
                    END IF;

                    NEW.assigned_at := COALESCE(NEW.assigned_at, NOW());
                END IF;

                IF NEW.status = 'cancelled' THEN
                    NEW.cancelled_at := COALESCE(NEW.cancelled_at, NOW());
                END IF;

            WHEN 'completed' THEN
                IF NEW.status <> 'closed' THEN
                    RAISE EXCEPTION 'Из статуса "completed" можно перейти только в "closed"';
                END IF;

                NEW.closed_at := COALESCE(NEW.closed_at, NOW());

            ELSE
                RAISE EXCEPTION 'Переход из статуса "%" запрещён', OLD.status;
        END CASE;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_task_transition
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION fn_validate_task_transition();

-- Логирование истории статусов задания
CREATE OR REPLACE FUNCTION fn_log_task_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO task_status_history(task_id, old_status, new_status, changed_by_user_id)
        VALUES (NEW.task_id, NULL, NEW.status, COALESCE(fn_current_app_user_id(), NEW.created_by_user_id));
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO task_status_history(task_id, old_status, new_status, changed_by_user_id)
        VALUES (NEW.task_id, OLD.status, NEW.status, fn_current_app_user_id());
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_task_status_insert
AFTER INSERT ON tasks
FOR EACH ROW
EXECUTE FUNCTION fn_log_task_status();

CREATE TRIGGER trg_log_task_status_update
AFTER UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION fn_log_task_status();

-- Проверка жизненного цикла HR-заявки
CREATE OR REPLACE FUNCTION fn_validate_recruitment_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status <> OLD.status THEN
        CASE OLD.status
            WHEN 'new' THEN
                IF NEW.status NOT IN ('in_work', 'cancelled') THEN
                    RAISE EXCEPTION 'Недопустимый переход статуса HR-заявки: % -> %', OLD.status, NEW.status;
                END IF;

                IF NEW.status = 'in_work' THEN
                    NEW.started_at := COALESCE(NEW.started_at, NOW());
                END IF;

            WHEN 'in_work' THEN
                IF NEW.status NOT IN ('fulfilled', 'cancelled') THEN
                    RAISE EXCEPTION 'Недопустимый переход статуса HR-заявки: % -> %', OLD.status, NEW.status;
                END IF;

                IF NEW.status = 'fulfilled' THEN
                    IF NEW.fulfilled_specialist_id IS NULL THEN
                        RAISE EXCEPTION 'Нельзя завершить HR-заявку без указанного специалиста';
                    END IF;

                    NEW.fulfilled_at := COALESCE(NEW.fulfilled_at, NOW());
                END IF;

            WHEN 'fulfilled', 'cancelled' THEN
                RAISE EXCEPTION 'HR-заявка в статусе "%" больше не изменяется', OLD.status;

            ELSE
                RAISE EXCEPTION 'Переход из статуса "%" запрещён', OLD.status;
        END CASE;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_recruitment_transition
BEFORE UPDATE ON recruitment_requests
FOR EACH ROW
EXECUTE FUNCTION fn_validate_recruitment_transition();

-- Логирование истории статусов HR-заявки
CREATE OR REPLACE FUNCTION fn_log_recruitment_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO recruitment_request_status_history(
            recruitment_request_id, old_status, new_status, changed_by_user_id
        )
        VALUES (
            NEW.recruitment_request_id, NULL, NEW.status,
            COALESCE(fn_current_app_user_id(), NEW.created_by_user_id)
        );
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO recruitment_request_status_history(
            recruitment_request_id, old_status, new_status, changed_by_user_id
        )
        VALUES (
            NEW.recruitment_request_id, OLD.status, NEW.status, fn_current_app_user_id()
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_recruitment_status_insert
AFTER INSERT ON recruitment_requests
FOR EACH ROW
EXECUTE FUNCTION fn_log_recruitment_status();

CREATE TRIGGER trg_log_recruitment_status_update
AFTER UPDATE ON recruitment_requests
FOR EACH ROW
EXECUTE FUNCTION fn_log_recruitment_status();

-- ----------------------------
-- Представления
-- ----------------------------

-- Задания, которые должен видеть управляющий офисом
CREATE OR REPLACE VIEW v_tasks_in_work AS
SELECT
    t.task_id,
    t.title,
    t.date_start,
    t.date_end,
    t.status,
    s.store_name,
    r.region_name,
    t.performer_wishes,
    t.created_at,
    t.submitted_at
FROM tasks t
JOIN stores s ON s.store_id = t.store_id
JOIN regions r ON r.region_id = s.region_id
WHERE t.status = 'in_work';

-- Архив выполненных и закрытых заданий
CREATE OR REPLACE VIEW v_task_archive AS
SELECT
    t.task_id,
    t.title,
    t.date_start,
    t.date_end,
    t.status,
    s.store_name,
    sp.specialist_id,
    concat_ws(' ', sp.last_name, sp.first_name, sp.middle_name) AS specialist_full_name,
    t.assigned_at,
    t.closed_at
FROM tasks t
JOIN stores s ON s.store_id = t.store_id
LEFT JOIN specialists sp ON sp.specialist_id = t.assigned_specialist_id
WHERE t.status IN ('completed', 'closed');

-- Удобное представление для поиска специалистов
CREATE OR REPLACE VIEW v_specialists_search AS
SELECT
    sp.specialist_id,
    concat_ws(' ', sp.last_name, sp.first_name, sp.middle_name) AS specialist_full_name,
    sp.phone,
    sp.email,
    rg.region_name,
    sp.contract_status,
    sp.is_available,
    string_agg(st.specialty_name, ', ' ORDER BY st.specialty_name) AS specialties
FROM specialists sp
JOIN regions rg ON rg.region_id = sp.region_id
LEFT JOIN specialist_specialties ss ON ss.specialist_id = sp.specialist_id
LEFT JOIN specialties st ON st.specialty_id = ss.specialty_id
GROUP BY
    sp.specialist_id,
    sp.last_name,
    sp.first_name,
    sp.middle_name,
    sp.phone,
    sp.email,
    rg.region_name,
    sp.contract_status,
    sp.is_available;

-- ----------------------------
-- Примеры справочников (необязательно)
-- ----------------------------
-- INSERT INTO regions(region_name) VALUES ('Москва'), ('Санкт-Петербург');
-- INSERT INTO specialties(specialty_name) VALUES ('Электрик'), ('Сантехник'), ('Клининг');

-- Пример создания задания
-- INSERT INTO tasks(store_id, created_by_user_id, title, date_start, date_end, performer_wishes)
-- VALUES (1, 10, 'Сервисные работы в торговом зале', '2026-03-15', '2026-03-17', 'Нужен допуск к электрике');

-- Пример состава работ
-- INSERT INTO task_work_items(task_id, line_no, work_name, specialty_id, quantity)
-- VALUES
--   (1, 1, 'Замена светильников', 1, 10),
--   (1, 2, 'Проверка проводки', 1, 1);

-- Пример перевода в статус "в работе"
-- UPDATE tasks SET status = 'in_work' WHERE task_id = 1;

-- Пример назначения специалиста и перевода задания в "completed"
-- UPDATE tasks
-- SET assigned_specialist_id = 5,
--     assigned_by_user_id = 2,
--     status = 'completed'
-- WHERE task_id = 1;

-- Пример закрытия задания
-- UPDATE tasks SET status = 'closed' WHERE task_id = 1;
