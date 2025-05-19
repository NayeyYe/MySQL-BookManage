use BookManage;
# ------------------创建存储过程---------------------
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