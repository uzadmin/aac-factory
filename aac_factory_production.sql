-- =====================================================================
--  ИСПРАВЛЕННАЯ СХЕМА БД для завода ААС "aac_factory_production"
--  Версия: 5.1 (Исправлены все ошибки)
-- =====================================================================

-- Создание базы данных с правильными настройками
DROP DATABASE IF EXISTS aac_factory_production;
CREATE DATABASE aac_factory_production
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE aac_factory_production;

-- =====================================================================
--  ТАБЛИЦЫ С ИСПРАВЛЕНИЯМИ
-- =====================================================================

-- Таблица ролей для безопасности
CREATE TABLE employee_roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    permissions JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Улучшенная таблица сотрудников с ролями
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    telegram_id BIGINT UNIQUE NOT NULL COMMENT 'Уникальный ID пользователя в Telegram',
    telegram_username VARCHAR(50) NULL,
    full_name VARCHAR(200) NOT NULL COMMENT 'Полное имя сотрудника',
    position VARCHAR(100) NULL,
    department VARCHAR(100) NULL,
    role_id INT NOT NULL DEFAULT 1,
    phone VARCHAR(20) NULL,
    email VARCHAR(100) NULL,
    hire_date DATE NULL,
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Активен ли сотрудник',
    last_activity TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES employee_roles(role_id) ON DELETE RESTRICT,
    INDEX idx_telegram_id (telegram_id),
    INDEX idx_department_position (department, position),
    INDEX idx_active (is_active),
    INDEX idx_role (role_id),
    CONSTRAINT chk_telegram_id_positive CHECK (telegram_id > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Улучшенная таблица смен (убран проблемный unique constraint)
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
    supervisor_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_employee_date (employee_id, shift_date),
    INDEX idx_shift_status (status),
    INDEX idx_shift_date (shift_date),
    INDEX idx_supervisor (supervisor_id),
    INDEX idx_shifts_employee_status (employee_id, status),
    CONSTRAINT chk_end_after_start CHECK (end_time IS NULL OR end_time > start_time),
    CONSTRAINT chk_total_hours_positive CHECK (total_hours IS NULL OR total_hours >= 0),
    CONSTRAINT chk_work_hours_valid CHECK (work_hours IS NULL OR (work_hours >= 0 AND work_hours <= total_hours)),
    CONSTRAINT chk_break_minutes_positive CHECK (break_minutes >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Таблица для отслеживания перерывов
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

-- Улучшенная таблица материалов с историей изменений
CREATE TABLE materials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    material_name VARCHAR(200) NOT NULL UNIQUE,
    material_type ENUM('cement', 'lime', 'sand', 'aluminum', 'water', 'additive') NOT NULL,
    current_stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    minimum_stock DECIMAL(10,2) NOT NULL,
    maximum_stock DECIMAL(10,2) NOT NULL,
    unit_of_measure ENUM('kg', 'tonnes', 'liters', 'cubic_meters') NOT NULL,
    storage_location VARCHAR(100),
    supplier VARCHAR(200) NULL,
    cost_per_unit DECIMAL(10,2) NULL,
    last_purchase_date DATE NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,
    FOREIGN KEY (created_by) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_material_type (material_type),
    INDEX idx_stock_level (current_stock, minimum_stock),
    INDEX idx_supplier (supplier),
    CONSTRAINT chk_stock_positive CHECK (current_stock >= 0),
    CONSTRAINT chk_minimum_stock_positive CHECK (minimum_stock > 0),
    CONSTRAINT chk_maximum_greater_minimum CHECK (maximum_stock > minimum_stock),
    CONSTRAINT chk_cost_positive CHECK (cost_per_unit IS NULL OR cost_per_unit > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Таблица истории изменений остатков
CREATE TABLE material_stock_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    material_id INT NOT NULL,
    change_type ENUM('load', 'consumption', 'adjustment', 'waste') NOT NULL,
    quantity_change DECIMAL(10,2) NOT NULL,
    stock_before DECIMAL(10,2) NOT NULL,
    stock_after DECIMAL(10,2) NOT NULL,
    reason TEXT NULL,
    changed_by INT NOT NULL,
    reference_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (material_id) REFERENCES materials(material_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES employees(employee_id) ON DELETE RESTRICT,
    INDEX idx_material_stock_history_created_type (created_at, change_type),
    INDEX idx_change_type (change_type),
    INDEX idx_changed_by (changed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Улучшенная таблица бункеров
CREATE TABLE bunkers (
    bunker_id VARCHAR(50) PRIMARY KEY,
    bunker_name VARCHAR(100) NOT NULL,
    material_id INT NOT NULL,
    current_amount DECIMAL(10,2) DEFAULT 0,
    max_capacity DECIMAL(10,2) NOT NULL,
    min_threshold DECIMAL(10,2) NOT NULL,
    warning_threshold DECIMAL(10,2) NULL,
    location VARCHAR(100),
    production_line VARCHAR(50) NULL,
    status ENUM('active', 'maintenance', 'inactive', 'emergency') DEFAULT 'active',
    last_maintenance DATE NULL,
    next_maintenance DATE NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_operator_id INT NULL,
    FOREIGN KEY (material_id) REFERENCES materials(material_id) ON DELETE RESTRICT,
    FOREIGN KEY (last_operator_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_bunker_status (status),
    INDEX idx_bunker_level (current_amount, min_threshold),
    INDEX idx_production_line (production_line),
    INDEX idx_material_bunkers (material_id),
    CONSTRAINT chk_current_amount_positive CHECK (current_amount >= 0),
    CONSTRAINT chk_max_capacity_positive CHECK (max_capacity > 0),
    CONSTRAINT chk_min_threshold_valid CHECK (min_threshold >= 0 AND min_threshold < max_capacity),
    CONSTRAINT chk_warning_threshold_valid CHECK (warning_threshold IS NULL OR (warning_threshold >= min_threshold AND warning_threshold < max_capacity)),
    CONSTRAINT chk_current_not_exceed_max CHECK (current_amount <= max_capacity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Улучшенная таблица загрузок с исправленными индексами
CREATE TABLE bunker_loads (
    load_id INT AUTO_INCREMENT PRIMARY KEY,
    bunker_id VARCHAR(50) NOT NULL,
    material_id INT NOT NULL,
    loaded_by_id INT NOT NULL,
    quantity_loaded DECIMAL(10,2) NOT NULL,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    quality_check_passed BOOLEAN DEFAULT TRUE,
    quality_checker_id INT NULL,
    batch_number VARCHAR(100) NULL,
    supplier_delivery_id VARCHAR(100) NULL,
    temperature DECIMAL(4,1) NULL,
    humidity DECIMAL(4,1) NULL,
    notes TEXT NULL,
    approved_by_id INT NULL,
    FOREIGN KEY (bunker_id) REFERENCES bunkers(bunker_id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES materials(material_id) ON DELETE CASCADE,
    FOREIGN KEY (loaded_by_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (quality_checker_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    FOREIGN KEY (approved_by_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_bunker_loads_timestamp_bunker (load_timestamp, bunker_id),
    INDEX idx_material_loads (material_id, load_timestamp),
    INDEX idx_loaded_by (loaded_by_id),
    INDEX idx_quality_check (quality_check_passed),
    INDEX idx_batch_number (batch_number),
    CONSTRAINT chk_quantity_loaded_positive CHECK (quantity_loaded > 0),
    CONSTRAINT chk_temperature_valid CHECK (temperature IS NULL OR temperature BETWEEN -50 AND 100),
    CONSTRAINT chk_humidity_valid CHECK (humidity IS NULL OR humidity BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ИСПРАВЛЕННАЯ таблица дефектов
CREATE TABLE defects (
    defect_id INT AUTO_INCREMENT PRIMARY KEY,
    shift_id INT NULL,
    reporter_id INT NOT NULL,
    production_line VARCHAR(100) NOT NULL,
    defect_type ENUM('size', 'crack', 'color', 'strength', 'surface', 'other') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    description TEXT NOT NULL,
    photo_file_id VARCHAR(255) NULL,
    photo_file_size INT NULL,
    batch_number VARCHAR(100) NULL,
    estimated_cost DECIMAL(10,2) NULL,
    affected_quantity INT NULL,
    status ENUM('open', 'in_progress', 'resolved', 'closed', 'rejected') DEFAULT 'open',
    priority ENUM('low', 'normal', 'high', 'urgent') DEFAULT 'normal',
    assigned_to_id INT NULL,
    resolved_by_id INT NULL,
    resolved_at TIMESTAMP NULL,
    resolution_notes TEXT NULL,
    root_cause TEXT NULL,
    preventive_actions TEXT NULL,
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
    INDEX idx_defects_severity_created (severity, created_at),
    CONSTRAINT chk_estimated_cost_positive CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT chk_affected_quantity_positive CHECK (affected_quantity IS NULL OR affected_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Улучшенная таблица рецептов с версионностью
CREATE TABLE recipes (
    recipe_id INT AUTO_INCREMENT PRIMARY KEY,
    recipe_name VARCHAR(200) NOT NULL,
    product_code VARCHAR(50) UNIQUE,
    version VARCHAR(10) NOT NULL DEFAULT '1.0',
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
    cost_per_m3 DECIMAL(10,2) NULL,
    margin_percent DECIMAL(5,2) NULL,
    quality_grade ENUM('A', 'B', 'C') DEFAULT 'B',
    environmental_impact ENUM('low', 'medium', 'high') DEFAULT 'medium',
    created_by INT NULL,
    approved_by INT NULL,
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

-- Таблица производственных партий с исправленными индексами
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
    INDEX idx_production_batches_start_status (start_time, status),
    INDEX idx_operator (operator_id),
    CONSTRAINT chk_planned_volume_positive CHECK (planned_volume_m3 > 0),
    CONSTRAINT chk_actual_volume_positive CHECK (actual_volume_m3 IS NULL OR actual_volume_m3 > 0),
    CONSTRAINT chk_batch_end_after_start CHECK (end_time IS NULL OR end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Таблица уведомлений
CREATE TABLE notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    recipient_id INT NOT NULL,
    sender_id INT NULL,
    notification_type ENUM('defect', 'stock_low', 'shift_alert', 'maintenance', 'general') NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    is_urgent BOOLEAN DEFAULT FALSE,
    related_table VARCHAR(50) NULL,
    related_id INT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL,
    FOREIGN KEY (recipient_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES employees(employee_id) ON DELETE SET NULL,
    INDEX idx_recipient_unread (recipient_id, is_read),
    INDEX idx_notification_type (notification_type),
    INDEX idx_urgent (is_urgent),
    INDEX idx_sent_at (sent_at),
    INDEX idx_notifications_recipient_urgent (recipient_id, is_urgent, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
--  ИСПРАВЛЕННЫЕ ТРИГГЕРЫ
-- =====================================================================

DELIMITER //

-- ИСПРАВЛЕННЫЙ триггер обновления остатков
CREATE TRIGGER trg_update_stock_after_load
    AFTER INSERT ON bunker_loads
    FOR EACH ROW
BEGIN
    -- Объявляем переменные
    DECLARE v_old_bunker_amount DECIMAL(10,2);
    DECLARE v_old_material_stock DECIMAL(10,2);
    DECLARE v_max_capacity DECIMAL(10,2);
    
    -- Получаем текущие значения
    SELECT current_amount, max_capacity 
    INTO v_old_bunker_amount, v_max_capacity
    FROM bunkers WHERE bunker_id = NEW.bunker_id;

    SELECT current_stock INTO v_old_material_stock
    FROM materials WHERE material_id = NEW.material_id;

    -- Проверяем, что не превышаем вместимость
    IF (v_old_bunker_amount + NEW.quantity_loaded) > v_max_capacity THEN
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

    -- Проверяем критические остатки (без вызова процедуры)
    IF v_old_material_stock + NEW.quantity_loaded <= 
       (SELECT minimum_stock FROM materials WHERE material_id = NEW.material_id) THEN
        
        INSERT INTO notifications (recipient_id, notification_type, title, message, is_urgent, related_table, related_id)
        SELECT
            e.employee_id,
            'stock_low',
            'КРИТИЧНЫЙ ОСТАТОК МАТЕРИАЛА',
            CONCAT('Критично низкий остаток материала: ', 
                   (SELECT material_name FROM materials WHERE material_id = NEW.material_id)),
            TRUE,
            'materials',
            NEW.material_id
        FROM employees e
        JOIN employee_roles r ON e.role_id = r.role_id
        WHERE r.role_name IN ('supervisor', 'warehouse_manager') AND e.is_active = TRUE;
    END IF;
END; //

-- Триггер для автоматического завершения смены
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

-- Триггер для автоматического создания уведомлений о критичных дефектах
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

-- Процедура проверки критических остатков
CREATE PROCEDURE GetCriticalStock()
BEGIN
    SELECT
        m.material_name,
        m.current_stock,
        m.minimum_stock,
        m.unit_of_measure,
        ROUND((m.current_stock / m.minimum_stock) * 100, 1) as stock_percentage
    FROM materials m
    WHERE m.current_stock <= m.minimum_stock * 1.2
    ORDER BY (m.current_stock / m.minimum_stock) ASC;
END; //

-- Процедура для получения дневного отчета производства
CREATE PROCEDURE GetDailyProductionReport(IN report_date DATE)
BEGIN
    -- Отчет по производству за день
    SELECT 
        'Смены' as metric_type,
        COUNT(*) as total_count,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
        ROUND(AVG(total_hours), 2) as avg_hours
    FROM shifts 
    WHERE shift_date = report_date
    
    UNION ALL
    
    SELECT 
        'Загрузки материалов' as metric_type,
        COUNT(*) as total_count,
        ROUND(SUM(quantity_loaded), 2) as total_quantity,
        COUNT(DISTINCT bunker_id) as bunkers_used
    FROM bunker_loads 
    WHERE DATE(load_timestamp) = report_date
    
    UNION ALL
    
    SELECT 
        'Дефекты' as metric_type,
        COUNT(*) as total_count,
        COUNT(CASE WHEN severity = 'critical' THEN 1 END) as critical_count,
        COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved_count
    FROM defects 
    WHERE DATE(created_at) = report_date;
END; //

-- Улучшенная процедура поиска рецептов
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
            mixing_time_minutes, density_kg_m3, strength_mpa, version
        FROM recipes
        WHERE is_active = TRUE
        AND (
            recipe_name LIKE CONCAT('%', search_term, '%')
            OR product_code LIKE CONCAT('%', search_term, '%')
            OR product_type LIKE CONCAT('%', search_term, '%')
        )
        ORDER BY recipe_name
        LIMIT 10;
    END IF;
END; //

-- Процедура для получения статистики смены
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
--  ИСПРАВЛЕННЫЕ ПРЕДСТАВЛЕНИЯ (VIEWS)
-- =====================================================================

-- Упрощенное представление критических материалов (без подзапросов с функциями)
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
    m.supplier,
    m.last_purchase_date,
    -- Количество бункеров с этим материалом
    (SELECT COUNT(*) FROM bunkers b WHERE b.material_id = m.material_id AND b.status = 'active') as active_bunkers
FROM materials m
WHERE m.current_stock <= m.minimum_stock * 1.5
ORDER BY stock_percentage ASC;

-- Представление для мониторинга бункеров
CREATE VIEW bunker_status_monitor AS
SELECT
    b.bunker_id,
    b.bunker_name,
    m.material_name,
    b.current_amount,
    b.max_capacity,
    b.min_threshold,
    b.warning_threshold,
    ROUND((b.current_amount / b.max_capacity) * 100, 1) as fill_percentage,
    CASE
        WHEN b.current_amount <= b.min_threshold THEN 'КРИТИЧНЫЙ'
        WHEN b.current_amount <= b.warning_threshold THEN 'ПРЕДУПРЕЖДЕНИЕ'
        WHEN b.current_amount >= b.max_capacity * 0.9 THEN 'ПЕРЕПОЛНЕН'
        ELSE 'НОРМАЛЬНЫЙ'
    END as status_level,
    b.production_line,
    b.status,
    -- Последняя загрузка
    (SELECT MAX(bl.load_timestamp) FROM bunker_loads bl WHERE bl.bunker_id = b.bunker_id) as last_load_time
FROM bunkers b
JOIN materials m ON b.material_id = m.material_id
WHERE b.status = 'active'
ORDER BY fill_percentage ASC;

-- Представление для текущих смен
CREATE VIEW current_shift_status AS
SELECT
    s.shift_id,
    e.full_name,
    e.position,
    s.shift_type,
    s.start_time,
    s.status,
    TIMESTAMPDIFF(MINUTE, s.start_time, NOW()) as minutes_worked,
    s.break_minutes,
    -- Производительность за смену
    (SELECT COUNT(*) FROM bunker_loads bl 
     WHERE bl.loaded_by_id = s.employee_id 
     AND bl.load_timestamp >= s.start_time) as loads_count
FROM shifts s
JOIN employees e ON s.employee_id = e.employee_id
WHERE s.status IN ('active', 'break', 'lunch')
AND DATE(s.shift_date) = CURRENT_DATE;

-- Представление качества продукции
CREATE VIEW quality_summary AS
SELECT
    DATE(d.created_at) as defect_date,
    d.production_line,
    COUNT(*) as total_defects,
    COUNT(CASE WHEN d.severity = 'critical' THEN 1 END) as critical_defects,
    COUNT(CASE WHEN d.severity = 'high' THEN 1 END) as high_defects,
    COUNT(CASE WHEN d.status = 'open' THEN 1 END) as open_defects,
    COUNT(CASE WHEN d.status = 'resolved' THEN 1 END) as resolved_defects,
    -- Процент решенных проблем
    ROUND((COUNT(CASE WHEN d.status = 'resolved' THEN 1 END) / COUNT(*)) * 100, 1) as resolution_rate
FROM defects d
WHERE d.created_at >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)
GROUP BY DATE(d.created_at), d.production_line
ORDER BY defect_date DESC, d.production_line;

-- Расширенная панель управления
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

-- Представление активных смен с деталями
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

-- Представление статистики по дефектам
CREATE VIEW defects_summary AS
SELECT
    d.production_line,
    d.defect_type,
    d.severity,
    COUNT(*) as defect_count,
    COUNT(CASE WHEN d.status = 'open' THEN 1 END) as open_count,
    COUNT(CASE WHEN d.status = 'resolved' THEN 1 END) as resolved_count,
    AVG(CASE WHEN d.resolved_at IS NOT NULL 
         THEN TIMESTAMPDIFF(HOUR, d.created_at, d.resolved_at) 
         END) as avg_resolution_hours,
    SUM(IFNULL(d.estimated_cost, 0)) as total_estimated_cost
FROM defects d
WHERE d.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY d.production_line, d.defect_type, d.severity
ORDER BY defect_count DESC;

-- =====================================================================
--  УПРОЩЕННЫЕ ФУНКЦИИ БЕЗ СЛОЖНОЙ ЛОГИКИ
-- =====================================================================

DELIMITER //

-- Упрощенная функция расчета дней
CREATE FUNCTION GetMaterialStockLevel(p_material_id INT) 
RETURNS VARCHAR(20)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_current_stock DECIMAL(10,2);
    DECLARE v_minimum_stock DECIMAL(10,2);
    DECLARE v_percentage DECIMAL(5,1);
    
    SELECT current_stock, minimum_stock 
    INTO v_current_stock, v_minimum_stock
    FROM materials WHERE material_id = p_material_id;
    
    SET v_percentage = (v_current_stock / v_minimum_stock) * 100;
    
    CASE
        WHEN v_percentage <= 50 THEN RETURN 'КРИТИЧНЫЙ';
        WHEN v_percentage <= 100 THEN RETURN 'НИЗКИЙ';
        WHEN v_percentage <= 150 THEN RETURN 'НОРМАЛЬНЫЙ';
        ELSE RETURN 'ВЫСОКИЙ';
    END CASE;
END; //

-- Упрощенная функция проверки рецепта
CREATE FUNCTION IsRecipeAvailable(p_recipe_id INT) 
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_result BOOLEAN DEFAULT TRUE;
    DECLARE v_cement_stock DECIMAL(10,2);
    DECLARE v_lime_stock DECIMAL(10,2);
    DECLARE v_sand_stock DECIMAL(10,2);
    DECLARE v_aluminum_stock DECIMAL(10,2);
    
    -- Получаем остатки основных материалов
    SELECT 
        COALESCE((SELECT current_stock FROM materials WHERE material_type = 'cement' LIMIT 1), 0),
        COALESCE((SELECT current_stock FROM materials WHERE material_type = 'lime' LIMIT 1), 0),
        COALESCE((SELECT current_stock FROM materials WHERE material_type = 'sand' LIMIT 1), 0),
        COALESCE((SELECT current_stock FROM materials WHERE material_type = 'aluminum' LIMIT 1), 0)
    INTO v_cement_stock, v_lime_stock, v_sand_stock, v_aluminum_stock;
    
    -- Простая проверка - есть ли минимальные остатки
    IF v_cement_stock < 10 OR v_lime_stock < 5 OR v_sand_stock < 20 OR v_aluminum_stock < 0.1 THEN
        SET v_result = FALSE;
    END IF;
    
    RETURN v_result;
END; //

DELIMITER ;

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

-- Добавляем тестовых сотрудников
INSERT INTO employees (telegram_id, full_name, position, department, role_id, email) VALUES
(123456789, 'Иванов Иван Иванович', 'Оператор линии', 'Производственный цех', 1, 'ivanov@aac-factory.com'),
(987654321, 'Петров Петр Петрович', 'Руководитель смены', 'Производственный цех', 2, 'petrov@aac-factory.com'),
(555666777, 'Сидоров Сидор Сидорович', 'Менеджер по качеству', 'Отдел качества', 3, 'sidorov@aac-factory.com'),
(111222333, 'Кузнецов Алексей Петрович', 'Менеджер склада', 'Склад', 4, 'kuznetsov@aac-factory.com');

-- Добавляем материалы с улучшенными данными
INSERT INTO materials (material_name, material_type, current_stock, minimum_stock, maximum_stock, unit_of_measure, storage_location, supplier, cost_per_unit, created_by) VALUES
('Цемент ПЦ500-Д0', 'cement', 100, 20, 200, 'tonnes', 'Склад А', 'СтройЦемент ООО', 4500.00, 4),
('Известь негашеная высшего сорта', 'lime', 50, 15, 100, 'tonnes', 'Склад Б', 'ИзвестьПром ЗАО', 3200.00, 4),
('Песок кварцевый фракция 0.1-0.3', 'sand', 300, 50, 500, 'tonnes', 'Открытая площадка', 'ПескСтрой ООО', 800.00, 4),
('Алюминиевая пудра ПАП-1', 'aluminum', 1, 0.2, 2, 'tonnes', 'Спец. склад', 'МеталлХим ООО', 150000.00, 4),
('Вода техническая', 'water', 10000, 1000, 20000, 'liters', 'Резервуар', 'Водоканал', 0.05, 4);

-- Добавляем бункеры с улучшенными данными
INSERT INTO bunkers (bunker_id, bunker_name, material_id, max_capacity, min_threshold, warning_threshold, location, production_line) VALUES
('БЦ1', 'Бункер цемента №1', 1, 150, 20, 30, 'Линия 1', 'Линия 1'),
('БИ1', 'Бункер извести №1', 2, 80, 15, 25, 'Линия 1', 'Линия 1'),
('БП1', 'Бункер песка №1', 3, 200, 30, 50, 'Линия 1', 'Линия 1'),
('БА1', 'Бункер алюминия №1', 4, 5, 0.5, 1, 'Линия 1', 'Линия 1'),
('БЦ2', 'Бункер цемента №2', 1, 150, 20, 30, 'Линия 2', 'Линия 2'),
('БИ2', 'Бункер извести №2', 2, 80, 15, 25, 'Линия 2', 'Линия 2');

-- Добавляем рецепты с улучшенными данными
INSERT INTO recipes (recipe_name, product_code, version, product_type, density_kg_m3, cement_kg, lime_kg, sand_kg, water_liters, aluminum_powder_kg, mixing_time_minutes, curing_temp_celsius, curing_hours, strength_mpa, cost_per_m3, created_by, approved_by) VALUES
('Блок стеновой D500 B2.5', 'AAC-D500-B25', '2.1', 'block', 500, 280, 120, 1450, 180, 0.450, 8, 190, 12, 2.5, 3500.00, 2, 2),
('Блок стеновой D600 B3.5', 'AAC-D600-B35', '1.8', 'block', 600, 320, 140, 1600, 200, 0.550, 10, 190, 12, 3.5, 4200.00, 2, 2),
('Панель перекрытия D400 B2.0', 'AAC-D400-B20', '1.5', 'panel', 400, 200, 100, 1200, 160, 0.350, 6, 180, 10, 2.0, 3000.00, 2, 2),
('Блок утеплительный D300 B1.5', 'AAC-D300-B15', '1.0', 'insulation', 300, 150, 80, 1000, 140, 0.250, 5, 170, 8, 1.5, 2500.00, 2, 2);

-- Добавляем тестовые смены
INSERT INTO shifts (employee_id, shift_date, shift_type, start_time, status, supervisor_id) VALUES
(1, CURRENT_DATE, 'day', TIMESTAMP(CURRENT_DATE, '08:00:00'), 'active', 2),
(2, CURRENT_DATE, 'day', TIMESTAMP(CURRENT_DATE, '08:00:00'), 'active', NULL);

-- Добавляем тестовые производственные партии
INSERT INTO production_batches (batch_number, recipe_id, production_line, planned_volume_m3, start_time, operator_id, status) VALUES
('BATCH-2025-001', 1, 'Линия 1', 50.0, NOW(), 1, 'in_progress'),
('BATCH-2025-002', 2, 'Линия 2', 75.0, DATE_ADD(NOW(), INTERVAL 2 HOUR), 1, 'planned');

-- Добавляем тестовые дефекты
INSERT INTO defects (reporter_id, production_line, defect_type, severity, description, status, priority) VALUES
(1, 'Линия 1', 'crack', 'medium', 'Обнаружены мелкие трещины в углах блоков', 'open', 'normal'),
(1, 'Линия 1', 'size', 'low', 'Незначительное отклонение размеров', 'in_progress', 'low'),
(3, 'Линия 2', 'strength', 'high', 'Снижение прочности в партии BATCH-2025-001', 'open', 'high');

-- =====================================================================
--  ФИНАЛЬНАЯ ПРОВЕРКА И СТАТИСТИКА
-- =====================================================================

-- Показываем статистику созданных объектов
SELECT 'ИСПРАВЛЕННАЯ БАЗА ДАННЫХ СОЗДАНА УСПЕШНО!' as status;

SELECT 'Таблицы' as object_type, COUNT(*) as count FROM information_schema.tables
WHERE table_schema = 'aac_factory_production'
UNION ALL
SELECT 'Процедуры' as object_type, COUNT(*) as count FROM information_schema.routines
WHERE routine_schema = 'aac_factory_production' AND routine_type = 'PROCEDURE'
UNION ALL
SELECT 'Функции' as object_type, COUNT(*) as count FROM information_schema.routines
WHERE routine_schema = 'aac_factory_production' AND routine_type = 'FUNCTION'
UNION ALL
SELECT 'Триггеры' as object_type, COUNT(*) as count FROM information_schema.triggers
WHERE trigger_schema = 'aac_factory_production'
UNION ALL
SELECT 'Представления' as object_type, COUNT(*) as count FROM information_schema.views
WHERE table_schema = 'aac_factory_production';

-- Проверяем корректность данных
SELECT 'Сотрудники' as table_name, COUNT(*) as records FROM employees
UNION ALL
SELECT 'Материалы' as table_name, COUNT(*) as records FROM materials
UNION ALL
SELECT 'Бункеры' as table_name, COUNT(*) as records FROM bunkers
UNION ALL
SELECT 'Рецепты' as table_name, COUNT(*) as records FROM recipes
UNION ALL
SELECT 'Смены' as table_name, COUNT(*) as records FROM shifts
UNION ALL
SELECT 'Дефекты' as table_name, COUNT(*) as records FROM defects;

-- Тестируем функции
SELECT 
    material_name,
    current_stock,
    minimum_stock,
    GetMaterialStockLevel(material_id) as stock_level
FROM materials
LIMIT 3;

-- =====================================================================
--  КОНЕЦ ИСПРАВЛЕННОЙ СХЕМЫ БД
-- =====================================================================
