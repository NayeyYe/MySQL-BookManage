use bookmanage;
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
create procedure if not exists select_fine_record(in target_name varchar(255))
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


delimiter //
drop procedure if exists UpdateOverdueAndFines;
create procedure if not exists UpdateOverdueAndFines()
begin
    -- 更新借阅记录中的逾期天数
    UPDATE borrow_record
    SET overdue_days = GREATEST(DATEDIFF(CURDATE(), due_date), 0)
    WHERE is_return = FALSE;
    -- 插入新的罚款记录（仅当借阅逾期且未生成罚款时）
    INSERT INTO fine_record (record_id, borrower_id, book_id, borrow_date, due_date, is_return, fine, is_pay, overdue_days)
    SELECT
        br.record_id,
        br.borrower_id,
        br.book_id,
        br.borrow_date,
        br.due_date,
        FALSE,
        0,
        FALSE,
        br.overdue_days
    FROM borrow_record br
             LEFT JOIN fine_record fr ON br.record_id = fr.record_id
    WHERE br.is_return = FALSE
      AND br.due_date < CURDATE()  -- 已逾期
      AND fr.record_id IS NULL;    -- 未生成罚款记录
end //
delimiter ;

# ----------------------注册系统---------------------------
# 注册学生用户或者教师用户
DELIMITER //
drop procedure if exists register_identity_user;
CREATE PROCEDURE if not exists register_identity_user(
    IN p_name VARCHAR(50),        -- 姓名
    IN p_phone VARCHAR(20),       -- 手机号
    IN p_category TINYINT,        -- 身份类型（1学生 2教师）
    IN p_origin_id VARCHAR(20),    -- 原始ID（学号/工号）
    IN p_plain_password varchar(255)
)
BEGIN
    DECLARE v_valid BOOLEAN;

    -- 验证身份合法性
    SELECT check_identity_exists_in_origin(p_origin_id, p_name, p_category)
    INTO v_valid;

    IF NOT v_valid THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '身份验证失败：ID与姓名不匹配';
    END IF;

    -- 检查手机号是否重复
    SELECT check_identity_exists_in_borrower(p_name, p_phone)
    INTO v_valid;
    IF v_valid THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '用户已被注册';
    END IF;

    -- 插入用户数据
    INSERT INTO borrower
    (name, PhoneNumber, category_id, origin_id, registration_date)
    VALUES
    (p_name, p_phone, p_category, p_origin_id, current_date);

    insert into user_info(id, password_hash) values (LAST_INSERT_ID(), sha2(p_plain_password, 256));
END//
DELIMITER ;


# 校外人员注册
DELIMITER //
drop procedure if exists register_external_user;
CREATE PROCEDURE if not exists register_external_user(
    IN p_name VARCHAR(50),        -- 姓名
    IN p_phone VARCHAR(20),       -- 手机号
    IN p_category TINYINT,         -- 身份类型（3为校外用户）
    IN p_plain_password varchar(255)
)
BEGIN
    declare v_valid boolean;
    -- 检查手机号是否重复
    SELECT check_identity_exists_in_borrower(p_name, p_phone)
    INTO v_valid;
    IF v_valid THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '用户已被注册';
    END IF;

    -- 插入用户数据（origin_id置空）
    INSERT INTO borrower
    (name, PhoneNumber, category_id, origin_id, registration_date)
    VALUES
    (p_name, p_phone, p_category, NULL, current_date);

    insert into user_info(id, password_hash) values (LAST_INSERT_ID(), sha2(p_plain_password, 256));
END//
DELIMITER ;


# 两个注册存储过程的集合
DELIMITER //
drop procedure if exists register_user;
CREATE PROCEDURE if not exists register_user(
    IN p_name VARCHAR(50),
    IN p_phone VARCHAR(20),
    IN p_category TINYINT,
    IN p_origin_id VARCHAR(20), -- 可为NULL
    IN p_plain_password varchar(255)
)
BEGIN
    -- 参数有效性检查
    IF p_category IN (1,2) AND p_origin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '学生/教师必须提供原始ID';
    END IF;
    -- 路由到对应注册逻辑
    CASE
        WHEN p_category IN (1,2) THEN
            CALL register_identity_user(p_name, p_phone, p_category, p_origin_id, p_plain_password);
        ELSE
            CALL register_external_user(p_name, p_phone, p_category, p_plain_password);
    END CASE;
END//
DELIMITER ;


# 手机号密码登录
DELIMITER //
drop procedure if exists login_by_phone;
CREATE PROCEDURE if not exists login_by_phone(
    IN p_phone VARCHAR(20),
    IN p_plain_password VARCHAR(255))
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_stored_hash VARCHAR(255);

    DECLARE v_name VARCHAR(20);

    -- 验证手机号存在性
    IF NOT check_identity_exists_in_borrower_1(p_phone) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '用户不存在';
    END IF;

    -- 获取用户凭证
    SELECT b.id as id , ui.password_hash, b.name as name
    INTO v_user_id, v_stored_hash, v_name
    FROM borrower b
    JOIN user_info ui ON b.id = ui.id
    WHERE b.PhoneNumber = p_phone;

    -- 密码验证
    IF v_stored_hash != sha2(p_plain_password, 256) THEN
        INSERT INTO login_logging(id, name, login_time)
        VALUES (v_user_id, v_name, NOW());

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '密码错误';
    END IF;

    -- 记录成功日志
    INSERT INTO login_logging(id, name, login_time)
    VALUES (v_user_id, v_name, NOW());

    SELECT
        b.id AS id,
        b.name AS name,
        b.category_id AS category
    FROM borrower b
    WHERE b.PhoneNumber = p_phone;
