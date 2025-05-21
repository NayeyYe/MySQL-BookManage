use BookManage;
# ------------------创建触发器---------------------
# 成功借书之后, 借阅人借书的数量要+1, 总图书中的图书剩余量要-1
drop trigger if exists after_borrow_insert;
delimiter //
CREATE TRIGGER if not exists after_borrow_insert
    AFTER INSERT ON borrow_record
    FOR EACH ROW
BEGIN
    -- 更新借阅人已借数量
    UPDATE borrower
    SET borrowed_num = borrowed_num + 1
    WHERE id = NEW.borrower_id;

    -- 更新图书剩余量
    UPDATE book
    SET remain = remain - 1
    WHERE book_id = NEW.book_id;

    call update_is_can_borrow(NEW.borrower_id);

END//
delimiter ;

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