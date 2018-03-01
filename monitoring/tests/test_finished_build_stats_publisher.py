#!/usr/bin/env python3
import unittest
from unittest.mock import MagicMock
from finished_build_stats_publisher import FinishedBuildStatsPublisher
from tests.common import get_build_stats_with_status


class TestFinishedBuildStatsPublisher(unittest.TestCase):
    class CollectSideEffect(object):
        def __init__(self):
            self.count = 0

        def __call__(self):
            self.count += 1
            status = 'SUCCESS' if self.count >= 3 else 'IN_PROGRESS'
            return get_build_stats_with_status(status)

    def test_finished(self):
        build_stats = get_build_stats_with_status('SUCCESS')

        collector = MagicMock()
        collector.collect = MagicMock(return_value=build_stats)

        publisher = MagicMock()
        publisher.publish = MagicMock()

        stats_publisher = FinishedBuildStatsPublisher(collector, publisher)
        stats_publisher.collect_and_publish()

        collector.collect.assert_called_once_with()
        publisher.publish.assert_called_once_with(build_stats)

    def test_with_retries(self):
        success_build_stats = get_build_stats_with_status('SUCCESS')

        collector = MagicMock()
        collector.collect = MagicMock(side_effect=TestFinishedBuildStatsPublisher.CollectSideEffect())

        publisher = MagicMock()
        publisher.publish = MagicMock()

        stats_publisher = FinishedBuildStatsPublisher(collector, publisher)
        stats_publisher.collect_and_publish(delay_ms=0)

        self.assertEqual(collector.collect.call_count, 3)
        publisher.publish.assert_called_once_with(success_build_stats)


if __name__ == '__main__':
    unittest.main()
