-- ============================================================
-- База данных: Управление сервисными работами
-- СУБД: PostgreSQL
-- Авторы: Сериков, Шавхалов
-- ============================================================

CREATE TYPE user_role AS ENUM ('store_manager','office_manager','hr_specialist');
CREATE TYPE task_status AS ENUM ('new','in_progress','completed','closed','cancelled');
CREATE TYPE recruitment_status AS ENUM ('new','in_progress','completed');
CREATE TYPE contract_status AS ENUM ('active','expired','terminated');

CREATE TABLE stores (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(300),
    region VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    role user_role NOT NULL,
    store_id INT REFERENCES stores(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE specializations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE specialists (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    patronymic VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    specialization_id INT NOT NULL REFERENCES specializations(id),
    region VARCHAR(100),
    contract_status contract_status DEFAULT 'active',
    contract_start DATE,
    contract_end DATE,
    added_by INT REFERENCES users(id),
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE service_tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(300) NOT NULL,
    description TEXT,
    store_id INT NOT NULL REFERENCES stores(id),
    date_start DATE NOT NULL,
    date_end DATE NOT NULL,
    executor_requirements TEXT,
    status task_status DEFAULT 'new',
    created_by INT NOT NULL REFERENCES users(id),
    assigned_specialist_id INT REFERENCES specialists(id),
    assigned_by INT REFERENCES users(id),
    assigned_at TIMESTAMP,
    closed_by INT REFERENCES users(id),
    closed_at TIMESTAMP,
    cancelled_by INT REFERENCES users(id),
    cancelled_at TIMESTAMP,
    cancel_reason TEXT,
    sent_to_office_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_dates CHECK (date_end >= date_start)
);

CREATE TABLE task_status_history (
    id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES service_tasks(id) ON DELETE CASCADE,
    old_status task_status,
    new_status task_status NOT NULL,
    changed_by INT NOT NULL REFERENCES users(id),
    comment TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE recruitment_requests (
    id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES service_tasks(id),
    specialization_id INT NOT NULL REFERENCES specializations(id),
    region VARCHAR(100),
    deadline DATE,
    requirements TEXT,
    status recruitment_status DEFAULT 'new',
    created_by INT NOT NULL REFERENCES users(id),
    assigned_to INT REFERENCES users(id),
    found_specialist_id INT REFERENCES specialists(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Индексы
CREATE INDEX idx_tasks_status ON service_tasks(status);
CREATE INDEX idx_tasks_store ON service_tasks(store_id);
CREATE INDEX idx_tasks_dates ON service_tasks(date_start, date_end);
CREATE INDEX idx_specialists_spec ON specialists(specialization_id);
CREATE INDEX idx_specialists_region ON specialists(region);
CREATE INDEX idx_specialists_contract ON specialists(contract_status);
CREATE INDEX idx_recruitment_status ON recruitment_requests(status);

-- ============================================================
-- ДАННЫЕ
-- ============================================================

INSERT INTO stores (name,address,region) VALUES
('Магазин №1 «Центральный»','ул. Тверская, 10','Москва'),
('Магазин №2 «Южный»','ул. Красная, 25','Краснодар'),
('Магазин №3 «Невский»','Невский пр., 48','Санкт-Петербург'),
('Магазин №4 «Волжский»','ул. Баумана, 15','Казань'),
('Магазин №5 «Уральский»','пр. Ленина, 72','Екатеринбург'),
('Магазин №6 «Сибирский»','Красный пр., 30','Новосибирск'),
('Магазин №7 «Приморский»','ул. Светланская, 12','Владивосток'),
('Магазин №8 «Донской»','пр. Ворошиловский, 33','Ростов-на-Дону'),
('Магазин №9 «Балтийский»','Ленинский пр., 5','Калининград'),
('Магазин №10 «Поволжский»','ул. Молодогвардейская, 18','Самара'),
('Магазин №11 «Черноморский»','ул. Навагинская, 7','Сочи'),
('Магазин №12 «Столичный-2»','ул. Арбат, 36','Москва'),
('Магазин №13 «Петроградский»','Большой пр. П.С., 22','Санкт-Петербург'),
('Магазин №14 «Кубанский»','ул. Северная, 41','Краснодар'),
('Магазин №15 «Тюменский»','ул. Республики, 55','Тюмень');

INSERT INTO specializations (name,description) VALUES
('Электрика','Электромонтажные и электроремонтные работы'),
('Сантехника','Сантехнические работы: водоснабжение, канализация, отопление'),
('Отделка и ремонт','Отделочные, малярные, штукатурные работы'),
('Кондиционирование','Монтаж и ремонт систем кондиционирования'),
('Охранные системы','Установка систем видеонаблюдения и сигнализации'),
('IT-инфраструктура','Прокладка сетей, настройка серверного оборудования'),
('Клининг (генеральный)','Генеральная уборка помещений'),
('Противопожарные системы','Монтаж систем пожаротушения и оповещения');

INSERT INTO users (username,email,password_hash,first_name,last_name,phone,role,store_id) VALUES
('ivanov.sm','ivanov@company.ru','$2b$hash1','Иван','Иванов','+79001110001','store_manager',1),
('petrova.sm','petrova@company.ru','$2b$hash2','Мария','Петрова','+79001110002','store_manager',2),
('kuznetsov.sm','kuznetsov@company.ru','$2b$hash3','Дмитрий','Кузнецов','+79001110003','store_manager',3),
('smirnova.sm','smirnova@company.ru','$2b$hash4','Анна','Смирнова','+79001110004','store_manager',4),
('popov.sm','popov@company.ru','$2b$hash5','Артём','Попов','+79001110005','store_manager',5),
('vasileva.sm','vasileva@company.ru','$2b$hash6','Ольга','Васильева','+79001110006','store_manager',6),
('sokolov.sm','sokolov@company.ru','$2b$hash7','Николай','Соколов','+79001110007','store_manager',7),
('mikhailov.sm','mikhailov@company.ru','$2b$hash8','Павел','Михайлов','+79001110008','store_manager',8),
('fedorova.sm','fedorova@company.ru','$2b$hash9','Екатерина','Фёдорова','+79001110009','store_manager',9),
('morozov.sm','morozov@company.ru','$2b$hash10','Сергей','Морозов','+79001110010','store_manager',10),
('orlova.sm','orlova@company.ru','$2b$hash11','Татьяна','Орлова','+79001110011','store_manager',11),
('lebedev.sm','lebedev@company.ru','$2b$hash12','Андрей','Лебедев','+79001110012','store_manager',12),
('novikova.sm','novikova@company.ru','$2b$hash13','Наталья','Новикова','+79001110013','store_manager',13),
('egorov.sm','egorov@company.ru','$2b$hash14','Максим','Егоров','+79001110014','store_manager',14),
('zakharova.sm','zakharova@company.ru','$2b$hash15','Юлия','Захарова','+79001110015','store_manager',15),
('sidorov.om','sidorov@company.ru','$2b$hash16','Алексей','Сидоров','+79002220001','office_manager',NULL),
('grigorieva.om','grigorieva@company.ru','$2b$hash17','Светлана','Григорьева','+79002220002','office_manager',NULL),
('volkov.om','volkov.om@company.ru','$2b$hash18','Роман','Волков','+79002220003','office_manager',NULL),
('kozlova.hr','kozlova@company.ru','$2b$hash19','Елена','Козлова','+79003330001','hr_specialist',NULL),
('titov.hr','titov@company.ru','$2b$hash20','Игорь','Титов','+79003330002','hr_specialist',NULL);

INSERT INTO specialists (first_name,last_name,patronymic,phone,email,specialization_id,region,contract_status,contract_start,contract_end,added_by,is_available) VALUES
('Дмитрий','Волков','Сергеевич','+79005550001','volkov.d@mail.ru',1,'Москва','active','2025-01-15','2026-06-14',19,TRUE),
('Александр','Зайцев','Николаевич','+79005550002','zaytsev@mail.ru',1,'Санкт-Петербург','active','2025-03-01','2026-08-28',19,TRUE),
('Виктор','Романов','Алексеевич','+79005550003','romanov.v@mail.ru',1,'Казань','active','2025-06-01','2026-05-31',20,TRUE),
('Евгений','Белов','Дмитриевич','+79005550004','belov.e@mail.ru',1,'Екатеринбург','active','2025-09-01','2026-08-31',20,FALSE),
('Сергей','Новиков','Петрович','+79005550005','novikov.s@mail.ru',2,'Москва','active','2025-02-01','2026-07-31',19,TRUE),
('Михаил','Козлов','Иванович','+79005550006','kozlov.m@mail.ru',2,'Краснодар','active','2025-04-15','2026-04-14',19,TRUE),
('Олег','Степанов','Викторович','+79005550007','stepanov.o@mail.ru',2,'Ростов-на-Дону','active','2025-07-01','2026-06-30',20,TRUE),
('Тимур','Хасанов','Равильевич','+79005550008','khasanov@mail.ru',2,'Казань','expired','2024-11-01','2025-10-31',19,FALSE),
('Ольга','Соколова','Дмитриевна','+79005550009','sokolova.o@mail.ru',3,'Краснодар','active','2025-04-10','2026-04-09',19,TRUE),
('Ирина','Павлова','Сергеевна','+79005550010','pavlova.i@mail.ru',3,'Москва','active','2025-05-20','2026-05-19',20,TRUE),
('Руслан','Гаджиев','Магомедович','+79005550011','gadzhiev@mail.ru',3,'Сочи','active','2025-08-01','2026-07-31',20,TRUE),
('Андрей','Фомин','Павлович','+79005550012','fomin.a@mail.ru',3,'Санкт-Петербург','active','2025-03-15','2026-03-14',19,FALSE),
('Денис','Орлов','Андреевич','+79005550013','orlov.d@mail.ru',4,'Москва','active','2025-05-01','2026-04-30',19,TRUE),
('Артём','Макаров','Олегович','+79005550014','makarov.a@mail.ru',4,'Краснодар','active','2025-06-15','2026-06-14',20,TRUE),
('Григорий','Лазарев','Юрьевич','+79005550015','lazarev@mail.ru',4,'Новосибирск','active','2025-09-01','2026-08-31',20,TRUE),
('Константин','Жуков','Валерьевич','+79005550016','zhukov.k@mail.ru',5,'Москва','active','2025-01-20','2026-01-19',19,TRUE),
('Владислав','Егоров','Станиславович','+79005550017','egorov.v@mail.ru',5,'Екатеринбург','active','2025-07-10','2026-07-09',20,TRUE),
('Роман','Тарасов','Игоревич','+79005550018','tarasov@mail.ru',5,'Ростов-на-Дону','active','2025-02-01','2026-01-31',19,TRUE),
('Кирилл','Абрамов','Денисович','+79005550019','abramov.k@mail.ru',6,'Москва','active','2025-03-01','2026-02-28',19,TRUE),
('Станислав','Громов','Артёмович','+79005550020','gromov@mail.ru',6,'Санкт-Петербург','active','2025-08-15','2026-08-14',20,TRUE),
('Илья','Давыдов','Кириллович','+79005550021','davydov@mail.ru',6,'Новосибирск','active','2025-10-01','2026-09-30',20,TRUE),
('Наталья','Кузьмина','Александровна','+79005550022','kuzmina@mail.ru',7,'Москва','active','2025-01-10','2026-01-09',19,TRUE),
('Галина','Борисова','Владимировна','+79005550023','borisova@mail.ru',7,'Краснодар','active','2025-05-05','2026-05-04',19,TRUE),
('Вадим','Николаев','Фёдорович','+79005550024','nikolaev.v@mail.ru',8,'Москва','active','2025-04-01','2026-03-31',20,TRUE),
('Борис','Филатов','Геннадьевич','+79005550025','filatov@mail.ru',8,'Санкт-Петербург','active','2025-06-20','2026-06-19',20,TRUE);

INSERT INTO service_tasks (title,description,store_id,date_start,date_end,executor_requirements,status,created_by,assigned_specialist_id,assigned_by,assigned_at,closed_by,closed_at,sent_to_office_at) VALUES
('Замена электропроводки в торговом зале','Полная замена проводки, 200 кв.м.',1,'2026-01-10','2026-01-25','Допуск к электроустановкам','closed',1,1,16,'2026-01-05 14:00:00',16,'2026-01-26 10:00:00','2026-01-04 09:30:00'),
('Ремонт системы отопления','Устранение течи в радиаторах.',2,'2026-01-15','2026-01-18','Опыт с коммерческим отоплением','closed',2,6,16,'2026-01-13 11:00:00',16,'2026-01-19 09:00:00','2026-01-12 10:00:00'),
('Покраска стен в зоне кассы','Покраска 80 кв.м., RAL 9003.',3,'2026-01-20','2026-01-23','Опыт отделочных работ','closed',3,10,17,'2026-01-18 15:30:00',17,'2026-01-24 16:00:00','2026-01-17 14:00:00'),
('Установка видеонаблюдения','Монтаж 8 камер и регистратора.',4,'2026-02-01','2026-02-07','Лицензия на системы безопасности','closed',4,16,16,'2026-01-30 10:00:00',16,'2026-02-08 11:00:00','2026-01-29 09:00:00'),
('Генеральная уборка после ремонта','Полная уборка торгового зала.',1,'2026-01-27','2026-01-28','Профессиональное оборудование','closed',1,22,17,'2026-01-26 12:00:00',17,'2026-01-29 09:00:00','2026-01-25 16:00:00');

INSERT INTO service_tasks (title,description,store_id,date_start,date_end,executor_requirements,status,created_by,assigned_specialist_id,assigned_by,assigned_at,sent_to_office_at) VALUES
('Ремонт кондиционера на 2 этаже','Диагностика сплит-системы.',5,'2026-03-25','2026-03-28','Сертификат на фреон R-410A','completed',5,13,16,'2026-03-23 10:00:00','2026-03-22 09:00:00'),
('Прокладка локальной сети','СКС на 24 порта.',6,'2026-03-20','2026-03-30','Сертификация по СКС','completed',6,21,17,'2026-03-18 14:00:00','2026-03-17 11:00:00'),
('Замена смесителей в санузлах','Замена 6 смесителей.',8,'2026-03-22','2026-03-24',NULL,'completed',8,7,18,'2026-03-20 16:00:00','2026-03-19 10:00:00');

INSERT INTO service_tasks (title,store_id,date_start,date_end,executor_requirements,status,created_by,sent_to_office_at) VALUES
('Монтаж пожарной сигнализации',7,'2026-04-05','2026-04-12','Лицензия МЧС','in_progress',7,'2026-03-24 09:00:00'),
('Укладка плитки в зоне входа',9,'2026-04-07','2026-04-11','Опыт укладки керамогранита','in_progress',9,'2026-03-25 10:30:00'),
('Ремонт электрощитка',10,'2026-04-01','2026-04-03','Допуск к электроустановкам','in_progress',10,'2026-03-25 14:00:00'),
('Обслуживание кондиционеров (5 шт.)',11,'2026-04-10','2026-04-12',NULL,'in_progress',11,'2026-03-26 08:00:00'),
('Замена дверных замков',12,'2026-04-02','2026-04-03',NULL,'in_progress',12,'2026-03-26 09:15:00');

INSERT INTO service_tasks (title,description,store_id,date_start,date_end,executor_requirements,status,created_by) VALUES
('Ремонт вентиляции на складе','Прочистка воздуховодов.',13,'2026-04-15','2026-04-18','Опыт с промышленной вентиляцией','new',13),
('Установка доводчиков на двери','Установка 4 доводчиков.',14,'2026-04-14','2026-04-15',NULL,'new',14),
('Монтаж серверного шкафа','Установка 19" шкафа, ИБП.',15,'2026-04-20','2026-04-25','Опыт с серверным оборудованием','new',15);

INSERT INTO service_tasks (title,store_id,date_start,date_end,status,created_by,cancelled_by,cancelled_at,cancel_reason,sent_to_office_at) VALUES
('Покраска фасада (ошибочное)',2,'2026-03-01','2026-03-10','cancelled',2,2,'2026-02-28 11:00:00','Работы выполняет арендодатель','2026-02-27 10:00:00');

INSERT INTO service_tasks (title,store_id,date_start,date_end,status,created_by,cancelled_by,cancelled_at,cancel_reason) VALUES
('Замена окон (дубль)',4,'2026-03-15','2026-03-20','cancelled',4,4,'2026-03-10 09:00:00','Дублирует существующее задание');

INSERT INTO service_tasks (title,description,store_id,date_start,date_end,executor_requirements,status,created_by,sent_to_office_at) VALUES
('Установка промышленного кондиционера','Канальный кондиционер 20 кВт.',15,'2026-04-15','2026-04-25','Допуск к промышленному оборудованию','in_progress',15,'2026-03-24 15:00:00'),
('Ремонт системы пожаротушения','Замена оросителей.',3,'2026-04-08','2026-04-14','Лицензия МЧС','in_progress',3,'2026-03-26 11:00:00');

INSERT INTO task_status_history (task_id,old_status,new_status,changed_by,comment,changed_at) VALUES
(1,NULL,'new',1,'Задание создано','2026-01-03 10:00:00'),
(1,'new','in_progress',1,'Отправлено в офис','2026-01-04 09:30:00'),
(1,'in_progress','completed',16,'Назначен: Волков Д.С.','2026-01-05 14:00:00'),
(1,'completed','closed',16,'Акт подписан','2026-01-26 10:00:00'),
(2,NULL,'new',2,'Задание создано','2026-01-11 09:00:00'),
(2,'new','in_progress',2,'Отправлено в офис','2026-01-12 10:00:00'),
(2,'in_progress','completed',16,'Назначен: Козлов М.И.','2026-01-13 11:00:00'),
(2,'completed','closed',16,'Работы завершены','2026-01-19 09:00:00'),
(3,NULL,'new',3,'Задание создано','2026-01-16 10:00:00'),
(3,'new','in_progress',3,'Отправлено в офис','2026-01-17 14:00:00'),
(3,'in_progress','completed',17,'Назначен: Павлова И.С.','2026-01-18 15:30:00'),
(3,'completed','closed',17,'Покраска завершена','2026-01-24 16:00:00'),
(4,NULL,'new',4,'Задание создано','2026-01-28 11:00:00'),
(4,'new','in_progress',4,'Отправлено в офис','2026-01-29 09:00:00'),
(4,'in_progress','completed',16,'Назначен: Жуков К.В.','2026-01-30 10:00:00'),
(4,'completed','closed',16,'Видеонаблюдение смонтировано','2026-02-08 11:00:00'),
(5,NULL,'new',1,'Задание создано','2026-01-24 14:00:00'),
(5,'new','in_progress',1,'Отправлено в офис','2026-01-25 16:00:00'),
(5,'in_progress','completed',17,'Назначен: Кузьмина Н.А.','2026-01-26 12:00:00'),
(5,'completed','closed',17,'Уборка завершена','2026-01-29 09:00:00'),
(6,NULL,'new',5,'Задание создано','2026-03-21 10:00:00'),
(6,'new','in_progress',5,'Отправлено в офис','2026-03-22 09:00:00'),
(6,'in_progress','completed',16,'Назначен: Орлов Д.А.','2026-03-23 10:00:00'),
(7,NULL,'new',6,'Задание создано','2026-03-16 09:00:00'),
(7,'new','in_progress',6,'Отправлено в офис','2026-03-17 11:00:00'),
(7,'in_progress','completed',17,'Назначен: Давыдов И.К.','2026-03-18 14:00:00'),
(8,NULL,'new',8,'Задание создано','2026-03-18 11:00:00'),
(8,'new','in_progress',8,'Отправлено в офис','2026-03-19 10:00:00'),
(8,'in_progress','completed',18,'Назначен: Степанов О.В.','2026-03-20 16:00:00'),
(9,NULL,'new',7,'Задание создано','2026-03-23 08:00:00'),
(9,'new','in_progress',7,'Отправлено в офис','2026-03-24 09:00:00'),
(10,NULL,'new',9,'Задание создано','2026-03-24 09:00:00'),
(10,'new','in_progress',9,'Отправлено в офис','2026-03-25 10:30:00'),
(11,NULL,'new',10,'Задание создано','2026-03-24 13:00:00'),
(11,'new','in_progress',10,'Отправлено в офис','2026-03-25 14:00:00'),
(12,NULL,'new',11,'Задание создано','2026-03-25 16:00:00'),
(12,'new','in_progress',11,'Отправлено в офис','2026-03-26 08:00:00'),
(13,NULL,'new',12,'Задание создано','2026-03-25 17:00:00'),
(13,'new','in_progress',12,'Отправлено в офис','2026-03-26 09:15:00'),
(14,NULL,'new',13,'Задание создано','2026-03-26 10:00:00'),
(15,NULL,'new',14,'Задание создано','2026-03-26 11:00:00'),
(16,NULL,'new',15,'Задание создано','2026-03-26 12:00:00'),
(17,NULL,'new',2,'Задание создано','2026-02-26 09:00:00'),
(17,'new','in_progress',2,'Отправлено в офис','2026-02-27 10:00:00'),
(17,'in_progress','cancelled',2,'Работы выполняет арендодатель','2026-02-28 11:00:00'),
(18,NULL,'new',4,'Задание создано','2026-03-09 10:00:00'),
(18,'new','cancelled',4,'Дублирует существующее','2026-03-10 09:00:00'),
(19,NULL,'new',15,'Задание создано','2026-03-23 14:00:00'),
(19,'new','in_progress',15,'Отправлено в офис','2026-03-24 15:00:00'),
(20,NULL,'new',3,'Задание создано','2026-03-25 10:00:00'),
(20,'new','in_progress',3,'Отправлено в офис','2026-03-26 11:00:00');

INSERT INTO recruitment_requests (task_id,specialization_id,region,deadline,requirements,status,created_by,assigned_to,found_specialist_id,created_at,completed_at) VALUES
(4,5,'Казань','2026-01-28','Лицензия на системы безопасности','completed',16,19,16,'2026-01-10 10:00:00','2026-01-29 15:00:00'),
(3,3,'Санкт-Петербург','2026-01-19','Опыт с водоэмульсионной краской','completed',17,20,10,'2026-01-10 11:00:00','2026-01-17 14:00:00');

INSERT INTO recruitment_requests (task_id,specialization_id,region,deadline,requirements,status,created_by,assigned_to,created_at) VALUES
(19,4,'Тюмень','2026-04-10','Допуск к промышленному оборудованию','in_progress',16,19,'2026-03-25 10:00:00');

INSERT INTO recruitment_requests (task_id,specialization_id,region,deadline,requirements,status,created_by,created_at) VALUES
(9,8,'Владивосток','2026-04-01','Лицензия МЧС','new',18,'2026-03-25 11:00:00'),
(20,8,'Санкт-Петербург','2026-04-05','Лицензия МЧС, пожаротушение','new',17,'2026-03-26 12:00:00');

-- ============================================================
-- ПРЕДСТАВЛЕНИЯ
-- ============================================================

CREATE VIEW v_tasks_in_progress AS
SELECT t.id, t.title, t.description, s.name AS store_name, s.region AS store_region,
       t.date_start, t.date_end, t.executor_requirements, t.status,
       u.first_name || ' ' || u.last_name AS created_by_name,
       t.created_at, t.sent_to_office_at
FROM service_tasks t
    JOIN stores s ON t.store_id = s.id
    JOIN users u ON t.created_by = u.id
WHERE t.status = 'in_progress';

CREATE VIEW v_tasks_archive AS
SELECT t.id, t.title, s.name AS store_name, s.region AS store_region,
       t.date_start, t.date_end, t.status,
       sp.first_name || ' ' || sp.last_name AS specialist_name,
       spec.name AS specialization, t.assigned_at, t.closed_at, t.created_at
FROM service_tasks t
    JOIN stores s ON t.store_id = s.id
    LEFT JOIN specialists sp ON t.assigned_specialist_id = sp.id
    LEFT JOIN specializations spec ON sp.specialization_id = spec.id
WHERE t.status IN ('completed','closed');

CREATE VIEW v_recruitment_for_hr AS
SELECT r.id, r.task_id, t.title AS task_title, spec.name AS specialization,
       r.region, r.deadline, r.requirements, r.status,
       u.first_name || ' ' || u.last_name AS created_by_name, r.created_at
FROM recruitment_requests r
    JOIN service_tasks t ON r.task_id = t.id
    JOIN specializations spec ON r.specialization_id = spec.id
    JOIN users u ON r.created_by = u.id
WHERE r.status IN ('new','in_progress');
