from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from publishers.database import Build


class MySQLPublisherAdapter(object):

    def __init__(self, host, username, password, database):
        connection_string = self.get_connection_string(host, username, password, database)
        self.session = self.get_database_session(connection_string)


    def publish(self, build_stats):
        build = Build.from_build_stats(build_stats)
        self.session.add(build)
        self.session.commit()


    @classmethod
    def get_connection_string(cls, host, username, password, database):
        return 'mysql://{}:{}@{}/{}'.format(username, password, host, database)


    @classmethod
    def get_database_session(cls, connection_string):
        engine = create_engine(connection_string)
        session_factory = sessionmaker()
        session_factory.configure(bind=engine)
        return session_factory()
