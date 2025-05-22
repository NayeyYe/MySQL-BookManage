use BookManage;
show tables ;
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
                     book_id = (select book_id from book where title = target_book limit 1) );
    return borrowers;
end //
delimiter ;


# 计算一个人的总罚款
DROP FUNCTION IF EXISTS Calculate_Fines;

DELIMITER //
CREATE FUNCTION IF NOT EXISTS Calculate_Fines(target_name varchar(20))
    returns int
    reads sql data
BEGIN
    declare fines int;

    select SUM(fr.fine) into fines
    FROM fine_record fr
        JOIN borrower b ON fr.borrower_id = b.id
    WHERE fr.is_pay = FALSE and b.name = target_name
    GROUP BY fr.borrower_id;

    if fines is null
        then return 0;
    else
        return fines;
    end if;
END //
DELIMITER ;


#  判断一个人的信息是否存在于学生/教师表中，用于注册系统
DELIMITER //
CREATE FUNCTION check_identity_exists(
    p_id VARCHAR(13),       -- 输入ID（支持13位学生ID或8位教师ID）
    p_name VARCHAR(50),     -- 姓名
    p_identity_id TINYINT   -- 身份标识（1学生 2教师）
)
    RETURNS BOOLEAN
    DETERMINISTIC
    READS SQL DATA
BEGIN
    DECLARE v_exists BOOLEAN DEFAULT FALSE;

    -- 根据身份类型选择查询对应表
    CASE p_identity_id
        WHEN 1 THEN  -- 学生验证
        SELECT COUNT(*) INTO v_exists
        FROM student
        WHERE stu_id = p_id
          AND name = p_name
        LIMIT 1;

        WHEN 2 THEN  -- 教师验证
        SELECT COUNT(*) INTO v_exists
        FROM teacher
        WHERE id = LEFT(p_id, 8)  -- 教师ID固定8位
          AND name = p_name
        LIMIT 1;

        ELSE
            SET v_exists = FALSE;
        END CASE;

    RETURN v_exists > 0;
END//
DELIMITER ;

