import os
from cryptography.fernet import Fernet

class BaseConfig:
    def __init__(self):
        self.root_dir = os.path.dirname(__file__)


class DataBaseConfig(BaseConfig):
    def __init__(self):
        super().__init__()
        self.database_dir = os.path.join(self.root_dir, 'database')

        # 数据库信息
        self.host = 'localhost'
        self.port = 3306
        self.database_name = 'bookmanage'
        self.super_admin = 'root'
        self.password = '13Password,'

        # 加密
        self.AES_KEY = b'GJJHd7gUVvrkbO9PL8wkv2DeYixJR9VosZ01j-nK2xU='


dbconfig = DataBaseConfig()


if __name__ == '__main__':
    print(Fernet.generate_key())