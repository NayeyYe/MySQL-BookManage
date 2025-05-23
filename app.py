from flask import Flask, render_template, redirect, url_for, request, jsonify, session
import pymysql
from config import dbconfig


app = Flask(__name__)

app.secret_key = 'your_secret_key_here'  # 设置Flask会话密钥

def get_db_connection():
    return pymysql.connect(
        host=dbconfig.host,
        user=dbconfig.super_admin,
        password=dbconfig.password,
        database=dbconfig.database_name,
        cursorclass=pymysql.cursors.DictCursor
    )

@app.route('/')
@app.route('/index.html')
def index():
    return render_template('index.html')

# 在app.py中添加登录路由处理
@app.route('/login.html', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        try:
            data = request.get_json()
            required_fields = {
                'teacher': ['loginMethod', 'staffId' if data.get('loginMethod') == 'staffId' else 'tPhone', 'password'],
                'student': ['loginMethod', 'sId' if data.get('loginMethod') == 'studentId' else 'sPhone', 'password'],
                'visitor': ['vPhone', 'password'],
                'admin': ['adminAccount', 'password']
            }

            user_type = data['userType']
            if not all(field in data for field in required_fields[user_type]):
                return jsonify({'success': False, 'message': '缺少必要字段'}), 400

            connection = get_db_connection()
            try:
                with connection.cursor() as cursor:
                    params = []
                    if user_type == 'teacher':
                        if data['loginMethod'] == 'staffId':
                            cursor.callproc('login_by_origin_id', (data['staffId'], data['password']))
                        else:
                            cursor.callproc('login_by_phone', (data['tPhone'], data['password']))
                    elif user_type == 'student':
                        if data['loginMethod'] == 'studentId':
                            cursor.callproc('login_by_origin_id', (data['sId'], data['password']))
                        else:
                            cursor.callproc('login_by_phone', (data['sPhone'], data['password']))
                    elif user_type == 'visitor':
                        cursor.callproc('login_by_phone', (data['vPhone'], data['password']))
                    elif user_type == 'admin':
                        cursor.callproc('login_admin', (data['adminAccount'], data['password']))

                    result = cursor.fetchone()

                    # 显式消费所有结果集
                    while cursor.nextset():
                        pass

                    if not result:
                        raise ValueError('用户信息获取失败')
                    connection.commit()
                    session['user_id'] = result['id']
                    session['username'] = result['name']
                    session['user_type'] = result['category']
                    return jsonify({
                        'success': True,
                        'message': '登录成功',
                        'redirect': url_for('home')  # 添加跳转路径
                    })


            except pymysql.MySQLError as e:
                connection.rollback()
                error_code = e.args[0] if e.args else 500
                error_msg = e.args[1] if len(e.args) > 1 else "数据库操作失败"

                # 处理特定错误代码
                if error_code == 1644:
                    return jsonify({'success': False, 'message': error_msg}), 401
                return jsonify({'success': False, 'message': error_msg}), 500

            finally:
                connection.close()

        except KeyError as e:
            return jsonify({'success': False, 'message': f'缺少必要字段: {e}'}), 400
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    return render_template('login.html')

@app.route('/register.html', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        try:
            # 获取表单数据
            data = request.get_json()
            name = data['name']
            user_type = data['userType']
            password = data['password']

            # 字段验证
            if not all([name, user_type, password]):
                return jsonify({'success': False, 'message': '必填字段不能为空'}), 400

            # 根据身份类型验证不同字段
            category_map = {'teacher': 2, 'student': 1, 'visitor': 3}
            category_id = category_map.get(user_type)
            origin_id = None
            phone = None

            if user_type == 'teacher':
                origin_id = data['staffId']
                phone = data['teacherPhone']
                if not origin_id.isdigit() or len(origin_id) not in (8, 10):
                    return jsonify({'success': False, 'message': '职工ID格式错误'}), 400
            elif user_type == 'student':
                origin_id = data['studentId']
                phone = data['studentPhone']
                if not origin_id.isdigit() or len(origin_id) != 13:
                    return jsonify({'success': False, 'message': '学号格式错误'}), 400
            elif user_type == 'visitor':
                phone = data['visitorPhone']
            else:
                return jsonify({'success': False, 'message': '无效的用户类型'}), 400

            # 手机号验证
            if not phone.startswith('1') or len(phone) != 11:
                return jsonify({'success': False, 'message': '手机号格式错误'}), 400
            # 数据库操作
            connection = get_db_connection()
            try:
                with connection.cursor() as cursor:
                    # 调用存储过程
                    if user_type == 'visitor':
                        cursor.callproc('register_external_user',
                                        (name, phone, category_id, password))
                    else:
                        cursor.callproc('register_identity_user',
                                        (name, phone, category_id, origin_id, password))

                    connection.commit()
                    return jsonify({'success': True, 'message': '注册成功'})

            except pymysql.MySQLError as e:
                connection.rollback()
                error_message = str(e.args[1]) if e.args else "数据库操作失败"
                return jsonify({'success': False, 'message': error_message}), 500

            finally:
                connection.close()

        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500

    return render_template('register.html')

@app.route('/helloworld.html')
def helloworld():
    return render_template('helloworld.html')

# 统一重定向历史路径
@app.route('/index')
def index_redirect():
    return redirect(url_for('index'))

# app.py 修改（优化首页路由）
@app.route('/home.html')
def home():
    if 'user_id' not in session:  # 添加登录校验
        return redirect(url_for('login'))

    username = session.get('username', '用户')
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 调用存储过程
            cursor.callproc('get_book_baseinfo')
            # 获取结果集
            books = cursor.fetchall()
            # 处理分类字段格式
            for book in books:
                book['categories'] = book['categories'] or '未分类'
            # 处理多结果集
            while cursor.nextset():
                pass
        return render_template('home.html', books=books, username=username)
    except pymysql.MySQLError as e:
        app.logger.error(f"数据库错误: {str(e)}")
        return render_template('error.html', message='数据库查询失败'), 500
    except Exception as e:
        app.logger.error(f"系统错误: {str(e)}")
        return render_template('error.html', message='系统错误'), 500
    finally:
        if 'connection' in locals():
            connection.close()


# app.py 添加借阅校验路由
@app.route('/check_book', methods=['POST'])
def check_book_availability():
    try:
        data = request.get_json()
        book_id = data['book_id']
        action = data['action']  # 'borrow'或'add_to_cart'

        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 调用校验函数
            cursor.execute("SELECT check_book_remain(%s) as available", (book_id,))
            result = cursor.fetchone()

            if result['available']:
                # 余量充足处理逻辑
                if action == 'add_to_cart':
                    return jsonify({'available': True, 'message': '已加入借书车'})
                return jsonify({'available': True, 'message': '可借阅'})
            else:
                # 余量不足处理
                return jsonify({
                    'available': False,
                    'message': '没有余量',
                    'alert_type': 'error'
                }), 400

    except KeyError as e:
        return jsonify({'success': False, 'message': f'缺少必要参数: {e}'}), 400
    except pymysql.MySQLError as e:
        return jsonify({'success': False, 'message': f'数据库错误: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
    finally:
        if 'connection' in locals():
            connection.close()


@app.route('/borrow', methods=['POST'])
def borrow_book():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': '请先登录'}), 401

    data = request.get_json()
    book_id = data.get('book_id')

    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 调用借书存储过程
            cursor.callproc('borrow_book',
                            (session['user_id'], book_id))
            connection.commit()
            return jsonify({'success': True, 'message': '借阅成功'})

    except pymysql.MySQLError as e:
        error_code = e.args[0]
        error_msg = e.args[1] if len(e.args) > 1 else "数据库错误"
        # 处理特定错误码
        if error_code == 1644:
            return jsonify({'success': False, 'message': error_msg}), 400
        return jsonify({'success': False, 'message': error_msg}), 500

    finally:
        connection.close()


# 处理未实现页面
@app.route('/<page>')
def catch_all(page):
    if page in ['profile.html', 'logout.html']:
        return render_template(page)
    return "页面不存在", 404

if __name__ == '__main__':
    app.run(debug=True)
