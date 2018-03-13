import re
import requests
from collectors.exceptions import InvalidResponseCodeError
from stats import TestStats
from xml.etree import ElementTree


class MissingXmlAttributeError(Exception):
    pass


class XmlReportCollector(object):
    def __init__(self, url):
        self.url = url

    def collect(self):
        resp = requests.get(self.url)
        if resp.status_code != 200:
            raise InvalidResponseCodeError()
        else:
            counts = self._get_test_counts(resp.text)
            return TestStats(report_url=self._report_url_from_xml_url(), **counts)

    def _get_test_counts(self, text):
        root = ElementTree.fromstring(text)

        counts = {}
        try:
            counts['total'] = int(root.attrib['total'])
            counts['errors'] = int(root.attrib['errors'])
            counts['failures'] = int(root.attrib['failures'])
            counts['not_run'] = int(root.attrib['not-run'])
            counts['inconclusive'] = int(root.attrib['inconclusive'])
            counts['ignored'] = int(root.attrib['ignored'])
            counts['skipped'] = int(root.attrib['skipped'])
            counts['invalid'] = int(root.attrib['invalid'])
        except KeyError:
            raise MissingXmlAttributeError()

        counts['passed'] = counts['total'] - sum(v for k, v in counts.items() if k != 'total')

        return counts

    def _report_url_from_xml_url(self):
        return re.sub(r'\.xml$', r'.html', self.url)
