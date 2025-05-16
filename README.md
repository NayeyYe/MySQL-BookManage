
### **1. 借阅人表 `borrower`**
#### **字段说明**
| 字段名              | 数据类型    | 约束                                  | 说明                     |
| ------------------- | ----------- | ------------------------------------- | ------------------------ |
| `id`                | INT         | PK, AUTO_INCREMENT, UNIQUE            | 借阅人证件号（唯一标识） |
| `name`              | VARCHAR(20) | NOT NULL                              | 借阅人姓名               |
| `PhoneNumber`       | VARCHAR(20) | NOT NULL                              | 借阅人电话               |
| `category_id`       | INT         | NOT NULL, FK → `category.category_id` | 借阅人身份类型           |
| `registration_date` | time        | NOT NULL                              | 注册时间                 |
| `borrowed_num`      | INT         | DEFAULT 0                             | 当前已借阅数目           |

#### **主键与外键**
- **主键**：`id`（唯一标识借阅人）。
- **外键**：`category_id` → `category.category_id`（关联借阅规则）。

#### **问题**
1. **冗余字段**：`borrowed_num` 可通过统计 `borrow_record` 表中未归还的记录动态计算。
2. **电话字段长度不足**：`PhoneNumber` 定义为 `VARCHAR(20)`，可能无法支持国际号码（如 `+86 13800138000`）。



### **2. 借阅规则表 `category`**
#### **字段说明**
| 字段名               | 数据类型 | 约束               | 说明                     |
| -------------------- | -------- | ------------------ | ------------------------ |
| `category_id`        | INT      | PK, AUTO_INCREMENT | 身份类型代码（唯一标识） |
| `category`           | ENUM     | UNIQUE             | 用户类别（学生/教师等）  |
| `max_borrowed_books` | INT      | NOT NULL           | 最大可借阅书籍数量       |
| `borrow_period`      | INT      | NOT NULL           | 借阅期限（天数）         |

#### **主键与外键**
- **主键**：`category_id`。
- **唯一约束**：`category` 字段确保类别名称唯一。

#### **问题**
1. **扩展性限制**：`category` 为 `ENUM` 类型，新增类别需修改表结构，建议改用 `VARCHAR` + 独立字典表。

---

### **3. 图书表 `book`**
#### **字段说明**
| 字段名             | 数据类型     | 约束                                  | 说明                 |
| ------------------ | ------------ | ------------------------------------- | -------------------- |
| `book_id`          | INT          | PK, AUTO_INCREMENT, UNIQUE            | 图书编号（唯一标识） |
| `title`            | VARCHAR(255) | NOT NULL                              | 书名                 |
| `isbn`             | VARCHAR(13)  | NOT NULL, UNIQUE                      | 国际标准书号（ISBN） |
| `category_id`      | INT          | NULL, FK → `bookCategory.category_id` | 图书分类号           |
| `author_id`        | INT          | NULL, FK → `author.author_id`         | 作者编号             |
| `publisher_id`     | INT          | NULL, FK → `publisher.publisher_id`   | 出版社编号           |
| `publication_year` | YEAR         | NULL                                  | 出版年份             |
| `total`            | INT          | NOT NULL                              | 图书总数             |
| `remain`           | INT          | NOT NULL                              | 剩余可借数量         |
| `location`         | VARCHAR(255) | NOT NULL                              | 存放位置             |

#### **主键与外键**
- **主键**：`book_id`。
- **外键**：
  - `category_id` → `bookCategory.category_id`
  - `author_id` → `author.author_id`
  - `publisher_id` → `publisher.publisher_id`

---

### **4. 图书类别表 `bookCategory`**
#### **字段说明**
| 字段名        | 数据类型    | 约束               | 说明         |
| ------------- | ----------- | ------------------ | ------------ |
| `category_id` | INT         | PK, AUTO_INCREMENT | 图书分类号   |
| `category`    | VARCHAR(20) | NOT NULL, UNIQUE   | 图书类别名称 |

#### **主键与外键**
- **主键**：`category_id`。
- **唯一约束**：`category` 确保类别名称唯一。

---

### **5. 作者表 `author`**
#### **字段说明**
| 字段名      | 数据类型     | 约束               | 说明     |
| ----------- | ------------ | ------------------ | -------- |
| `author_id` | INT          | PK, AUTO_INCREMENT | 作者编号 |
| `author`    | VARCHAR(255) | NOT NULL, UNIQUE   | 作者姓名 |

#### **主键与外键**
- **主键**：`author_id`。
- **唯一约束**：`author` 字段确保作者姓名唯一。

---

### **6. 出版社表 `publisher`**
#### **字段说明**
| 字段名         | 数据类型     | 约束               | 说明       |
| -------------- | ------------ | ------------------ | ---------- |
| `publisher_id` | INT          | PK, AUTO_INCREMENT | 出版社编号 |
| `publisher`    | VARCHAR(255) | NOT NULL, UNIQUE   | 出版社名称 |

#### **主键与外键**
- **主键**：`publisher_id`。
- **唯一约束**：`publisher` 确保出版社名称唯一。

---

### **7. 借阅记录表 `borrow_record`**
#### **字段说明**

| 字段名         | 数据类型 | 约束                          | 说明         |
| -------------- | -------- | ----------------------------- | ------------ |
| `record_id`    | INT      | PK, AUTO_INCREMENT, UNIQUE    | 借阅记录编号 |
| `borrower_id`  | INT      | NOT NULL, FK → `borrower.id`  | 借阅人证件号 |
| `book_id`      | INT      | NOT NULL, FK → `book.book_id` | 图书编号     |
| `borrow_date`  | DATE     | NOT NULL                      | 借出日期     |
| `due_date`     | DATE     | NOT NULL                      | 应归还日期   |
| `is_return`    | BOOLEAN  | NOT NULL DEFAULT FALSE        | 是否归还     |
| `return_date`  | DATE     | NULL                          | 实际归还日期 |
| `overdue_days` | INT      | NULL                          | 逾期天数     |

#### **主键与外键**
- **主键**：`record_id`。
- **外键**：
  - `borrower_id` → `borrower.id`
  - `book_id` → `book.book_id`

