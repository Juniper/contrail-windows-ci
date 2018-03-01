#!/usr/bin/env python3
import unittest
from unittest.mock import MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from publishers.database_publisher_adapter import DatabasePublisherAdapter
from publishers.database import Build, Stage, MonitoringBase
from stats import BuildStats, StageStats


class TestPublishing(unittest.TestCase):
    def setUp(self):
        # Provision the SQLite in-memory database with our schema
        self.engine = create_engine('sqlite://')
        MonitoringBase.metadata.create_all(self.engine)

        self.session_factory = sessionmaker()
        self.session_factory.configure(bind=self.engine)
        self.session = self.session_factory()

    def tearDown(self):
        self.session = None
        self.session_factory = None
        self.engine.dispose()
        self.engine = None

    def test_publish_build_stats_no_stages(self):
        build_stats = BuildStats(
            job_name = 'Test',
            build_id = 1234,
            build_url = 'http://1.2.3.4:8080/job/MyJob/1',
            finished_at_secs = 5678,
            status = 'SUCCESS',
            duration_millis = 4321,
            stages = [],
        )

        db_session = MagicMock()
        db_session.get_database_session = MagicMock(return_value=self.session)
        publisher = DatabasePublisherAdapter(db_session)
        publisher.publish(build_stats)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)

        stage_count = self.session.query(Stage).count()
        self.assertEqual(stage_count, 0)

        build = self.session.query(Build).one()
        self.assertEqual(build.job_name, 'Test')
        self.assertEqual(build.build_id, 1234)
        self.assertEqual(build.build_url, 'http://1.2.3.4:8080/job/MyJob/1')
        self.assertEqual(build.finished_at_secs, 5678)
        self.assertEqual(build.status, 'SUCCESS')
        self.assertEqual(build.duration_millis, 4321)

    def test_publish_build_stats_with_stages(self):
        stage1_stats = StageStats(
            name = 'TestStage1',
            status = 'SUCCESS',
            duration_millis = 1010,
        )

        stage2_stats = StageStats(
            name = 'TestStage2',
            status = 'FAILURE',
            duration_millis = 10,
        )

        build_stats = BuildStats(
            job_name = 'Test',
            build_id = 1234,
            build_url = 'http://1.2.3.4:8080/job/MyJob/1',
            finished_at_secs = 5678,
            status = 'SUCCESS',
            duration_millis = 4321,
            stages = [stage1_stats, stage2_stats],
        )

        db_session = MagicMock()
        db_session.get_database_session = MagicMock(return_value=self.session)
        publisher = DatabasePublisherAdapter(db_session)
        publisher.publish(build_stats)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)
        build = self.session.query(Build).one()
        self.assertEqual(len(build.stages), 2)
        self.assertIsNotNone(build.stages[0])
        self.assertIsNotNone(build.stages[1])

        self.assertEqual(build.stages[0].name, 'TestStage1')
        self.assertEqual(build.stages[0].status, 'SUCCESS')
        self.assertEqual(build.stages[0].duration_millis, 1010)
        self.assertEqual(build.stages[0].build_id, build.id)
        self.assertEqual(build.stages[0].build, build)

        self.assertEqual(build.stages[1].name, 'TestStage2')
        self.assertEqual(build.stages[1].status, 'FAILURE')
        self.assertEqual(build.stages[1].duration_millis, 10)
        self.assertEqual(build.stages[1].build_id, build.id)
        self.assertEqual(build.stages[1].build, build)


if __name__ == '__main__':
    unittest.main()
