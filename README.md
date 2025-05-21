# BookManage 数据库表结构说明

## 1. category（借阅规则表）

| 字段名             | 类型 | 允许NULL | 默认值 | 键     | 注释                                  |
| ------------------ | ---- | -------- | ------ | ------ | ------------------------------------- |
| category_id        | int  | 否       | 自增   | 主键   | 身份类型代码                          |
| category           | enum | 否       | 无     | 唯一键 | 用户类别（学生/教师/校外人员/管理员） |
| max_borrowed_books | int  | 否       | 无     |        | 最大可借阅书籍量                      |
| borrow_period      | int  | 否       | 无     |        | 借阅期限（天）                        |

## 2. borrower（借阅人表）

| 字段名            | 类型        | 允许NULL | 默认值 | 键     | 注释                     |
| ----------------- | ----------- | -------- | ------ | ------ | ------------------------ |
| id                | int         | 否       | 自增   | 主键   | 借阅人证件号             |
| name              | varchar(20) | 否       | 无     |        | 借阅人姓名               |
| PhoneNumber       | varchar(30) | 否       | 无     | 唯一键 | 借阅人电话               |
| category_id       | int         | 否       | 无     | 外键   | 关联category表的身份类型 |
| borrowed_num      | int         | 是       | 0      |        | 已借阅数目               |
| registration_date | date        | 否       | 无     |        | 注册时间                 |
| is_can_borrow     | bool        | 否       | TRUE   |        | 是否可借书               |

## 3. publisher（出版社表）

| 字段名       | 类型         | 允许NULL | 默认值 | 键     | 注释       |
| ------------ | ------------ | -------- | ------ | ------ | ---------- |
| publisher_id | int          | 否       | 自增   | 主键   | 出版社编号 |
| publisher    | varchar(255) | 否       | 无     | 唯一键 | 出版社名字 |

## 4. book（图书表）

| 字段名           | 类型         | 允许NULL | 默认值 | 键            | 注释         |
| ---------------- | ------------ | -------- | ------ | ------------- | ------------ |
| book_id          | int          | 否       | 自增   | 主键          | 图书编号     |
| title            | varchar(255) | 否       | 无     |               | 书名         |
| isbn             | varchar(17)  | 否       | 无     | 唯一键        | 国际标准书号 |
| publisher_id     | int          | 是       | NULL   | 外键:pulisher | 出版社编号   |
| publication_year | year         | 是       | NULL   |               | 出版年份     |
| total            | int          | 否       | 无     |               | 图书总数     |
| remain           | int          | 否       | 无     |               | 图书剩余量   |
| location         | varchar(255) | 否       | 无     |               | 存放位置     |

## 5. bookCategory（图书类别表）

| 字段名      | 类型        | 允许NULL | 默认值 | 键     | 注释       |
| ----------- | ----------- | -------- | ------ | ------ | ---------- |
| category_id | int         | 否       | 自增   | 主键   | 图书分类号 |
| category    | varchar(20) | 否       | 无     | 唯一键 | 图书类别   |

## 6. bookCategoryRelation（图书-类别关系表）

| 字段名      | 类型 | 允许NULL | 默认值 | 键             | 注释       |
| ----------- | ---- | -------- | ------ | -------------- | ---------- |
| book_id     | int  | 否       | 自增   | 联合主键，外键 | 图书编号   |
| category_id | int  | 否       | 无     | 联合主键，外键 | 图书分类号 |

## 7. author（作者表）

| 字段名    | 类型         | 允许NULL | 默认值 | 键     | 注释     |
| --------- | ------------ | -------- | ------ | ------ | -------- |
| author_id | int          | 否       | 自增   | 主键   | 作者编号 |
| author    | varchar(255) | 否       | 无     | 唯一键 | 作者名字 |

## 8. bookAuthorRelation（图书-作者关系表）

| 字段名    | 类型 | 允许NULL | 默认值 | 键             | 注释     |
| --------- | ---- | -------- | ------ | -------------- | -------- |
| book_id   | int  | 否       | 自增   | 联合主键       | 图书编号 |
| author_id | int  | 否       | 无     | 联合主键，外键 | 作者编号 |

## 9. borrow_record（借阅记录表）

| 字段名       | 类型 | 允许NULL | 默认值 | 键            | 注释         |
| ------------ | ---- | -------- | ------ | ------------- | ------------ |
| record_id    | int  | 否       | 自增   | 主键          | 借阅记录编号 |
| borrower_id  | int  | 否       | 无     | 外键:borrower | 借阅人证件号 |
| book_id      | int  | 否       | 无     | 外键:book     | 图书编号     |
| borrow_date  | date | 否       | 无     |               | 借出日期     |
| due_date     | date | 否       | 无     |               | 应归还日期   |
| is_return    | bool | 否       | FALSE  |               | 是否归还     |
| return_date  | date | 是       | NULL   |               | 实际归还日期 |
| overdue_days | int  | 是       | NULL   |               | 逾期天数     |

## 10. fine_record（罚款记录表）

| 字段名       | 类型 | 允许NULL | 默认值 | 键                 | 注释                 |
| ------------ | ---- | -------- | ------ | ------------------ | -------------------- |
| fine_id      | int  | 否       | 自增   | 主键               | 罚款记录编号         |
| record_id    | int  | 否       | 无     | 外键:borrow_record | 借阅记录编号         |
| borrower_id  | int  | 否       | 无     | 外键:borrower      | 借阅人证件号         |
| book_id      | int  | 否       | 无     | 外键:book          | 图书编号             |
| borrow_date  | date | 否       | 无     |                    | 借出日期             |
| due_date     | date | 否       | 无     |                    | 应归还日期           |
| overdue_days | int  | 是       | NULL   |                    | 逾期天数             |
| is_return    | bool | 否       | FALSE  |                    | 是否归还             |
| fine         | int  | 否       | 无     |                    | 罚款金额（单位：分） |
| is_pay       | bool | 否       | FALSE  |                    | 是否缴纳罚款         |
