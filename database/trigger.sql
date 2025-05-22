use BookManage;
# ------------------创建触发器---------------------
# 借书之前, 借阅人借书的数量要+1, 总图书中的图书剩余量要-1
DROP TRIGGER IF EXISTS before_borrow_insert;
DELIMITER //
CREATE TRIGGER before_borrow_insert
    BEFORE INSERT ON borrow_record
    FOR EACH ROW
BEGIN
    DECLARE current_remain INT;
    DECLARE current_is_can_borrow BOOLEAN;
    DECLARE max_allowed INT;
    DECLARE existing_borrow INT;


    -- 检查是否存在未归还的相同书籍借阅记录
    SELECT COUNT(*) INTO existing_borrow
    FROM borrow_record
    WHERE borrower_id = NEW.borrower_id
      AND book_id = NEW.book_id
      AND not is_return;

    IF existing_borrow > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '借阅失败：该用户已有未归还的相同书籍';
    END IF;


    -- 检查图书剩余量
    SELECT remain INTO current_remain
    FROM book
    WHERE book_id = NEW.book_id;

    IF current_remain <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '借书失败：图书库存不足';
    END IF;

    -- 检查借阅人状态及借阅上限
    SELECT is_can_borrow, category.max_borrowed_books INTO current_is_can_borrow, max_allowed
    FROM borrower
             JOIN category ON borrower.category_id = category.category_id
    WHERE borrower.id = NEW.borrower_id;

    IF NOT current_is_can_borrow THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '借书失败：超出借书量';
    END IF;

    IF (SELECT borrowed_num FROM borrower WHERE id = NEW.borrower_id) >= max_allowed THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '借书失败：超过该用户类别最大借阅量';
    END IF;

    -- 预更新数据（保证事务原子性）
    UPDATE book
    SET remain = remain - 1
    WHERE book_id = NEW.book_id;

    UPDATE borrower
    SET borrowed_num = borrowed_num + 1
    WHERE id = NEW.borrower_id;

    -- 同步更新可借状态
    CALL update_is_can_borrow(NEW.borrower_id);
END//
DELIMITER ;


# 成功还书之后，借阅人已经借阅的数量-1， 图书剩余量+1
drop trigger if exists after_return_update;
delimiter //
CREATE TRIGGER if not exists after_return_update
    AFTER UPDATE ON borrow_record
    FOR EACH ROW
BEGIN
    IF NEW.is_return = TRUE AND OLD.is_return = FALSE THEN
        -- 更新借阅人已借数量
        UPDATE borrower
        SET borrowed_num = borrowed_num - 1
        WHERE id = NEW.borrower_id;

        -- 更新图书剩余量
        UPDATE book
        SET remain = remain + 1
        WHERE book_id = NEW.book_id;

    END IF;

    call update_is_can_borrow(NEW.borrower_id);
END//
delimiter ;