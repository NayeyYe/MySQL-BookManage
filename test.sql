use bookmanage;

-- 初始化测试环境
START TRANSACTION;
-- ----------------------------
-- 第一部分：基础数据准备
-- ----------------------------
INSERT INTO category (category, max_borrowed_books, borrow_period) VALUES
                                                                       ('学生', 3, 14),
                                                                       ('教师', 5, 30),
                                                                       ('管理员', 1, 7);
INSERT INTO publisher (publisher) VALUES
                                      ('清华大学出版社'),
                                      ('人民邮电出版社');
INSERT INTO bookCategory (category) VALUES
                                        ('计算机'),
                                        ('文学'),
                                        ('数学');
INSERT INTO author (author) VALUES
                                ('李华'),
                                ('王明'),
                                ('张强');
-- ----------------------------
-- 第二部分：核心功能测试
-- ----------------------------
-- 测试用例1：完整借阅周期测试
SET @test_name = '测试用户1';
-- 正确方式：分开插入借阅人并获取ID
-- 插入第一个借阅人
INSERT INTO borrower (name, PhoneNumber, category_id, registration_date)
VALUES (@test_name, '13800000001', 1, CURDATE());


INSERT INTO book (title, isbn, publisher_id, publication_year, total, remain, location) VALUES
                                                                                            ('数据库系统', '978-7-302-12345-7', 1, 2020, 5, 5, 'A101'),
                                                                                            ('高等数学', '978-7-115-67890-2', 2, 2021, 3, 3, 'B205');

-- 测试插入作者和分类关系
INSERT INTO bookAuthorRelation (book_id, author_id) VALUES
                                                        (1, 1),
                                                        (1, 2),
                                                        (2, 3);

INSERT INTO bookCategoryRelation (book_id, category_id) VALUES
                                                            (1, 1),
                                                            (2, 3);

-- ----------------------------
-- 第三部分：功能验证
-- ----------------------------
-- 验证测试1：正常借书流程
SET @borrower_id = LAST_INSERT_ID();  -- 测试用户1
SET @book_id = 1;

-- 执行借书
-- 使用正确的借阅人ID变量
INSERT INTO borrow_record (borrower_id, book_id, borrow_date, due_date) VALUES
                                                                            (@borrower_id, 1, CURDATE(), CURDATE() + INTERVAL 14 DAY),  -- ✅ 使用第一个借阅人
                                                                            (@borrower_id, 2, CURDATE(), CURDATE() + INTERVAL 30 DAY);   -- ✅ 使用第二个借阅人
select * from borrower;
select * from book;

-- 验证触发器生效
SELECT '【验证1】借书后图书剩余量应为4' AS test_case;
SELECT remain FROM book WHERE book_id = @book_id;

SELECT '【验证2】借阅人已借数量应为1' AS test_case;
SELECT borrowed_num FROM borrower WHERE id = @borrower_id;

-- ----------------------------
-- 测试用例2：借阅限制测试
-- 尝试借阅超过限额
INSERT INTO borrow_record (borrower_id, book_id, borrow_date, due_date) VALUES
                                                                            (@borrower_id, @book_id, CURDATE(), CURDATE() + INTERVAL 14 DAY),
                                                                            (@borrower_id, @book_id, CURDATE(), CURDATE() + INTERVAL 14 DAY),
                                                                            (@borrower_id, @book_id, CURDATE(), CURDATE() + INTERVAL 14 DAY);
select * from borrower;
SELECT '【验证3】当借阅达到上限时应禁止借书' AS test_case;
SELECT is_can_borrow FROM borrower WHERE id = @borrower_id;

-- ----------------------------
-- 测试用例3：还书流程测试
-- 先更新为已归还
select * from borrow_record;
select * from book where book_id=1;
UPDATE borrow_record SET
                         is_return = TRUE,
                         return_date = CURDATE()
WHERE record_id = 1;
select * from borrow_record;
select * from book where book_id=1;
select * from borrower;


SELECT '【验证4】还书后图书剩余量恢复为2' AS test_case;
SELECT remain FROM book WHERE book_id = @book_id;

SELECT '【验证5】借阅人已借数量应减为4' AS test_case;
SELECT borrowed_num FROM borrower WHERE id = @borrower_id;

-- ----------------------------
-- 第四部分：存储过程测试
-- 测试存储过程：查询借阅人信息
SELECT '【验证6】存储过程select_person应返回正确信息' AS test_case;
CALL select_person(@test_name);

-- 测试函数：计算罚款
SELECT '【验证7】罚款计算函数应返回0' AS test_case;
SELECT Calculate_Fines(@test_name) AS total_fines;

-- ----------------------------
-- 第五部分：逾期罚款测试
-- 设置逾期场景
UPDATE borrow_record SET
                         is_return = FALSE,
                         due_date = DATE_SUB(CURDATE(), INTERVAL 5 DAY)
WHERE record_id = 1;
select * from borrow_record;
-- 手动触发罚款计算事件
call UpdateOverdueAndFines();
CALL DailyCalculateFines();

SELECT '【验证8】应生成罚款记录' AS test_case;
SELECT * FROM fine_record WHERE borrower_id = @borrower_id;

SELECT '【验证9】5天逾期罚款应为5元' AS test_case;
SELECT fine FROM fine_record WHERE record_id = 1;

-- ----------------------------
-- 第六部分：数据完整性验证
SELECT '【验证11】外键约束应正常生效' AS test_case;
-- 预期失败的插入
INSERT INTO borrow_record (borrower_id, book_id, borrow_date, due_date) VALUES
    (999, 1, CURDATE(), CURDATE());  -- 不存在的借阅人

-- ----------------------------
-- 清理测试数据
ROLLBACK;  -- 回滚所有测试数据

