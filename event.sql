# 启用事件调度器
use bookmanage;
SET GLOBAL event_scheduler = ON;


# 每天自动计算借阅记录和罚款记录中的天数
DELIMITER //
CREATE EVENT IF NOT EXISTS AutoUpdateOverdueAndFines
    ON SCHEDULE EVERY 1 DAY STARTS '2024-01-01 00:00:00'
    DO
    BEGIN
        -- 更新借阅记录中的逾期天数
        UPDATE borrow_record
        SET overdue_days = GREATEST(DATEDIFF(CURDATE(), due_date), 0)
        WHERE is_return = FALSE;
        -- 插入新的罚款记录（仅当借阅逾期且未生成罚款时）
        INSERT INTO fine_record (record_id, borrower_id, book_id, borrow_date, due_date, is_return, fine, is_pay)
        SELECT
            br.record_id,
            br.borrower_id,
            br.book_id,
            br.borrow_date,
            br.due_date,
            FALSE,
            0,
            FALSE
        FROM borrow_record br
                 LEFT JOIN fine_record fr ON br.record_id = fr.record_id
        WHERE br.is_return = FALSE
          AND br.due_date < CURDATE()  -- 已逾期
          AND fr.record_id IS NULL;    -- 未生成罚款记录
    END //
DELIMITER ;


# 每天自己计算罚款金额
CREATE EVENT IF NOT EXISTS AutoDailyCalculateFines
    ON SCHEDULE EVERY 1 DAY STARTS '2024-01-01 00:00:00'  -- 每天凌晨执行
    DO
    BEGIN
        CALL DailyCalculateFines();  -- 调用存储过程
    END;