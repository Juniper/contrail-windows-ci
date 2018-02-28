#!/usr/bin/env python3
from sqlalchemy import create_engine
from publishers.database import MonitoringBase
from publishers.mysql_publisher_adapter import MySQLPublisherAdapter
from mysql_common_argument_parser import MysqlCommonArgumentParser


def parse_args():
    parser = MysqlCommonArgumentParser()
    return parser.parse_args()


def provision_database(connection_string, model):
    engine = create_engine(connection_string, echo=True)
    model.metadata.create_all(engine)


def main():
    args = parse_args()

    connection_string = MySQLPublisherAdapter.get_connection_string(host=args.mysql_host,
                                                                    username=args.mysql_username,
                                                                    password=args.mysql_password,
                                                                    database=args.mysql_database)
    provision_database(connection_string, MonitoringBase)


if __name__ == '__main__':
    main()
