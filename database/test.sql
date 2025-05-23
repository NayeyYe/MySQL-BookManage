-- file: test.sql
USE bookmanage;

-- ---------------------------
-- 存储过程测试
-- ---------------------------

-- 测试1: 更新借阅权限
CALL update_is_can_borrow(1);
SELECT id, name, borrowed_num, is_can_borrow FROM borrower WHERE id = 1;

-- 测试2: 查询用户借阅信息
CALL select_person('张伟');

-- 测试3: 查询图书借阅信息
CALL select_book('三体');

-- 测试4: 生成借阅记录（先重置环境）
UPDATE book SET remain = 5 WHERE book_id = 1;
CALL borrow_book(1, 1);
SELECT * FROM borrow_record WHERE borrower_id = 1 AND book_id = 1;
SELECT remain FROM book WHERE book_id = 1;

-- 测试5: 注册用户（正常情况）
CALL register_user('测试用户', '13812341234', 1, '2025010101001', 'Test@123');
SELECT * FROM borrower WHERE name = '测试用户';

-- 测试6: 注册用户（异常情况-重复注册）
CALL register_user('张伟', '13597646338', 1, '2025010101001', 'Test@123');

-- ---------------------------
-- 函数测试
-- ---------------------------

-- 测试1: 罚款记录数量查询
SELECT count_fine_record(1) AS 用户1的未支付罚款数;

-- 测试2: 图书借阅者查询
SELECT who_borrow_it('三体') AS 当前借阅者;

-- 测试3: 罚款金额计算
SELECT Calculate_Fines('张伟') AS 张伟的总罚款;

-- 测试4: 身份验证函数
SELECT check_identity_exists_in_origin('2025010101001', '张伟', 1) AS 学生身份验证;

-- ---------------------------
-- 触发器测试
-- ---------------------------

-- 测试1: 借阅超出库存（先设置库存为0）
UPDATE book SET remain = 0 WHERE book_id = 1;
INSERT INTO borrow_record (borrower_id, book_id, borrow_date, due_date)
VALUES (1, 1, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY));

-- 测试2: 正常还书操作（恢复库存）
UPDATE book SET remain = 5 WHERE book_id = 1;
INSERT INTO borrow_record (borrower_id, book_id, borrow_date, due_date, is_return)
VALUES (1, 1, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), FALSE);
UPDATE borrow_record SET is_return = TRUE WHERE record_id = LAST_INSERT_ID();
SELECT remain FROM book WHERE book_id = 1;

-- ---------------------------
-- 事件测试
-- ---------------------------

-- 手动执行事件关联的存储过程
CALL UpdateOverdueAndFines();
CALL DailyCalculateFines();

-- 验证结果
SELECT * FROM fine_record WHERE overdue_days > 0 LIMIT 5;

-- ---------------------------
-- 登录系统测试
-- ---------------------------

-- 测试1: 正常手机登录
CALL login_by_phone('13597646338', '13Password,');

-- 测试2: 错误密码登录
CALL login_by_phone('13597646338', 'wrongpassword');

-- 测试3: 管理员登录
CALL login_admin('root', '13Password,');

-- ---------------------------
-- 借还书系统测试
-- ---------------------------

-- 测试1: 获取当前借阅
CALL get_current_borrows(1);

-- 测试2: 获取借阅历史
CALL get_borrow_history(1);

-- 测试3: 获取罚款记录
CALL get_fine_records(1);

-- 测试4: 支付罚款
UPDATE fine_record SET is_pay = FALSE WHERE fine_id = 1;
CALL pay_fine(1);
SELECT is_pay FROM fine_record WHERE fine_id = 1;

-- ---------------------------
-- 管理功能测试
-- ---------------------------

-- 测试1: 获取所有用户
CALL get_all_users();

-- 测试2: 获取所有借阅记录
CALL get_all_borrows();

-- 测试3: 切换用户状态
CALL toggle_user_status(1);
SELECT is_can_borrow FROM borrower WHERE id = 1;

-- 测试完成后重置环境
UPDATE borrower SET is_can_borrow = TRUE WHERE id = 1;
DELETE FROM borrower WHERE name = '测试用户';
