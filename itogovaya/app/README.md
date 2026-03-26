# Система управления сервисными заданиями

Полноценное веб-приложение: Express.js backend + vanilla JS frontend + PostgreSQL.

---

## Структура проекта

```
app/
├── server/
│   ├── server.js          ← точка входа Express
│   ├── db.js              ← подключение к PostgreSQL
│   ├── package.json
│   ├── .env.example       ← пример настроек
│   ├── seed.sql           ← тестовые данные
│   ├── middleware/
│   │   └── auth.js        ← JWT middleware
│   └── routes/
│       ├── auth.js        ← POST /api/auth/login, GET /api/auth/me
│       ├── tasks.js       ← CRUD заданий
│       ├── specialists.js ← база специалистов
│       └── recruitment.js ← заявки на подбор
└── client/
    ├── index.html         ← единственная страница (SPA)
    ├── style.css          ← стили
    └── app.js             ← весь JS: fetch, DOM, localStorage
```

---

## Запуск (шаг за шагом)

### 1. База данных PostgreSQL

```sql
-- В psql или pgAdmin создать БД:
CREATE DATABASE service_tasks;

-- Затем выполнить в этой БД:
-- 1. db_schema.sql  (создаёт таблицы)
-- 2. seed.sql       (тестовые данные)
```

### 2. Настройка сервера

```bash
cd server
cp .env.example .env
# Открыть .env и указать пароль от PostgreSQL и JWT_SECRET
```

`.env`:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=service_tasks
DB_USER=postgres
DB_PASSWORD=ВАШ_ПАРОЛЬ

JWT_SECRET=super_secret_key_12345
JWT_EXPIRES_IN=8h
PORT=3000
```

### 3. Установка зависимостей и запуск

```bash
cd server
npm install
npm start
```

Открыть в браузере: **http://localhost:3000**

---

## Тестовые пользователи (пароль у всех: `Password123!`)

| Логин     | Роль                 | Доступ                                      |
|-----------|----------------------|---------------------------------------------|
| manager1  | Управляющий магазином | Создание заданий, отправка в офис, отмена   |
| office1   | Управляющий офисом   | Назначение специалистов, закрытие заданий   |
| hr1       | Специалист HR        | Обработка заявок на подбор, добавление spec |

---

## API для тестирования в Postman / Insomnia

### Авторизация
```
POST http://localhost:3000/api/auth/login
Content-Type: application/json

{ "username": "manager1", "password": "Password123!" }
```
→ Скопировать `token` из ответа и добавить в заголовок:
`Authorization: Bearer <token>`

### Задания
```
GET  /api/tasks                        — список заданий
GET  /api/tasks?status=in_progress     — фильтр по статусу
POST /api/tasks                        — создать задание
POST /api/tasks/:id/send               — отправить в офис
POST /api/tasks/:id/assign             — назначить специалиста
POST /api/tasks/:id/close              — закрыть задание
POST /api/tasks/:id/cancel             — отменить задание
```

### Специалисты
```
GET  /api/specialists                              — все специалисты
GET  /api/specialists?specialization_id=1&region=Москва
GET  /api/specialists/specializations              — справочник
POST /api/specialists                              — добавить (только HR)
```

### Заявки на подбор
```
GET   /api/recruitment                 — список заявок
POST  /api/recruitment                 — создать заявку (office_manager)
PATCH /api/recruitment/:id/status      — сменить статус (hr)
      Body: { "status_code": "in_progress" }
```

---

## Что реализовано по User Story

| US | Функционал                              | Роль              |
|----|-----------------------------------------|-------------------|
| 1  | Создание задания со статусом «новый»    | Управляющий магазина |
| 2  | Отправка задания в офис (→ «в работе»)  | Управляющий магазина |
| 3  | Просмотр заданий «в работе», фильтры    | Управляющий офиса |
| 4  | Назначение специалиста из базы          | Управляющий офиса |
| 5  | Создание заявки на подбор               | Управляющий офиса |
| 6  | Обработка заявок HR'ом                  | HR                |
| 7  | Добавление специалиста в базу           | HR                |
| 8  | Закрытие задания (только из «выполнен») | Управляющий офиса |
| 9  | Отмена задания (новый/в работе)         | Управляющий магазина |
| 10 | Архив закрытых заданий                  | Управляющий офиса |

---

## Стек

- **Backend**: Node.js + Express.js
- **БД**: PostgreSQL (через пакет `pg`)
- **Аутентификация**: JWT (jsonwebtoken) + bcryptjs
- **Frontend**: Нативная верстка (HTML/CSS/JS), без фреймворков
- **Клиент-серверное взаимодействие**: `fetch` с JWT-токеном из `localStorage`
- **Тестирование API**: Postman / Insomnia
