#!/usr/bin/env python3
import unittest
from unittest.mock import MagicMock

from collectors.build_stats_collector import BuildStatsCollector, BuildStatsMissingError
from tests.common import get_test_build_stats, EXAMPLE_TESTS_STATS


class TestBuildStatsCollector(unittest.TestCase):
    def setUp(self):
        self.example_build_stats = get_test_build_stats()
        self.example_test_stats = EXAMPLE_TESTS_STATS

        self.example_build_stats_collector = MagicMock()
        self.example_build_stats_collector.collect = MagicMock(return_value=self.example_build_stats)

        self.example_test_stats_collector = MagicMock()
        self.example_test_stats_collector.collect = MagicMock(return_value=self.example_test_stats)

    def test_collecting_works(self):
        collector = BuildStatsCollector(build_stats_collector=self.example_build_stats_collector,
                                        test_stats_collector=self.example_test_stats_collector)
        build_stats = collector.collect()
        self.assertIsNotNone(build_stats)

        self.assertEqual(build_stats.build_id, self.example_build_stats.build_id)
        self.assertEqual(build_stats.job_name, self.example_build_stats.job_name)

        self.assertIsNotNone(build_stats.test_stats)
        self.assertEqual(build_stats.test_stats.total, self.example_test_stats.total)
        self.assertEqual(build_stats.test_stats.passed, self.example_test_stats.passed)

    def test_collecting_raises_exception_when_build_stats_raises_exception(self):
        build_stats_collector = MagicMock()
        build_stats_collector.collect = MagicMock(side_effect=Exception)

        collector = BuildStatsCollector(build_stats_collector=build_stats_collector,
                                        test_stats_collector=self.example_test_stats_collector)
        with self.assertRaises(Exception):
            collector.collect()

    def test_collecting_works_when_test_stats_are_missing(self):
        test_stats_collector = MagicMock()
        test_stats_collector.collect = MagicMock(side_effect=Exception)

        collector = BuildStatsCollector(build_stats_collector=self.example_build_stats_collector,
                                        test_stats_collector=test_stats_collector)
        build_stats = collector.collect()
        self.assertIsNotNone(build_stats)

        self.assertEqual(build_stats.build_id, self.example_build_stats.build_id)
        self.assertEqual(build_stats.job_name, self.example_build_stats.job_name)

        self.assertIsNone(build_stats.test_stats)


if __name__ == '__main__':
    unittest.main()
