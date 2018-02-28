#!/usr/bin/env python3
from mysql_common_argument_parser import MysqlCommonArgumentParser
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter
from publishers.mysql_publisher_adapter import MySQLPublisherAdapter
from finished_build_stats_publisher import FinishedBuildStatsPublisher


def parse_args():
    parser = MysqlCommonArgumentParser()
    parser.add_argument('--job-name', required=True)
    parser.add_argument('--build-url', required=True)
    return parser.parse_args()


def main():
    args = parse_args()

    collector = JenkinsCollectorAdapter(job_name=args.job_name, build_url=args.build_url)
    publisher = MySQLPublisherAdapter(host=args.mysql_host, username=args.mysql_username,
                                      password=args.mysql_password, database=args.mysql_database)

    stats_publisher = FinishedBuildStatsPublisher(collector, publisher)
    stats_publisher.collect_and_publish()


if __name__ == '__main__':
    main()
