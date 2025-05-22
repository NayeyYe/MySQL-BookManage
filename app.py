from flask import Flask, render_template, redirect, url_for

app = Flask(__name__)

@app.route('/')
@app.route('/index.html')
def index():
    return render_template('index.html')

@app.route('/login.html')
def login():
    return render_template('login.html')

@app.route('/register.html')
def register():
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
