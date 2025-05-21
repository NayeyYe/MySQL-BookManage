-- 启用事件调度器（需MySQL权限）
SET GLOBAL event_scheduler = ON;

-- 创建事件
CREATE EVENT IF NOT EXISTS AutoDailyCalculateFines
    ON SCHEDULE EVERY 1 DAY STARTS '2024-01-01 00:00:00'  -- 每天凌晨执行
    DO
    BEGIN
        CALL DailyCalculateFines();  -- 调用存储过程
    END;