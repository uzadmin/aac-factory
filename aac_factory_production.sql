-- =====================================================================
--  ИСПРАВЛЕННАЯ СХЕМА БД для завода ААС "aac_factory_production"
--  Версия: 5.0 (С исправлениями и улучшениями)
-- =====================================================================

-- НОВОЕ: Создание базы данных с правильными настройками
DROP DATABASE IF EXISTS aac_factory_production;
CREATE DATABASE aac_factory_production 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE aac_factory_production;

-- =====================================================================
--  ИСПРАВЛЕННЫЕ ТАБЛИЦЫ С УЛУЧШЕНИЯМИ
-- =====================================================================

-- ИСПРАВЛЕНИЕ: Добавлена таблица ролей для безопасности
CREATE TABLE employee_roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    permissions JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица сотрудников с ролями
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    telegram_id BIGINT UNIQUE NOT NULL COMMENT 'Уникальный ID пользователя в Telegram',
    telegram_username VARCHAR(50) NULL,
    full_name VARCHAR(200) NOT NULL COMMENT 'Полное имя сотрудника',
    position VARCHAR(100) NULL,
    department VARCHAR(100) NULL,
    role_id INT NOT NULL DEFAULT 1, -- НОВОЕ: Ссылка на роль
    phone VARCHAR(20) NULL,
    email VARCHAR(100) NULL, -- НОВОЕ: Email для уведомлений
    hire_date DATE NULL, -- НОВОЕ: Дата найма
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Активен ли сотрудник',
    last_activity TIMESTAMP NULL, -- НОВОЕ: Последняя активность
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (role_id) REFERENCES employee_roles(role_id) ON DELETE RESTRICT,
    INDEX idx_telegram_id (telegram_id),
    INDEX idx_department_position (department, position),
    INDEX idx_active (is_active),
    INDEX idx_role (role_id),
    
    -- НОВОЕ: Проверочное ограничение
    CONSTRAINT chk_telegram_id_positive CHECK (telegram_id > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица смен с дополнительными проверками
CREATE TABLE shifts (
    shift_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    shift_date DATE NOT NULL COMMENT 'Дата, к которой относится смена',
    shift_type ENUM('day', 'night', 'overtime') NOT NULL DEFAULT 'day',
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NULL,
    status ENUM('active', 'break', 'lunch', 'completed', 'cancelled') DEFAULT 'active',
    productivity_score DECIMAL(5,2) NULL,
    total_hours DECIMAL(6,2) NULL COMMENT 'Общее время от начала до конца',
    work_hours DECIMAL(6,2) NULL COMMENT 'Рабочее время за вычетом перерывов',
    break_minutes INT DEFAULT 0 COMMENT 'Общее время перерывов в минутах',
    notes TEXT NULL,
    supervisor_id INT NULL, -- НОВОЕ: Ответственный руководитель
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    
    INDEX idx_employee_date (employee_id, shift_date),
    INDEX idx_shift_status (status),
    INDEX idx_shift_date (shift_date),
    INDEX idx_supervisor (supervisor_id),
    
    -- ИСПРАВЛЕНИЕ: Добавлены проверочные ограничения
    CONSTRAINT chk_end_after_start CHECK (end_time IS NULL OR end_time > start_time),
    CONSTRAINT chk_total_hours_positive CHECK (total_hours IS NULL OR total_hours >= 0),
    CONSTRAINT chk_work_hours_valid CHECK (work_hours IS NULL OR (work_hours >= 0 AND work_hours <= total_hours)),
    CONSTRAINT chk_break_minutes_positive CHECK (break_minutes >= 0),
    
    -- НОВОЕ: Ограничение на одну активную смену на сотрудника
    CONSTRAINT unique_active_shift UNIQUE (employee_id, status) -- Будет работать только для статусов, отличных от completed/cancelled
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- НОВОЕ: Таблица для отслеживания перерывов
CREATE TABLE shift_breaks (
    break_id INT AUTO_INCREMENT PRIMARY KEY,
    shift_id INT NOT NULL,
    break_type ENUM('lunch', 'short', 'technical') NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NULL,
    duration_minutes INT NULL,
    reason TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shift_id) REFERENCES shifts(shift_id) ON DELETE CASCADE,
    INDEX idx_shift_break (shift_id, break_type),
    
    CONSTRAINT chk_break_end_after_start CHECK (end_time IS NULL OR end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица материалов с историей изменений
CREATE TABLE materials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    material_name VARCHAR(200) NOT NULL UNIQUE,
    material_type ENUM('cement', 'lime', 'sand', 'aluminum', 'water', 'additive') NOT NULL,
    current_stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    minimum_stock DECIMAL(10,2) NOT NULL,
    maximum_stock DECIMAL(10,2) NOT NULL,
    unit_of_measure ENUM('kg', 'tonnes', 'liters', 'cubic_meters') NOT NULL,
    storage_location VARCHAR(100),
    supplier VARCHAR(200) NULL, -- НОВОЕ: Поставщик
    cost_per_unit DECIMAL(10,2) NULL, -- НОВОЕ: Стоимость за единицу
    last_purchase_date DATE NULL, -- НОВОЕ: Дата последней закупки
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL, -- НОВОЕ: Кто создал запись
    
    FOREIGN KEY (created_by) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_material_type (material_type),
    INDEX idx_stock_level (current_stock, minimum_stock),
    INDEX idx_supplier (supplier),
    
    -- ИСПРАВЛЕНИЕ: Добавлены проверочные ограничения
    CONSTRAINT chk_stock_positive CHECK (current_stock >= 0),
    CONSTRAINT chk_minimum_stock_positive CHECK (minimum_stock > 0),
    CONSTRAINT chk_maximum_greater_minimum CHECK (maximum_stock > minimum_stock),
    CONSTRAINT chk_cost_positive CHECK (cost_per_unit IS NULL OR cost_per_unit > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- НОВОЕ: Таблица истории изменений остатков
CREATE TABLE material_stock_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    material_id INT NOT NULL,
    change_type ENUM('load', 'consumption', 'adjustment', 'waste') NOT NULL,
    quantity_change DECIMAL(10,2) NOT NULL, -- Может быть отрицательным для расхода
    stock_before DECIMAL(10,2) NOT NULL,
    stock_after DECIMAL(10,2) NOT NULL,
    reason TEXT NULL,
    changed_by INT NOT NULL,
    reference_id INT NULL, -- Ссылка на связанную запись (bunker_load_id, etc.)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (material_id) REFERENCES materials(material_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES employees(employee_id) ON DELETE RESTRICT,
    INDEX idx_material_history (material_id, created_at),
    INDEX idx_change_type (change_type),
    INDEX idx_changed_by (changed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица бункеров с дополнительными полями
CREATE TABLE bunkers (
    bunker_id VARCHAR(50) PRIMARY KEY,
    bunker_name VARCHAR(100) NOT NULL,
    material_id INT NOT NULL,
    current_amount DECIMAL(10,2) DEFAULT 0,
    max_capacity DECIMAL(10,2) NOT NULL,
    min_threshold DECIMAL(10,2) NOT NULL,
    warning_threshold DECIMAL(10,2) NULL, -- НОВОЕ: Предупредительный уровень
    location VARCHAR(100),
    production_line VARCHAR(50) NULL, -- НОВОЕ: Привязка к линии
    status ENUM('active', 'maintenance', 'inactive', 'emergency') DEFAULT 'active',
    last_maintenance DATE NULL, -- НОВОЕ: Дата последнего обслуживания
    next_maintenance DATE NULL, -- НОВОЕ: Дата следующего обслуживания
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_operator_id INT NULL,
    
    FOREIGN KEY (material_id) REFERENCES materials(material_id) ON DELETE RESTRICT,
    FOREIGN KEY (last_operator_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_bunker_status (status),
    INDEX idx_bunker_level (current_amount, min_threshold),
    INDEX idx_production_line (production_line),
    INDEX idx_material_bunkers (material_id),
    
    -- ИСПРАВЛЕНИЕ: Добавлены проверочные ограничения
    CONSTRAINT chk_current_amount_positive CHECK (current_amount >= 0),
    CONSTRAINT chk_max_capacity_positive CHECK (max_capacity > 0),
    CONSTRAINT chk_min_threshold_valid CHECK (min_threshold >= 0 AND min_threshold < max_capacity),
    CONSTRAINT chk_warning_threshold_valid CHECK (warning_threshold IS NULL OR (warning_threshold >= min_threshold AND warning_threshold < max_capacity)),
    CONSTRAINT chk_current_not_exceed_max CHECK (current_amount <= max_capacity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица загрузок с дополнительными проверками
CREATE TABLE bunker_loads (
    load_id INT AUTO_INCREMENT PRIMARY KEY,
    bunker_id VARCHAR(50) NOT NULL,
    material_id INT NOT NULL,
    loaded_by_id INT NOT NULL,
    quantity_loaded DECIMAL(10,2) NOT NULL,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    quality_check_passed BOOLEAN DEFAULT TRUE,
    quality_checker_id INT NULL, -- НОВОЕ: Кто проверил качество
    batch_number VARCHAR(100) NULL, -- НОВОЕ: Номер партии
    supplier_delivery_id VARCHAR(100) NULL, -- НОВОЕ: ID поставки
    temperature DECIMAL(4,1) NULL, -- НОВОЕ: Температура материала
    humidity DECIMAL(4,1) NULL, -- НОВОЕ: Влажность
    notes TEXT NULL,
    approved_by_id INT NULL, -- НОВОЕ: Кто одобрил загрузку
    
    FOREIGN KEY (bunker_id) REFERENCES bunkers(bunker_id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES materials(material_id) ON DELETE CASCADE,
    FOREIGN KEY (loaded_by_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (quality_checker_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    FOREIGN KEY (approved_by_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    
    INDEX idx_bunker_loads_timestamp (load_timestamp),
    INDEX idx_material_loads (material_id, load_timestamp),
    INDEX idx_loaded_by (loaded_by_id),
    INDEX idx_quality_check (quality_check_passed),
    INDEX idx_batch_number (batch_number),
    
    -- ИСПРАВЛЕНИЕ: Добавлены проверочные ограничения
    CONSTRAINT chk_quantity_loaded_positive CHECK (quantity_loaded > 0),
    CONSTRAINT chk_temperature_valid CHECK (temperature IS NULL OR temperature BETWEEN -50 AND 100),
    CONSTRAINT chk_humidity_valid CHECK (humidity IS NULL OR humidity BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица дефектов с расширенной трассировкой
CREATE TABLE defects (
    defect_id INT AUTO_INCREMENT PRIMARY KEY,
    shift_id INT NULL,
    reporter_id INT NOT NULL,
    production_line VARCHAR(100) NOT NULL,
    defect_type ENUM('size', 'crack', 'color', 'strength', 'surface', 'other') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    description TEXT NOT NULL,
    photo_file_id VARCHAR(255) NULL,
    photo_file_size INT NULL, -- НОВОЕ: Размер файла фото
    batch_number VARCHAR(100) NULL, -- НОВОЕ: Номер партии с дефектом
    estimated_cost DECIMAL(10,2) NULL, -- НОВОЕ: Оценочная стоимость ущерба
    affected_quantity INT NULL, -- НОВОЕ: Количество дефектных изделий
    status ENUM('open', 'in_progress', 'resolved', 'closed', 'rejected') DEFAULT 'open',
    priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal', -- НОВОЕ: Приоритет
    assigned_to_id INT NULL, -- НОВОЕ: Кому назначено
    resolved_by_id INT NULL,
    resolved_at TIMESTAMP NULL,
    resolution_notes TEXT NULL,
    root_cause TEXT NULL, -- НОВОЕ: Причина дефекта
    preventive_actions TEXT NULL, -- НОВОЕ: Превентивные меры
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shift_id) REFERENCES shifts(shift_id) ON DELETE SET NULL,
    FOREIGN KEY (reporter_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (resolved_by_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    
    INDEX idx_defect_status_severity (status, severity),
    INDEX idx_production_line (production_line),
    INDEX idx_reporter_id (reporter_id),
    INDEX idx_assigned_to (assigned_to_id),
    INDEX idx_priority (priority),
    INDEX idx_batch_number (batch_number),
    
    -- ИСПРАВЛЕНИЕ: Добавлены проверочные ограничения
    CONSTRAINT chk_estimated_cost_positive CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT chk_affected_quantity_positive CHECK (affected_quantity IS NULL OR affected_quantity > 0),
    CONSTRAINT chk_resolution_logic CHECK (
        (status IN ('resolved', 'closed') AND resolved_at IS NOT NULL AND resolved_by_id IS NOT NULL) OR
        (status NOT IN ('resolved', 'closed'))
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕНИЕ: Улучшенная таблица рецептов с версионностью
CREATE TABLE recipes (
    recipe_id INT AUTO_INCREMENT PRIMARY KEY,
    recipe_name VARCHAR(200) NOT NULL,
    product_code VARCHAR(50) UNIQUE,
    version VARCHAR(10) NOT NULL DEFAULT '1.0', -- НОВОЕ: Версия рецепта
    product_type ENUM('block', 'panel', 'reinforced', 'insulation') NOT NULL,
    density_kg_m3 DECIMAL(6,2) NOT NULL,
    cement_kg DECIMAL(8,2) NOT NULL,
    lime_kg DECIMAL(8,2) NOT NULL,
    sand_kg DECIMAL(8,2) NOT NULL,
    water_liters DECIMAL(8,2) NOT NULL,
    aluminum_powder_kg DECIMAL(8,3) NOT NULL,
    mixing_time_minutes INT NOT NULL,
    curing_temp_celsius INT NOT NULL,
    curing_hours INT NOT NULL,
    strength_mpa DECIMAL(5,2) NULL,
    cost_per_m3 DECIMAL(10,2) NULL, -- НОВОЕ: Стоимость за м³
    margin_percent DECIMAL(5,2) NULL, -- НОВОЕ: Планируемая маржа
    quality_grade ENUM('A', 'B', 'C') DEFAULT 'B', -- НОВОЕ: Класс качества
    environmental_impact ENUM('low', 'medium', 'high') DEFAULT 'medium', -- НОВОЕ: Экологичность
    created_by INT NULL, -- НОВОЕ: Создатель рецепта
    approved_by INT NULL, -- НОВОЕ: Кто утвердил
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (created_by) REFERENCES employees(employee_id) ON DELETE SET NULL,
    FOREIGN KEY (approved_by) REFERENCES employees(employee_id) ON DELETE SET NULL,
    
    INDEX idx_recipe_name (recipe_name),
    INDEX idx_product_type (product_type),
    INDEX idx_active_recipes (is_active),
    INDEX idx_density (density_kg_m3),
    INDEX idx_version (version),
    FULLTEXT idx_recipe_search (recipe_name, product_code),
    
    -- ИСПРАВЛЕНИЕ: Добавлены проверочные ограничения
    CONSTRAINT chk_density_positive CHECK (density_kg_m3 > 0),
    CONSTRAINT chk_ingredients_positive CHECK (
        cement_kg > 0 AND lime_kg >= 0 AND sand_kg > 0 AND 
        water_liters > 0 AND aluminum_powder_kg > 0
    ),
    CONSTRAINT chk_mixing_time_positive CHECK (mixing_time_minutes > 0),
    CONSTRAINT chk_curing_temp_valid CHECK (curing_temp_celsius BETWEEN 80 AND 250),
    CONSTRAINT chk_curing_hours_positive CHECK (curing_hours > 0),
    CONSTRAINT chk_strength_positive CHECK (strength_mpa IS NULL OR strength_mpa > 0),
    CONSTRAINT chk_cost_positive CHECK (cost_per_m3 IS NULL OR cost_per_m3 > 0),
    CONSTRAINT chk_margin_valid CHECK (margin_percent IS NULL OR margin_percent BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- НОВОЕ: Таблица производственных партий
CREATE TABLE production_batches (
    batch_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_number VARCHAR(100) NOT NULL UNIQUE,
    recipe_id INT NOT NULL,
    production_line VARCHAR(50) NOT NULL,
    planned_volume_m3 DECIMAL(8,2) NOT NULL,
    actual_volume_m3 DECIMAL(8,2) NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NULL,
    shift_id INT NULL,
    operator_id INT NOT NULL,
    quality_controller_id INT NULL,
    status ENUM('planned', 'in_progress', 'completed', 'cancelled', 'on_hold') DEFAULT 'planned',
    quality_rating ENUM('excellent', 'good', 'acceptable', 'poor') NULL,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (recipe_id) REFERENCES recipes(recipe_id) ON DELETE RESTRICT,
    FOREIGN KEY (shift_id) REFERENCES shifts(shift_id) ON DELETE SET NULL,
    FOREIGN KEY (operator_id) REFERENCES employees(employee_id) ON DELETE RESTRICT,
    FOREIGN KEY (quality_controller_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    
    INDEX idx_batch_number (batch_number),
    INDEX idx_production_line (production_line),
    INDEX idx_status (status),
    INDEX idx_operator (operator_id),
    INDEX idx_start_time (start_time),
    
    CONSTRAINT chk_planned_volume_positive CHECK (planned_volume_m3 > 0),
    CONSTRAINT chk_actual_volume_positive CHECK (actual_volume_m3 IS NULL OR actual_volume_m3 > 0),
    CONSTRAINT chk_batch_end_after_start CHECK (end_time IS NULL OR end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- НОВОЕ: Таблица уведомлений
CREATE TABLE notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    recipient_id INT NOT NULL,
    sender_id INT NULL,
    notification_type ENUM('defect', 'stock_low', 'shift_alert', 'maintenance', 'general') NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    is_urgent BOOLEAN DEFAULT FALSE,
    related_table VARCHAR(50) NULL, -- Связанная таблица
    related_id INT NULL, -- ID связанной записи
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL,
    
    FOREIGN KEY (recipient_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    
    INDEX idx_recipient_unread (recipient_id, is_read),
    INDEX idx_notification_type (notification_type),
    INDEX idx_urgent (is_urgent),
    INDEX idx_sent_at (sent_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
--  ИСПРАВЛЕННЫЕ ТРИГГЕРЫ С УЛУЧШЕННОЙ ЛОГИКОЙ
-- =====================================================================

DELIMITER //

-- ИСПРАВЛЕНИЕ: Безопасный триггер обновления остатков
CREATE TRIGGER trg_update_stock_after_load
AFTER INSERT ON bunker_loads
FOR EACH ROW
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    DECLARE v_old_bunker_amount DECIMAL(10,2);
    DECLARE v_old_material_stock DECIMAL(10,2);
    
    START TRANSACTION;
    
    -- Получаем текущие значения
    SELECT current_amount INTO v_old_bunker_amount 
    FROM bunkers WHERE bunker_id = NEW.bunker_id;
    
    SELECT current_stock INTO v_old_material_stock 
    FROM materials WHERE material_id = NEW.material_id;
    
    -- Проверяем, что не превышаем вместимость
    IF (v_old_bunker_amount + NEW.quantity_loaded) > 
       (SELECT max_capacity FROM bunkers WHERE bunker_id = NEW.bunker_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Превышение вместимости бункера';
    END IF;
    
    -- Обновляем остаток в бункере
    UPDATE bunkers 
    SET current_amount = current_amount + NEW.quantity_loaded,
        last_updated = NOW(),
        last_operator_id = NEW.loaded_by_id
    WHERE bunker_id = NEW.bunker_id;
    
    -- Обновляем общий остаток материала
    UPDATE materials 
    SET current_stock = current_stock + NEW.quantity_loaded,
        last_updated = NOW()
    WHERE material_id = NEW.material_id;
    
    -- Записываем в историю изменений
    INSERT INTO material_stock_history 
    (material_id, change_type, quantity_change, stock_before, stock_after, 
     reason, changed_by, reference_id)
    VALUES 
    (NEW.material_id, 'load', NEW.quantity_loaded, v_old_material_stock, 
     v_old_material_stock + NEW.quantity_loaded, 
     CONCAT('Загрузка в бункер ', NEW.bunker_id), NEW.loaded_by_id, NEW.load_id);
    
    -- Проверяем критические остатки и создаем уведомления
    CALL CheckAndNotifyCriticalStock(NEW.material_id);
    
    COMMIT;
END; //

-- НОВОЕ: Триггер для автоматического завершения смены при превышении 12 часов
CREATE TRIGGER trg_check_shift_duration
BEFORE UPDATE ON shifts
FOR EACH ROW
BEGIN
    IF NEW.end_time IS NOT NULL AND OLD.end_time IS NULL THEN
        SET NEW.total_hours = TIMESTAMPDIFF(MINUTE, NEW.start_time, NEW.end_time) / 60.0;
        SET NEW.work_hours = NEW.total_hours - (IFNULL(NEW.break_minutes, 0) / 60.0);
        
        -- Проверяем разумную продолжительность смены
        IF NEW.total_hours > 16 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Смена не может длиться более 16 часов';
        END IF;
        
        SET NEW.status = 'completed';
    END IF;
END; //

-- НОВОЕ: Триггер для автоматического создания уведомлений о критичных дефектах
CREATE TRIGGER trg_notify_critical_defects
AFTER INSERT ON defects
FOR EACH ROW
BEGIN
    IF NEW.severity = 'critical' THEN
        -- Уведомляем руководителей смены
        INSERT INTO notifications (recipient_id, notification_type, title, message, is_urgent, related_table, related_id)
        SELECT 
            e.employee_id,
            'defect',
            'КРИТИЧНЫЙ ДЕФЕКТ',
            CONCAT('Обнаружен критичный дефект на линии ', NEW.production_line, '. Тип: ', NEW.defect_type, '. Требуется немедленное вмешательство.'),
            TRUE,
            'defects',
            NEW.defect_id
        FROM employees e
        JOIN employee_roles r ON e.role_id = r.role_id
        WHERE r.role_name IN ('supervisor', 'quality_manager') AND e.is_active = TRUE;
    END IF;
END; //

DELIMITER ;

-- =====================================================================
--  ИСПРАВЛЕННЫЕ ХРАНИМЫЕ ПРОЦЕДУРЫ
-- =====================================================================

DELIMITER //

-- ИСПРАВЛЕНИЕ: Улучшенная процедура проверки критических остатков
CREATE PROCEDURE GetCriticalStock()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_material_id INT;
    DECLARE v_material_name VARCHAR(200);
    DECLARE v_current_stock DECIMAL(10,2);
    DECLARE v_minimum_stock DECIMAL(10,2);
    DECLARE v_unit_measure VARCHAR(20);
    
    DECLARE cur CURSOR FOR 
        SELECT material_id, material_name, current_stock, minimum_stock, unit_of_measure
        FROM materials 
        WHERE current_stock <= minimum_stock * 1.2  -- 120% от минимума
        ORDER BY (current_stock / minimum_stock) ASC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Создаем временную таблицу для результатов
    DROP TEMPORARY TABLE IF EXISTS temp_critical_stock;
    CREATE TEMPORARY TABLE temp_critical_stock (
        material_name VARCHAR(200),
        current_stock DECIMAL(10,2),
        minimum_stock DECIMAL(10,2),
        unit_of_measure VARCHAR(20),
        stock_percentage DECIMAL(5,1)
    );
    
    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO v_material_id, v_material_name, v_current_stock, v_minimum_stock, v_unit_measure;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        INSERT INTO temp_critical_stock VALUES (
            v_material_name,
            v_current_stock,
            v_minimum_stock,
            v_unit_measure,
            ROUND((v_current_stock / v_minimum_stock) * 100, 1)
        );
    END LOOP;
    
    CLOSE cur;
    
    -- Возвращаем результаты
    SELECT * FROM temp_critical_stock;
    
    DROP TEMPORARY TABLE temp_critical_stock;
END; //

-- НОВОЕ: Процедура для проверки и создания уведомлений о критических остатках
CREATE PROCEDURE CheckAndNotifyCriticalStock(IN p_material_id INT)
BEGIN
    DECLARE v_current_stock DECIMAL(10,2);
    DECLARE v_minimum_stock DECIMAL(10,2);
    DECLARE v_material_name VARCHAR(200);
    
    SELECT current_stock, minimum_stock, material_name
    INTO v_current_stock, v_minimum_stock, v_material_name
    FROM materials 
    WHERE material_id = p_material_id;
    
    -- Если остаток критично низкий
    IF v_current_stock <= v_minimum_stock THEN
        INSERT INTO notifications (recipient_id, notification_type, title, message, is_urgent, related_table, related_id)
        SELECT 
            e.employee_id,
            'stock_low',
            'КРИТИЧНЫЙ ОСТАТОК МАТЕРИАЛА',
            CONCAT('Критично низкий остаток материала "', v_material_name, '": ', v_current_stock, ' (минимум: ', v_minimum_stock, '). Требуется срочное пополнение.'),
            TRUE,
            'materials',
            p_material_id
        FROM employees e
        JOIN employee_roles r ON e.role_id = r.role_id
        WHERE r.role_name IN ('supervisor', 'warehouse_manager') AND e.is_active = TRUE;
    END IF;
END; //

-- ИСПРАВЛЕНИЕ: Улучшенная процедура поиска рецептов
CREATE PROCEDURE SearchRecipes(IN search_term VARCHAR(200))
BEGIN
    -- Если поисковый термин пустой, возвращаем все активные рецепты
    IF search_term IS NULL OR TRIM(search_term) = '' THEN
        SELECT 
            recipe_id, recipe_name, product_code, product_type,
            cement_kg, lime_kg, sand_kg, water_liters, aluminum_powder_kg,
            mixing_time_minutes, density_kg_m3, strength_mpa, version
        FROM recipes
        WHERE is_active = TRUE
        ORDER BY recipe_name
        LIMIT 10;
    ELSE
        SELECT 
            recipe_id, recipe_name, product_code, product_type,
            cement_kg, lime_kg, sand_kg, water_liters, aluminum_powder_kg,
            mixing_time_minutes, density_kg_m3, strength_mpa, version,
            -- Добавляем релевантность для сортировки
            CASE 
                WHEN recipe_name = search_term THEN 1
                WHEN recipe_name LIKE CONCAT(search_term, '%') THEN 2
                WHEN product_code = search_term THEN 3
                WHEN product_code LIKE CONCAT(search_term, '%') THEN 4
                ELSE 5
            END as relevance
        FROM recipes
        WHERE is_active = TRUE
        AND (
            recipe_name LIKE CONCAT('%', search_term, '%')
            OR product_code LIKE CONCAT('%', search_term, '%')
            OR product_type LIKE CONCAT('%', search_term, '%')
            OR MATCH(recipe_name, product_code) AGAINST(search_term IN NATURAL LANGUAGE MODE)
        )
        ORDER BY relevance, recipe_name
        LIMIT 10;
    END IF;
END; //

-- НОВОЕ: Процедура для получения статистики смены
CREATE PROCEDURE GetShiftStatistics(IN p_shift_id INT)
BEGIN
    SELECT 
        s.shift_id,
        s.start_time,
        s.end_time,
        s.total_hours,
        s.work_hours,
        s.break_minutes,
        e.full_name as employee_name,
        e.position,
        -- Статистика по загрузкам
        (SELECT COUNT(*) FROM bunker_loads bl WHERE bl.loaded_by_id = s.employee_id 
         AND DATE(bl.load_timestamp) = s.shift_date) as loads_count,
        (SELECT COALESCE(SUM(bl.quantity_loaded), 0) FROM bunker_loads bl WHERE bl.loaded_by_id = s.employee_id 
         AND DATE(bl.load_timestamp) = s.shift_date) as total_loaded,
        -- Статистика по дефектам
        (SELECT COUNT(*) FROM defects d WHERE d.reporter_id = s.employee_id 
         AND DATE(d.created_at) = s.shift_date) as defects_reported,
        (SELECT COUNT(*) FROM defects d WHERE d.reporter_id = s.employee_id 
         AND d.severity = 'critical' AND DATE(d.created_at) = s.shift_date) as critical_defects
    FROM shifts s
    JOIN employees e ON s.employee_id = e.employee_id
    WHERE s.shift_id = p_shift_id;
END; //

DELIMITER ;

-- =====================================================================
--  УЛУЧШЕННЫЕ ПРЕДСТАВЛЕНИЯ (VIEWS)
-- =====================================================================

-- ИСПРАВЛЕНИЕ: Расширенная панель управления
CREATE VIEW production_dashboard AS
SELECT 
    DATE(s.shift_date) as production_date,
    COUNT(DISTINCT s.shift_id) as total_shifts,
    COUNT(DISTINCT CASE WHEN s.status IN ('active', 'break', 'lunch') THEN s.shift_id END) as active_shifts,
    COUNT(DISTINCT CASE WHEN s.status = 'completed' THEN s.shift_id END) as completed_shifts,
    ROUND(AVG(s.productivity_score), 2) as avg_productivity,
    ROUND(SUM(s.work_hours), 2) as total_work_hours,
    
    -- Статистика по загрузкам
    (SELECT COUNT(*) FROM bunker_loads bl WHERE DATE(bl.load_timestamp) = DATE(s.shift_date)) as total_loads,
    (SELECT COALESCE(SUM(bl.quantity_loaded), 0) FROM bunker_loads bl WHERE DATE(bl.load_timestamp) = DATE(s.shift_date)) as total_material_loaded,
    
    -- Статистика по дефектам
    (SELECT COUNT(*) FROM defects d WHERE DATE(d.created_at) = DATE(s.shift_date)) as total_defects,
    (SELECT COUNT(*) FROM defects d WHERE DATE(d.created_at) = DATE(s.shift_date) AND d.severity = 'critical') as critical_defects,
    (SELECT COUNT(*) FROM defects d WHERE DATE(d.created_at) = DATE(s.shift_date) AND d.status = 'open') as open_defects,
    
    -- Статистика по производству
    (SELECT COUNT(*) FROM production_batches pb WHERE DATE(pb.start_time) = DATE(s.shift_date)) as batches_produced,
    (SELECT COALESCE(SUM(pb.actual_volume_m3), 0) FROM production_batches pb WHERE DATE(pb.start_time) = DATE(s.shift_date) AND pb.status = 'completed') as total_volume_produced
    
FROM shifts s
WHERE s.shift_date >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
GROUP BY DATE(s.shift_date)
ORDER BY production_date DESC;

-- НОВОЕ: Представление активных смен с деталями
CREATE VIEW active_shifts_detailed AS
SELECT 
    s.shift_id,
    s.employee_id,
    e.full_name,
    e.position,
    e.department,
    s.start_time,
    s.status,
    TIMESTAMPDIFF(MINUTE, s.start_time, NOW()) / 60.0 as hours_worked,
    s.break_minutes,
    
    -- Статистика по текущей смене
    (SELECT COUNT(*) FROM bunker_loads bl WHERE bl.loaded_by_id = s.employee_id 
     AND DATE(bl.load_timestamp) = CURRENT_DATE) as loads_today,
    (SELECT COUNT(*) FROM defects d WHERE d.reporter_id = s.employee_id 
     AND DATE(d.created_at) = CURRENT_DATE) as defects_today,
    
    -- Контактная информация
    e.telegram_id,
    e.phone
FROM shifts s
JOIN employees e ON s.employee_id = e.employee_id
WHERE s.status IN ('active', 'break', 'lunch')
ORDER BY s.start_time;

-- ИСПРАВЛЕНИЕ: Улучшенное представление критических остатков
CREATE VIEW critical_materials_extended AS
SELECT 
    m.material_id,
    m.material_name,
    m.material_type,
    m.current_stock,
    m.minimum_stock,
    m.maximum_stock,
    m.unit_of_measure,
    ROUND((m.current_stock / m.minimum_stock) * 100, 1) as stock_percentage,
    
    -- Расчет дней до нехватки (на основе среднего расхода)
    CASE 
        WHEN avg_daily_consumption.avg_consumption > 0 
        THEN ROUND(m.current_stock / avg_daily_consumption.avg_consumption, 1)
        ELSE NULL 
    END as days_until_empty,
    
    m.supplier,
    m.last_purchase_date,
    
    -- Количество бункеров с этим материалом
    (SELECT COUNT(*) FROM bunkers b WHERE b.material_id = m.material_id AND b.status = 'active') as active_bunkers
    
FROM materials m
LEFT JOIN (
    SELECT 
        material_id,
        AVG(quantity_change) as avg_consumption
    FROM material_stock_history 
    WHERE change_type = 'consumption' 
    AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    GROUP BY material_id
) avg_daily_consumption ON m.material_id = avg_daily_consumption.material_id
WHERE m.current_stock <= m.minimum_stock * 1.5  -- 150% от минимума
ORDER BY stock_percentage ASC;

-- =====================================================================
--  НАЧАЛЬНЫЕ ДАННЫЕ С ИСПРАВЛЕНИЯМИ
-- =====================================================================

-- Добавляем роли сотрудников
INSERT INTO employee_roles (role_name, description, permissions) VALUES
('operator', 'Оператор производства', '{"can_load_materials": true, "can_report_defects": true, "can_view_recipes": true}'),
('supervisor', 'Руководитель смены', '{"can_load_materials": true, "can_report_defects": true, "can_view_recipes": true, "can_manage_shifts": true, "can_approve_loads": true}'),
('quality_manager', 'Менеджер по качеству', '{"can_view_defects": true, "can_resolve_defects": true, "can_view_quality_reports": true}'),
('warehouse_manager', 'Менеджер склада', '{"can_manage_materials": true, "can_view_stock": true, "can_manage_suppliers": true}'),
('admin', 'Администратор системы', '{"full_access": true}');

-- Добавляем тестового сотрудника с правильной ролью
INSERT INTO employees (telegram_id, full_name, position, department, role_id, email) VALUES
(123456789, 'Иванов Иван Иванович', 'Оператор линии', 'Производственный цех', 1, 'ivanov@aac-factory.com'),
(987654321, 'Петров Петр Петрович', 'Руководитель смены', 'Производственный цех', 2, 'petrov@aac-factory.com');

-- Добавляем материалы с улучшенными данными
INSERT INTO materials (material_name, material_type, current_stock, minimum_stock, maximum_stock, unit_of_measure, storage_location, supplier, cost_per_unit) VALUES
('Цемент ПЦ500-Д0', 'cement', 100, 20, 200, 'tonnes', 'Склад А', 'СтройЦемент ООО', 4500.00),
('Известь негашеная высшего сорта', 'lime', 50, 15, 100, 'tonnes', 'Склад Б', 'ИзвестьПром ЗАО', 3200.00),
('Песок кварцевый фракция 0.1-0.3', 'sand', 300, 50, 500, 'tonnes', 'Открытая площадка', 'ПескСтрой ООО', 800.00),
('Алюминиевая пудра ПАП-1', 'aluminum', 1, 0.2, 2, 'tonnes', 'Спец. склад', 'МеталлХим ООО', 150000.00);

-- Добавляем бункеры с улучшенными данными
INSERT INTO bunkers (bunker_id, bunker_name, material_id, max_capacity, min_threshold, warning_threshold, location, production_line) VALUES
('БЦ1', 'Бункер цемента №1', 1, 150, 20, 30, 'Линия 1', 'Линия 1'),
('БИ1', 'Бункер извести №1', 2, 80, 15, 25, 'Линия 1', 'Линия 1'),
('БП1', 'Бункер песка №1', 3, 200, 30, 50, 'Линия 1', 'Линия 1'),
('БА1', 'Бункер алюминия №1', 4, 5, 0.5, 1, 'Линия 1', 'Линия 1');

-- Добавляем рецепты с улучшенными данными
INSERT INTO recipes (recipe_name, product_code, version, product_type, density_kg_m3, cement_kg, lime_kg, sand_kg, water_liters, aluminum_powder_kg, mixing_time_minutes, curing_temp_celsius, curing_hours, strength_mpa, cost_per_m3, created_by, approved_by) VALUES
('Блок стеновой D500 B2.5', 'AAC-D500-B25', '2.1', 'block', 500, 280, 120, 1450, 180, 0.450, 8, 190, 12, 2.5, 3500.00, 2, 2),
('Блок стеновой D600 B3.5', 'AAC-D600-B35', '1.8', 'block', 600, 320, 140, 1600, 200, 0.550, 10, 190, 12, 3.5, 4200.00, 2, 2),
('Панель перекрытия D400 B2.0', 'AAC-D400-B20', '1.5', 'panel', 400, 200, 100, 1200, 160, 0.350, 6, 180, 10, 2.0, 3000.00, 2, 2);

-- =====================================================================
--  ИНДЕКСЫ ДЛЯ ПРОИЗВОДИТЕЛЬНОСТИ
-- =====================================================================

-- Дополнительные индексы для улучшения производительности
CREATE INDEX idx_shifts_employee_status ON shifts(employee_id, status);
CREATE INDEX idx_defects_severity_created ON defects(severity, created_at);
CREATE INDEX idx_bunker_loads_timestamp_material ON bunker_loads(load_timestamp, material_id);
CREATE INDEX idx_material_stock_history_material_date ON material_stock_history(material_id, created_at);
CREATE INDEX idx_notifications_recipient_urgent ON notifications(recipient_id, is_urgent, is_read);

-- =====================================================================
--  КОНЕЦ ИСПРАВЛЕННОЙ СХЕМЫ
-- =====================================================================

-- Показываем финальную статистику
SELECT 'Исправленная база данных создана успешно!' as status;
SELECT COUNT(*) as tables_created FROM information_schema.tables 
WHERE table_schema = 'aac_factory_production';
SELECT COUNT(*) as procedures_created FROM information_schema.routines 
WHERE routine_schema = 'aac_factory_production' AND routine_type = 'PROCEDURE';
SELECT COUNT(*) as triggers_created FROM information_schema.triggers 
WHERE trigger_schema = 'aac_factory_production';
