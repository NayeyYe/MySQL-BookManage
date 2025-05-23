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
    fernet = Fernet(dbconfig.AES_KEY)

    pwd_hash = fernet.encrypt(dbconfig.password.encode()).decode()
    print(pwd_hash)

    pwd_1 = 'gAAAAABoL9cxShGC7tkxYJAUPbBSAIbjfkw1LSUV0oR29_5fLTXGYF3TksN7B_RVdSbfY44NWEUhXilhLvFARrJIeWdf3zASgw=='
    pwd = fernet.decrypt(pwd_1.encode()).decode()
    print(pwd)

    print(len(dbconfig.AES_KEY))