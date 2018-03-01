#!/usr/bin/env python3
import unittest
from unittest.mock import MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from publishers.database_publisher_adapter import DatabasePublisherAdapter
from publishers.database import Build, Stage, MonitoringBase
from stats import BuildStats, StageStats
from tests.common import get_test_build_stats, TEST_STAGE1_STATS, TEST_STAGE2_STATS
from tests.common import assert_stage_matches_stage_stats, assert_build_matches_build_stats


class TestPublishing(unittest.TestCase):
    def setUp(self):
        # Provision the SQLite in-memory database with our schema
        self.engine = create_engine('sqlite://')
        MonitoringBase.metadata.create_all(self.engine)

        session_factory = sessionmaker()
        session_factory.configure(bind=self.engine)
        self.session = session_factory()

        db_session = MagicMock()
        db_session.get_database_session = MagicMock(return_value=self.session)

        self.publisher = DatabasePublisherAdapter(db_session)

    def tearDown(self):
        self.engine.dispose()
        self.engine = None

    def test_publish_build_stats_no_stages(self):
        build_stats = get_test_build_stats()
        self.publisher.publish(build_stats)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)

        stage_count = self.session.query(Stage).count()
        self.assertEqual(stage_count, 0)

        build = self.session.query(Build).one()
        assert_build_matches_build_stats(self, build, build_stats)

    def test_publish_build_stats_with_stages(self):
        build_stats = get_test_build_stats([TEST_STAGE1_STATS, TEST_STAGE2_STATS])
        self.publisher.publish(build_stats)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)

        build = self.session.query(Build).one()
        self.assertEqual(len(build.stages), 2)
        self.assertIsNotNone(build.stages[0])
        self.assertIsNotNone(build.stages[1])

        assert_stage_matches_stage_stats(self, build.stages[0], TEST_STAGE1_STATS)
        self.assertEqual(build.stages[0].build_id, build.id)
        self.assertEqual(build.stages[0].build, build)

        assert_stage_matches_stage_stats(self, build.stages[1], TEST_STAGE2_STATS)
        self.assertEqual(build.stages[1].build_id, build.id)
        self.assertEqual(build.stages[1].build, build)


if __name__ == '__main__':
    unittest.main()
