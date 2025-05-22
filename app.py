from flask import Flask, render_template, redirect, url_for, request, jsonify
from cryptography.fernet import Fernet
import pymysql
from config import dbconfig


app = Flask(__name__)

app.secret_key = 'your_secret_key_here'  # 设置Flask会话密钥
fernet = Fernet(dbconfig.AES_KEY)

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

@app.route('/login.html')
def login():
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
            # 加密密码
            encrypted_pwd = fernet.encrypt(password.encode()).decode()
            # 数据库操作
            connection = get_db_connection()
            try:
                with connection.cursor() as cursor:
                    # 调用存储过程
                    if user_type == 'visitor':
                        cursor.callproc('register_external_user',
                                        (name, phone, category_id, encrypted_pwd))
                    else:
                        cursor.callproc('register_identity_user',
                                        (name, phone, category_id, origin_id, encrypted_pwd))

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

# 处理未实现页面
@app.route('/<page>')
def catch_all(page):
    if page in ['profile.html', 'logout.html']:
        return render_template(page)
    return "页面不存在", 404

if __name__ == '__main__':
    app.run(debug=True)
