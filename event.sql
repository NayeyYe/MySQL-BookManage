# 启用事件调度器
use bookmanage;
SET GLOBAL event_scheduler = ON;


# 每天自动计算借阅记录和罚款记录中的天数
DELIMITER //
CREATE EVENT IF NOT EXISTS AutoUpdateOverdueAndFines
    ON SCHEDULE EVERY 1 DAY STARTS '2024-01-01 00:00:00'
    DO
    BEGIN
       call UpdateOverdueAndFines();
    END //
DELIMITER ;


# 每天自己计算罚款金额
CREATE EVENT IF NOT EXISTS AutoDailyCalculateFines
    ON SCHEDULE EVERY 1 DAY STARTS '2024-01-01 00:00:00'  -- 每天凌晨执行
    DO
    BEGIN
        CALL DailyCalculateFines();  -- 调用存储过程
    END;