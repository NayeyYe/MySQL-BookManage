use BookManage;
set global log_bin_trust_function_creators =TRUE;
# ------------------ 创建储存函数 ---------------------
# 查找某人有多少罚款记录
drop function if exists count_fine_record;
DELIMITER //
create function if not exists count_fine_record(target_id int)
    returns int
    reads sql data
begin
    declare fine_num int;
    select count(*) into fine_num from fine_record where borrower_id = target_id and is_return=FALSE;
    return fine_num;
end //
delimiter ;


# 查询一个人的基本借书信息
drop function if exists select_person;

delimiter //
create function if not exists select_person(target_name varchar(20))
    returns bool
    reads sql data
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
    return TRUE;
end //
delimiter ;


# 查询一本书正在被哪些人借阅，返回字符串
drop function if exists who_borrow_it;
delimiter //
create function if not exists who_borrow_it(target_book varchar(255))
    returns varchar(255)
    reads sql data
begin
    declare borrowers varchar(255);

    select group_concat(name SEPARATOR ',') into borrowers
    from borrower
    where id in (select borrower_id
                 from borrow_record
                 where is_return=FALSE and
                     book_id = (select book_id from book where title = target_book));
    return borrowers;
end //
delimiter ;


# 查询一本书的借阅信息
drop function if exists select_book;
delimiter //
create function if not exists select_book(target_book varchar(255))
    returns bool
    reads sql data
begin
    select book.book_id as 图书id,
           book.title as 书名,
           book.isbn as isbn码,
           who_borrow_it(target_book) as 正在借阅
    from book where title = target_book;

    return TRUE;
end //
delimiter ;


# 查找一个人的罚款记录
drop function if exists select_fine_record;
delimiter //
create function if not exists select_fine_record(target_name int)
    returns bool
    reads sql data
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

    return TRUE;
end //
delimiter ;


# 计算罚款
DROP FUNCTION IF EXISTS Calculate_Fines;

DELIMITER //
CREATE FUNCTION IF NOT EXISTS Calculate_Fines(target_name varchar(20))
    returns int
    reads sql data
BEGIN
    declare fines int;
    DECLARE done INT DEFAULT FALSE;
    DECLARE temp_borrower_id INT;
    DECLARE temp_overdue_days INT;
    DECLARE temp_fine_amount INT;
    DECLARE temp_record_id INT;

    -- 声明游标：获取所有未归还且未缴纳罚款的记录
    DECLARE cur_fines CURSOR FOR
        SELECT record_id, borrower_id, overdue_days
        FROM fine_record
        WHERE is_return = FALSE AND is_pay = FALSE;

    -- 定义异常处理
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur_fines;

    read_loop: LOOP
        FETCH cur_fines INTO temp_record_id, temp_borrower_id, temp_overdue_days;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- 根据逾期天数计算罚款
        SET temp_fine_amount =
                CASE
                    WHEN temp_overdue_days <= 30 THEN temp_overdue_days * 1
                    WHEN temp_overdue_days <= 90 THEN 30 * 1 + (temp_overdue_days - 30) * 3
                    ELSE 30 * 1 + 60 * 3 + (temp_overdue_days - 90) * 5
                    END;

        -- 更新罚款金额到 fine_record 表
        UPDATE fine_record
        SET fine = temp_fine_amount
        WHERE record_id = temp_record_id;
    END LOOP;

    CLOSE cur_fines;

    -- 显示所有需要缴纳罚款的借阅人信息
    SELECT
        b.name AS '姓名',
        SUM(fr.fine) AS '总罚款',
        b.PhoneNumber AS '电话'
    FROM fine_record fr
         JOIN borrower b ON fr.borrower_id = b.id
    WHERE fr.is_pay = FALSE
    GROUP BY fr.borrower_id;

    select SUM(fr.fine) into fines
    FROM fine_record fr
        JOIN borrower b ON fr.borrower_id = b.id
    WHERE fr.is_pay = FALSE and b.name = target_name
    GROUP BY fr.borrower_id;

    return fines;
END //
DELIMITER ;