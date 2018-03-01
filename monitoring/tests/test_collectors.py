#!/usr/bin/env python3
import unittest
import requests_mock
from datetime import datetime, timezone
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter, InvalidResponseCodeError
from stats import BuildStats, StageStats


class TestJenkinsGetBuildStatsEndpoint(unittest.TestCase):
    def test_build_stats_endpoint_is_good(self):
        url = JenkinsCollectorAdapter.get_build_stats_endpoint(build_url='http://1.2.3.4:5678/job/MyJob/1')
        self.assertEqual(url, 'http://1.2.3.4:5678/job/MyJob/1/wfapi/describe')


class TestJenkinsGetRawStats(unittest.TestCase):
    def test_get_raw_stats_ok(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': 1234,
            })

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
            stats = collector.get_raw_stats_from_jenkins()

        self.assertIsNotNone(stats)
        self.assertEqual(stats['id'], 1)
        self.assertEqual(stats['endTimeMillis'], 1234)
        self.assertEqual(stats['status'], 'SUCCESS')
        self.assertEqual(stats['durationMillis'], 1000)

    def test_get_raw_stats_invalid_build_id(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/-1/wfapi/describe', status_code=404)

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/-1')
            with self.assertRaises(InvalidResponseCodeError):
                collector.get_raw_stats_from_jenkins()


class TestJenkinsConvertStats(unittest.TestCase):
    def setUp(self):
        self.finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        self.finished_at_millis = int(self.finished_at.timestamp() * 1000)

    def test_build_stats(self):
        json = {
            'id': 1,
            'status': 'SUCCESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
        }

        collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
        build_stats = collector.convert_raw_stats_to_build_stats(json)

        self.assertIsNotNone(build_stats)
        self.assertIsInstance(build_stats, BuildStats)
        self.assertEqual(build_stats.job_name, 'MyJob')
        self.assertEqual(build_stats.build_id, 1)
        self.assertEqual(build_stats.build_url, 'http://1.2.3.4:5678/job/MyJob/1')
        self.assertEqual(build_stats.finished_at_secs, int(self.finished_at.timestamp()))
        self.assertEqual(build_stats.status, 'SUCCESS')
        self.assertEqual(build_stats.duration_millis, 1000)

    def test_no_stages(self):
        json = {
            'id': 1,
            'status': 'SUCCESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
        }

        collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
        build_stats = collector.convert_raw_stats_to_build_stats(json)

        self.assertIsNotNone(build_stats)
        self.assertEqual(len(build_stats.stages), 0)

    def test_empty_stages(self):
        json = {
            'id': 1,
            'status': 'SUCCESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
            'stages': [],
        }

        collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
        build_stats = collector.convert_raw_stats_to_build_stats(json)

        self.assertIsNotNone(build_stats)
        self.assertEqual(len(build_stats.stages), 0)

    def test_stages_stats(self):
        json = {
            'id': 1,
            'status': 'SUCCESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
            'stages': [
                {
                    'name': 'Preparation',
                    'status': 'SUCCESS',
                    'durationMillis': 1234,
                },
                {
                    'name': 'Build',
                    'status': 'FAILED',
                    'durationMillis': 4321,
                },
            ],
        }

        collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
        build_stats = collector.convert_raw_stats_to_build_stats(json)

        self.assertIsNotNone(build_stats)
        self.assertEqual(len(build_stats.stages), 2)
        self.assertIsNotNone(build_stats.stages[0])
        self.assertIsNotNone(build_stats.stages[1])

        self.assertEqual(build_stats.stages[0].name, 'Preparation')
        self.assertEqual(build_stats.stages[0].status, 'SUCCESS')
        self.assertEqual(build_stats.stages[0].duration_millis, 1234)

        self.assertEqual(build_stats.stages[1].name, 'Build')
        self.assertEqual(build_stats.stages[1].status, 'FAILED')
        self.assertEqual(build_stats.stages[1].duration_millis, 4321)


class TestJenkinsCollect(unittest.TestCase):
    def setUp(self):
        self.finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        self.finished_at_millis = int(self.finished_at.timestamp() * 1000)

    def test_build_stats(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
            })

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
            build_stats = collector.collect()
            self.assertIsNotNone(build_stats)
            self.assertIsInstance(build_stats, BuildStats)
            self.assertEqual(build_stats.job_name, 'MyJob')
            self.assertEqual(build_stats.build_id, 1)
            self.assertEqual(build_stats.build_url, 'http://1.2.3.4:5678/job/MyJob/1')
            self.assertEqual(build_stats.finished_at_secs, int(self.finished_at.timestamp()))
            self.assertEqual(build_stats.status, 'SUCCESS')
            self.assertEqual(build_stats.duration_millis, 1000)

    def test_invalid_url(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/-1/wfapi/describe', status_code=404)

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/-1')

            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_no_stages(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
            })

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
            build_stats = collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_empty_stages(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
                'stages': [],
            })

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
            build_stats = collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_stages_stats(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
                'stages': [
                    {
                        'name': 'Preparation',
                        'status': 'SUCCESS',
                        'durationMillis': 1234,
                    },
                    {
                        'name': 'Build',
                        'status': 'FAILED',
                        'durationMillis': 4321,
                    },
                ],
            })

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/1')
            build_stats = collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 2)
            self.assertIsNotNone(build_stats.stages[0])
            self.assertIsNotNone(build_stats.stages[1])

            self.assertEqual(build_stats.stages[0].name, 'Preparation')
            self.assertEqual(build_stats.stages[0].status, 'SUCCESS')
            self.assertEqual(build_stats.stages[0].duration_millis, 1234)

            self.assertEqual(build_stats.stages[1].name, 'Build')
            self.assertEqual(build_stats.stages[1].status, 'FAILED')
            self.assertEqual(build_stats.stages[1].duration_millis, 4321)


if __name__ == '__main__':
    unittest.main()
