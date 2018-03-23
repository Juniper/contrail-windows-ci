#!/usr/bin/env python3
import unittest
import requests_mock
from datetime import datetime, timezone
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter, InvalidResponseCodeError
from collectors.xml_report_collector import XmlReportCollector, MissingXmlAttributeError, \
    InvalidJsonFormatError, EmptyXmlReportsListError
from stats import BuildStats, StageStats
from xml.etree.ElementTree import ParseError
from json import JSONDecodeError


class TestJenkinsCollector(unittest.TestCase):
    def setUp(self):
        self.finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        self.finished_at_millis = int(self.finished_at.timestamp() * 1000)
        self.default_build_url = 'http://1.2.3.4:5678/job/MyJob/1'
        self.default_api_url = 'http://1.2.3.4:5678/job/MyJob/1/wfapi/describe'
        self.default_collector = JenkinsCollectorAdapter('MyJob', self.default_build_url)

        self.default_build_stats_response = {
            'id': 1,
            'status': 'SUCCESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
        }

        self.default_stages_stats_response = [
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
        ]

    def assert_build_stats_is_valid(self, build_stats, json):
        self.assertIsNotNone(build_stats)
        self.assertIsInstance(build_stats, BuildStats)
        self.assertEqual(build_stats.job_name, 'MyJob')
        self.assertEqual(build_stats.build_id, json['id'])
        self.assertEqual(build_stats.build_url, self.default_build_url)
        self.assertEqual(build_stats.finished_at_secs, int(self.finished_at.timestamp()))
        self.assertEqual(build_stats.status, json['status'])
        self.assertEqual(build_stats.duration_millis, json['durationMillis'])

    def assert_stage_stats_is_valid(self, stage_stats, json):
        self.assertIsNotNone(stage_stats)
        self.assertIsInstance(stage_stats, StageStats)
        self.assertEqual(stage_stats.name, json['name'])
        self.assertEqual(stage_stats.status, json['status'])
        self.assertEqual(stage_stats.duration_millis, json['durationMillis'])

    def test_build_stats(self):
        with requests_mock.mock() as m:
            response = self.default_build_stats_response
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()
            self.assert_build_stats_is_valid(build_stats, response)

    def test_invalid_url(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/-1/wfapi/describe', status_code=404)

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/-1')

            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_no_stages(self):
        with requests_mock.mock() as m:
            m.get(self.default_api_url, json=self.default_build_stats_response)
            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_empty_stages(self):
        with requests_mock.mock() as m:
            response = {**self.default_build_stats_response, **{ 'stages': [] }}
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_stages_stats(self):
        with requests_mock.mock() as m:
            response = {
                **self.default_build_stats_response,
                **{ 'stages': self.default_stages_stats_response }
            }
            m.get(self.default_api_url, json=response)
            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 2)

            self.assert_stage_stats_is_valid(build_stats.stages[0], self.default_stages_stats_response[0])
            self.assert_stage_stats_is_valid(build_stats.stages[1], self.default_stages_stats_response[1])


class TestXmlReportCollector(unittest.TestCase):
    def test_raises_error_when_json_does_not_exist(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4/build/1/test.json', status_code=404)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_raises_error_when_json_has_invalid_format(self):
        with requests_mock.mock() as m:
            response_text = 'Invalid JSON'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(JSONDecodeError):
                collector.collect()

    def test_raises_error_when_json_has_invalid_structure(self):
        with requests_mock.mock() as m:
            response_text = '{}'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(InvalidJsonFormatError):
                collector.collect()

    def test_raises_error_when_xml_reports_empty(self):
        with requests_mock.mock() as m:
            response_text = '{ "xml_reports": [], "html_report": "" }'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(EmptyXmlReportsListError):
                collector.collect()

    def test_raises_error_when_stats_do_not_exist(self):
        with requests_mock.mock() as m:
            response_text = '{ "xml_reports": ["test1.xml", "test2.xml"], "html_report": "report.html" }'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)
            m.get('http://1.2.3.4/build/1/test1.xml', text='')
            m.get('http://1.2.3.4/build/1/test2.xml', status_code=404)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_raises_error_when_some_fields_do_not_exist(self):
        with requests_mock.mock() as m:
            response_text = '{ "xml_reports": ["report.xml"], "html_report": "report.html" }'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="4">
            </test-results>
            """
            m.get('http://1.2.3.4/build/1/report.xml', text=response_text)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(MissingXmlAttributeError):
                collector.collect()

    def test_raises_error_when_xml_does_not_parse(self):
        with requests_mock.mock() as m:
            response_text = '{ "xml_reports": ["reports/report.xml"], "html_report": "report.html" }'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)
            m.get('http://1.2.3.4/build/1/reports/report.xml', text="this-should-not-parse")

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            with self.assertRaises(ParseError):
                collector.collect()

    def test_collects_basic_stats(self):
        with requests_mock.mock() as m:
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="1" errors="0" failures="0"
                          not-run="0" inconclusive="0" ignored="0"
                          skipped="0" invalid="0">
            </test-results>
            """
            m.get('http://1.2.3.4/build/1/reports/report.xml', text=response_text)
            response_text = '{ "xml_reports": ["reports/report.xml"], "html_report": "pretty/report.html" }'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            test_stats = collector.collect()
            self.assertIsNotNone(test_stats)
            self.assertEqual(test_stats.total, 1)
            self.assertEqual(test_stats.passed, 1)
            self.assertEqual(test_stats.errors, 0)
            self.assertEqual(test_stats.failures, 0)
            self.assertEqual(test_stats.not_run, 0)
            self.assertEqual(test_stats.inconclusive, 0)
            self.assertEqual(test_stats.ignored, 0)
            self.assertEqual(test_stats.skipped, 0)
            self.assertEqual(test_stats.invalid, 0)
            self.assertEqual(test_stats.report_url, 'http://1.2.3.4/build/1/pretty/report.html')

    def test_collects_multiple_stats_with_some_errors(self):
        with requests_mock.mock() as m:
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="4" errors="2" failures="0"
                          not-run="0" inconclusive="0" ignored="0"
                          skipped="0" invalid="0">
            </test-results>
            """
            m.get('http://1.2.3.4/build/1/report1.xml', text=response_text)
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="7" errors="1" failures="2"
                          not-run="0" inconclusive="0" ignored="0"
                          skipped="1" invalid="1">
            </test-results>
            """
            m.get('http://1.2.3.4/build/1/report2.xml', text=response_text)
            response_text = '{ "xml_reports": ["report1.xml", "report2.xml"], "html_report": "report.html" }'
            m.get('http://1.2.3.4/build/1/test.json', text=response_text)

            collector = XmlReportCollector(url='http://1.2.3.4/build/1/test.json')
            test_stats = collector.collect()
            self.assertIsNotNone(test_stats)
            self.assertEqual(test_stats.total, 11)
            self.assertEqual(test_stats.passed, 4)
            self.assertEqual(test_stats.errors, 3)
            self.assertEqual(test_stats.failures, 2)
            self.assertEqual(test_stats.not_run, 0)
            self.assertEqual(test_stats.inconclusive, 0)
            self.assertEqual(test_stats.ignored, 0)
            self.assertEqual(test_stats.skipped, 1)
            self.assertEqual(test_stats.invalid, 1)
            self.assertEqual(test_stats.report_url, 'http://1.2.3.4/build/1/report.html')


if __name__ == '__main__':
    unittest.main()