END //
DELIMITER ;


# 教职工ID, 学号, 密码登录
DELIMITER //
drop procedure if exists login_by_origin_id;
CREATE PROCEDURE if not exists login_by_origin_id(
    IN p_origin_id VARCHAR(13),
    IN p_plain_password VARCHAR(255)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_stored_hash VARCHAR(255);
    DECLARE v_name VARCHAR(20);
    DECLARE v_category TINYINT;

    -- 验证原始ID存在性
    IF NOT check_identity_exists_in_borrower_2(p_origin_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '用户不存在';
    END IF;

    -- 获取用户凭证和身份
    SELECT b.id as id , ui.password_hash, b.name as name , b.category_id
    INTO v_user_id, v_stored_hash, v_name, v_category
    FROM borrower b
    JOIN user_info ui ON b.id = ui.id
    WHERE b.origin_id = p_origin_id;

    -- 身份验证（仅允许学生/教师）
    IF v_category NOT IN (1,2) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '非法登录方式';
    END IF;


    -- 密码验证
    IF v_stored_hash != sha2(p_plain_password, 256) THEN
        INSERT INTO login_logging(id, name, login_time)
        VALUES (v_user_id, v_name, NOW());

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '密码错误';
    END IF;

    -- 记录日志
    INSERT INTO login_logging(id, name, login_time)
    VALUES (v_user_id, v_name, NOW());

    SELECT
        b.id AS id,
        b.name AS name,
        b.category_id AS category
    FROM borrower b
    WHERE b.origin_id = p_origin_id;
END//
DELIMITER ;


# 管理员密码登录
DELIMITER //
drop procedure if exists login_admin;
CREATE PROCEDURE if not exists login_admin(
    IN p_name VARCHAR(20),
    IN p_plain_password VARCHAR(255))
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_stored_hash VARCHAR(255);
    DECLARE v_name VARCHAR(20);

    -- 验证手机号存在性
    IF NOT check_identity_exists_in_borrower_3(p_name) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '用户不存在';
    END IF;

    -- 获取用户凭证
    SELECT b.id as id, ui.password_hash, b.name as name
    INTO v_user_id, v_stored_hash, v_name
    FROM borrower b
    JOIN user_info ui ON b.id = ui.id
    WHERE b.name = p_name;

    -- 密码验证
    IF v_stored_hash != sha2(p_plain_password, 256) THEN
        INSERT INTO login_logging(id, name, login_time)
        VALUES (v_user_id, v_name, NOW());

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '密码错误';
    END IF;

    -- 记录成功日志
    INSERT INTO login_logging(id, name, login_time)
    VALUES (v_user_id, v_name, NOW());

    SELECT
        b.id AS id,
        b.name AS name,
        b.category_id AS category
    FROM borrower b
    WHERE b.name = p_name;
END //
DELIMITER ;


# 借书系统
# 获取全部图书的基本信息
drop procedure if exists get_book_baseinfo;
delimiter //
create procedure if not exists get_book_baseinfo()
begin
    SELECT
        b.book_id, b.title, b.remain, GROUP_CONCAT(c.category SEPARATOR ', ') AS categories
        FROM book b
        LEFT JOIN bookCategoryRelation r ON b.book_id = r.book_id
        LEFT JOIN bookCategory c ON r.category_id = c.category_id
        GROUP BY b.book_id;
end //
delimiter ;


# 借书
DELIMITER //
DROP PROCEDURE IF EXISTS borrow_book;
CREATE PROCEDURE borrow_book(
    IN p_borrower_id INT,
    IN p_book_id INT
)
BEGIN

    -- 更新图书余量
    UPDATE book SET remain = remain - 1
    WHERE book_id = p_book_id;

    -- 更新借阅数量
    UPDATE borrower SET borrowed_num = borrowed_num + 1
    WHERE id = p_borrower_id;

    -- 插入借阅记录（触发器的校验仍然生效）
    INSERT INTO borrow_record (
        borrower_id,
        book_id,
        borrow_date,
        due_date
    ) VALUES (
        p_borrower_id,
        p_book_id,
        CURDATE(),
        DATE_ADD(CURDATE(), INTERVAL
            (SELECT borrow_period
             FROM category
             WHERE category_id = (SELECT category_id FROM borrower WHERE id = p_borrower_id)) DAY)
    );

    -- 更新借阅状态
    CALL update_is_can_borrow(p_borrower_id);

    COMMIT;
END //
DELIMITER ;
