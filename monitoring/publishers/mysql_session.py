from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


class MySQLSession(object):
    def __init__(self, host, username, password, database):
        self.connection_string = self._get_connection_string(host, username, password, database)

    def get_database_session(self):
        engine = self.get_database_engine()
        session_factory = sessionmaker()
        session_factory.configure(bind=engine)
        return session_factory()

    def get_database_engine(self, echo=False):
        return create_engine(self.connection_string, echo=echo)

    def _get_connection_string(self, host, username, password, database):
        return 'mysql://{}:{}@{}/{}'.format(username, password, host, database)
