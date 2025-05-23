# ---------------------- 创建数据库 ----------------------
drop database if exists BookManage;
create database if not exists bookmanage
    default character set utf8;
use BookManage;
show tables ;
# ---------------------- 创建数据表 ----------------------
SET FOREIGN_KEY_CHECKS = 0;


# 借阅规则
drop table if exists category;
create table if not exists category(
                                       category_id int auto_increment comment '身份类型代码',
                                       category enum('学生', '教师', '校外人员', '管理员') unique comment '用户类别',
                                       max_borrowed_books int not null comment '最大可借阅书籍量',
                                       borrow_period int not null comment '借阅期限',
                                       primary key(category_id)
);
INSERT INTO category (category, max_borrowed_books, borrow_period)
values ( '学生', 10, 30),
       ('教师', 20, 60),
       ('校外人员', 5, 14),
       ('管理员', 50, 90);


# 创建借阅人表
drop table if exists borrower;
create table if not exists borrower(
    id int unique auto_increment comment '借阅人证件号',
    name varchar(20) not null comment '借阅人姓名',
    PhoneNumber varchar(30) unique not null comment '借阅人电话',
    category_id int not null comment '借阅人身份',
    origin_id varchar(13) null comment '学生ID或者教职工ID',
    borrowed_num int default 0 comment '已借阅数目',
    registration_date date not null comment '注册时间',
    is_can_borrow bool not null default TRUE comment '是否可以借书',
    primary key (id),
    foreign key (category_id) references category(category_id)
);
INSERT INTO borrower(name, PhoneNumber, category_id, registration_date) values ('root', '13597646338', 4, current_date);

# 账号密码表
drop table if exists user_info;
create table if not exists user_info(
    id int comment '账号',
    password_hash VARCHAR(255) NOT NULL COMMENT 'SHA2密码哈希',
    foreign key (id) references borrower(id)
);

# 出版社表
drop table if exists publisher;
create table if not exists publisher(
                                        publisher_id int not null auto_increment comment '出版社编号',
                                        publisher varchar(255) unique not null comment '出版社名字',
                                        primary key (publisher_id)
);


# 图书表
drop table if exists book;
create table if not exists book(
    book_id int auto_increment unique comment '图书编号',
    title varchar(255) not null comment '书名',
    isbn varchar(17) not null unique comment '国际标准书号',
    publisher_id int null comment '出版社编号',
    publication_year year null comment '出版年份',
    total int not null comment '图书总数',
    remain int not null comment '图书剩余量',
    location varchar(255) not null comment '存放位置',
    primary key (book_id),
    foreign key (publisher_id) references publisher(publisher_id)
);

# 图书类别表
drop table if exists bookCategory;
create table if not exists bookCategory(
    category_id int not null auto_increment comment '图书分类号',
    category varchar(20) unique not null comment '图书类别',
    primary key (category_id)
);

# 图书--图书类表关系表
drop table if exists bookCategoryRelation;
create table if not exists bookCategoryRelation(
                                                   book_id int auto_increment unique comment '图书编号',
                                                   category_id int not null comment '图书分类号',
                                                   primary key (book_id, category_id),
                                                   foreign key (book_id) references book(book_id),
                                                   foreign key (category_id) references bookcategory(category_id)
);

# 作者表
drop table if exists author;
create table if not exists author(
    author_id int not null auto_increment comment '作者编号',
    author varchar(255) unique not null comment '作者名字',
    primary key (author_id)
);

# 图书--作者关系表
drop table if exists bookAuthorRelation;
create table if not exists bookAuthorRelation(
    book_id int auto_increment comment '图书编号',
    author_id int not null comment '作者编号',
    primary key (book_id, author_id),
    foreign key (book_id) references book(book_id),
    foreign key (author_id) references author(author_id)
);


# 借阅记录
drop table if exists borrow_record;
create table if not exists borrow_record(
    record_id int not null unique auto_increment comment '借阅记录编号',
    borrower_id int not null comment '借阅人证件号',
    book_id int not null comment '图书编号',
    borrow_date date not null comment '借出日期',

    due_date date not null comment '应归还日期',
    is_return boolean not null default false comment '是否归还',
    return_date date null comment '实际归还日期',

    overdue_days int null comment '逾期天数',
    primary key (record_id),
    foreign key (borrower_id) references borrower(id),
    foreign key (book_id) references book(book_id)
);

# 罚款记录表
drop table if exists fine_record;
create table if not exists fine_record(
    fine_id int not null unique auto_increment comment '罚款记录编号',
    record_id int not null unique comment '借阅记录编号',
    borrower_id int not null comment '借阅人证件号',
    book_id int not null comment '图书编号',

    borrow_date date not null comment '借出日期',
    due_date date not null comment '应归还日期',

    overdue_days int null comment '逾期天数',
    is_return boolean not null default false comment '是否归还',
    fine int not null comment '罚款金额',
    is_pay boolean not null default false comment '是否缴纳罚款',

    primary key (fine_id),
    foreign key (record_id) references borrow_record(record_id),
    foreign key (borrower_id) references borrower(id),
    foreign key (book_id) references book(book_id)
);

SET FOREIGN_KEY_CHECKS = 1;


# 登录系统日志表
drop table if exists login_logging;
create table if not exists login_logging(
    id int unique comment '借阅人证件号',
    name varchar(20) not null comment '借阅人姓名',
    login_time date not null comment '登录时间',
    foreign key (id) references borrower(id)
);
