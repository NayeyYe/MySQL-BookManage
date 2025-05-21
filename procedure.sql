use BookManage;
# ------------------创建存储过程---------------------
# 更新借阅人能不能借阅
drop procedure if exists update_is_can_borrow;
delimiter \\
create procedure if not exists update_is_can_borrow(in borrower_id int)
begin
    declare max_borrowed_books int;
    declare borrowed_num int;

    select borrower.borrowed_num into borrowed_num from borrower where id = borrower_id;
    select category.max_borrowed_books into max_borrowed_books from category
        join borrower on category.category_id = borrower.category_id
    where borrower.id = borrower_id;
    if borrowed_num < max_borrowed_books
        then update borrower set is_can_borrow=TRUE where id=borrower_id;
    else
        update borrower set is_can_borrow=FALSE where id=borrower_id;
    end if;
end \\
delimiter ;


# 查询一个人的基本借书信息
delimiter //
drop procedure if exists select_person;
create procedure if not exists select_person(in target_name varchar(20))
begin
    select borrower.id as 借阅人id,
           borrower.name as 借阅人名字 ,
           borrower.PhoneNumber as 电话号码,
           category.category as 身份 ,
           borrower.borrowed_num as 已借阅书籍数目,
           borrower.is_can_borrow as 借书权限,
           count_fine_record(borrower.id) as 现有罚款记录数量
    from borrower
             join category on borrower.category_id = category.category_id
    where borrower.name = target_name;
end //
delimiter ;


# 查询一本书的借阅信息
delimiter //
drop procedure if exists select_book;
create procedure if not exists select_book(in target_book varchar(255))
begin
    select book.book_id as 图书id,
           book.title as 书名,
           book.isbn as isbn码,
           who_borrow_it(target_book) as 正在借阅
    from book where title = target_book;
end //
delimiter ;


# 查找一个人的罚款记录
drop procedure if exists select_fine_record;
delimiter //
create procedure if not exists select_fine_record(in target_name int)
begin
    select fine_record.fine_id as 罚款记录id,
           fine_record.record_id as 借阅记录id,
           borrower.name as 借阅人,
           book.title as 书名,
           fine_record.borrow_date as 借阅日期,
           fine_record.due_date as 应还日期,
           fine_record.overdue_days as 逾期天数,
           fine_record.is_return as 是否归还,
           fine_record.fine as 罚款数,
           fine_record.is_pay as 是否支付
    from fine_record
             join borrower on fine_record.borrower_id = borrower.id
             join book on fine_record.book_id = book.book_id
    where target_name = borrower.name;
end //
delimiter ;


# 每天要计算罚款, 在event中调用
DELIMITER //
DROP PROCEDURE IF EXISTS DailyCalculateFines;
CREATE PROCEDURE DailyCalculateFines()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE temp_record_id INT;
    DECLARE temp_due_date DATE;
    DECLARE temp_overdue_days INT;
    DECLARE temp_fine_amount INT;

    -- 声明游标：获取所有未归还且未缴纳罚款的记录
    DECLARE cur_fines CURSOR FOR
        SELECT
            fr.record_id,
            fr.due_date,
            -- 动态计算逾期天数（避免依赖表中overdue_days字段）
            GREATEST(DATEDIFF(CURDATE(), fr.due_date), 0) AS current_overdue
        FROM fine_record fr
        WHERE fr.is_return = FALSE
          AND fr.is_pay = FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- 开启事务
    START TRANSACTION;

    -- 更新所有记录的逾期天数
    UPDATE fine_record
    SET overdue_days = GREATEST(DATEDIFF(CURDATE(), due_date), 0)
    WHERE is_return = FALSE
      AND is_pay = FALSE;

    OPEN cur_fines;

    read_loop: LOOP
        FETCH cur_fines INTO temp_record_id, temp_due_date, temp_overdue_days;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- 计算罚款（分段累加）
        SET temp_fine_amount =
                CASE
                    WHEN temp_overdue_days <= 30 THEN temp_overdue_days * 1
                    WHEN temp_overdue_days <= 90 THEN 30 * 1 + (temp_overdue_days - 30) * 3
                    ELSE 30 * 1 + 60 * 3 + (temp_overdue_days - 90) * 5
                    END;

        -- 更新罚款金额
        UPDATE fine_record
        SET fine = temp_fine_amount
        WHERE record_id = temp_record_id;
    END LOOP;

    CLOSE cur_fines;

    -- 提交事务
    COMMIT;
END //
DELIMITER ;


# 查询全部罚款信息
delimiter //
drop procedure if exists select_fines;
create procedure if not exists select_fines()
begin
    SELECT
        b.name AS '姓名',
        SUM(fr.fine) AS '总罚款',
        b.PhoneNumber AS '电话'
    FROM fine_record fr
             JOIN borrower b ON fr.borrower_id = b.id
    WHERE fr.is_pay = FALSE
    GROUP BY fr.borrower_id;
end //
delimiter ;


# 查询某个人的罚款信息
delimiter //
drop procedure if exists select_fine;
create procedure if not exists select_fine(in target_name varchar(255))
begin
    SELECT
        b.name AS '姓名',
        SUM(fr.fine) AS '总罚款',
        b.PhoneNumber AS '电话'
    FROM fine_record fr
             JOIN borrower b ON fr.borrower_id = b.id
    WHERE fr.is_pay = FALSE and b.name=target_name
    GROUP BY fr.borrower_id;
end //
delimiter ;
