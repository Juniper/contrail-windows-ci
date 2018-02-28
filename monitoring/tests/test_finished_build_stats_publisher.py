#!/usr/bin/env python3
import unittest
from unittest.mock import MagicMock
from finished_build_stats_publisher import FinishedBuildStatsPublisher
from collector import ICollector
from publisher import IPublisher
from stats import BuildStats


class TestFinishedBuildStatsPublisher(unittest.TestCase):
    class CollectSideEffect(object):
        def __init__(self):
            self.count = 0

        def __call__(self):
            self.count += 1
            status = 'SUCCESS' if self.count >= 3 else 'IN_PROGRESS'
            return TestFinishedBuildStatsPublisher.get_build_stats_with_status(status)

    @classmethod
    def get_build_stats_with_status(cls, status):
        return BuildStats(
            job_name = 'Test',
            build_id = 1,
            build_url = 'http://1.2.3.4/',
            finished_at_secs = 2,
            status = status,
            duration_millis = 3,
            stages = [],
        )

    def test_finished(self):
        build_stats = self.get_build_stats_with_status('SUCCESS')

        collector = ICollector()
        collector.collect = MagicMock(return_value=build_stats)

        publisher = IPublisher()
        publisher.publish = MagicMock()

        stats_publisher = FinishedBuildStatsPublisher(collector, publisher)
        stats_publisher.collect_and_publish()

        collector.collect.assert_called_once_with()
        publisher.publish.assert_called_once_with(build_stats)

    def test_with_retries(self):
        success_build_stats = self.get_build_stats_with_status('SUCCESS')

        collector = ICollector()
        collector.collect = MagicMock(side_effect=TestFinishedBuildStatsPublisher.CollectSideEffect())

        publisher = IPublisher()
        publisher.publish = MagicMock()

        stats_publisher = FinishedBuildStatsPublisher(collector, publisher)
        stats_publisher.collect_and_publish(delay_ms=0)

        self.assertEqual(collector.collect.call_count, 3)
        publisher.publish.assert_called_once_with(success_build_stats)


if __name__ == '__main__':
    unittest.main()
