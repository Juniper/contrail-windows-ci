#!/usr/bin/env python3
import unittest
from collections import namedtuple
from stats import BuildStats, StageStats
from publishers.database import Build, Stage


class TestObjectStringifying(unittest.TestCase):
    def test_build_stringifying(self):
        build_stats = {
            'job_name': 'Test',
            'build_id': 1234,
            'build_url': 'test',
            'finished_at_secs': 5678,
            'status': 'SUCCESS',
            'duration_millis': 4321,
            'stages': [],
        }
        build_stats = namedtuple('TestStats', build_stats.keys())(*build_stats.values())
        build = Build(build_stats)

        self.assertEqual(str(build), '<Build(id=None, name=Test, build_id=1234)>')

    def test_stage_stringifying(self):
        build_stats = {
            'job_name': 'Test',
            'build_id': 1234,
            'build_url': 'test',
            'finished_at_secs': 5678,
            'status': 'SUCCESS',
            'duration_millis': 4321,
            'stages': [],
        }
        build_stats = namedtuple('TestBuildStats', build_stats.keys())(*build_stats.values())
        build = Build(build_stats)

        stage_stats = {
            'name': 'TestStage',
            'status': 'SUCCESS',
            'duration_millis': 1010,
        }
        stage_stats = namedtuple('TestStageStats', stage_stats.keys())(*stage_stats.values())
        stage = Stage(stage_stats)

        build.stages.append(stage)

        self.assertEqual(str(stage), '<Stage(id=None, build_id=1234, name=TestStage)>')


class TestObjectConversions(unittest.TestCase):
    def test_stage_from_stage_stats(self):
        stage_stats = StageStats(
            name = 'Stage1',
            status = 'OK',
            duration_millis = 123
        )

        stage = Stage(stage_stats)

        self.assertIsNotNone(stage)
        self.assertEqual(stage.id, None)
        self.assertEqual(stage.build_id, None)
        self.assertEqual(stage.name, 'Stage1')
        self.assertEqual(stage.status, 'OK')
        self.assertEqual(stage.duration_millis, 123)
        self.assertEqual(stage.build, None)

    def test_build_from_build_stats(self):
        build_stats = BuildStats(
            job_name = 'MyJob',
            build_url = 'http://1.2.3.4/',
            build_id = 10,
            finished_at_secs = 123,
            status = 'SUCCESS',
            duration_millis = 3,
            stages = [],
        )

        build = Build(build_stats)

        self.assertIsNotNone(build)
        self.assertEqual(build.id, None)
        self.assertEqual(build.job_name, 'MyJob')
        self.assertEqual(build.build_id, 10)
        self.assertEqual(build.build_url, 'http://1.2.3.4/')
        self.assertEqual(build.finished_at_secs, 123)
        self.assertEqual(build.duration_millis, 3)
        self.assertEqual(build.status, 'SUCCESS')
        self.assertIsNotNone(build.stages)
        self.assertEqual(len(build.stages), 0)

    def test_build_from_build_and_stages_stats(self):
        build_stats = BuildStats(
            job_name = 'MyJob',
            build_url = 'http://1.2.3.4/',
            build_id = 10,
            finished_at_secs = 123,
            status = 'SUCCESS',
            duration_millis = 3,
            stages = [
                StageStats(
                    name = 'Stage1',
                    status = 'OK',
                    duration_millis = 123
                ),
                StageStats(
                    name = 'Stage2',
                    status = 'FAIL',
                    duration_millis = 321
                ),
            ],
        )

        build = Build(build_stats)

        self.assertIsNotNone(build)
        self.assertEqual(build.id, None)
        self.assertEqual(build.job_name, 'MyJob')
        self.assertEqual(build.build_id, 10)
        self.assertEqual(build.build_url, 'http://1.2.3.4/')
        self.assertEqual(build.finished_at_secs, 123)
        self.assertEqual(build.duration_millis, 3)
        self.assertEqual(build.status, 'SUCCESS')
        self.assertIsNotNone(build.stages)
        self.assertEqual(len(build.stages), 2)

        self.assertIsNotNone(build.stages[0])
        self.assertEqual(build.stages[0].id, None)
        self.assertEqual(build.stages[0].build_id, None)
        self.assertEqual(build.stages[0].name, 'Stage1')
        self.assertEqual(build.stages[0].status, 'OK')
        self.assertEqual(build.stages[0].duration_millis, 123)
        self.assertEqual(build.stages[0].build, build)

        self.assertIsNotNone(build.stages[1])
        self.assertEqual(build.stages[1].id, None)
        self.assertEqual(build.stages[1].build_id, None)
        self.assertEqual(build.stages[1].name, 'Stage2')
        self.assertEqual(build.stages[1].status, 'FAIL')
        self.assertEqual(build.stages[1].duration_millis, 321)
        self.assertEqual(build.stages[1].build, build)

    def test_invalid_build_stats(self):
        pass

if __name__ == '__main__':
    unittest.main()
