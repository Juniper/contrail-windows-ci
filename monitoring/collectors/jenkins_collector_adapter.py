import requests
from collector import ICollector
from stats import BuildStats, StageStats


class InvalidResponseCodeError(Exception):
    pass


class JenkinsCollectorAdapter(ICollector):

    def __init__(self, job_name, build_url):
        self.job_name = job_name
        self.url = build_url


    def collect(self):
        resp = self.get_raw_stats_from_jenkins()
        return self.convert_raw_stats_to_build_stats(resp)


    def get_raw_stats_from_jenkins(self):
        endpoint = self.get_build_stats_endpoint(self.url)
        resp = requests.get(endpoint)

        if resp.status_code != 200:
            raise InvalidResponseCodeError()

        return resp.json()


    def convert_raw_stats_to_build_stats(self, raw_stats):
        timestamp = int(raw_stats['endTimeMillis'] / 1000)

        stages_stats = []

        if 'stages' in raw_stats.keys():
            for raw_stage in raw_stats['stages']:
                stage = StageStats(
                    name = raw_stage['name'],
                    status = raw_stage['status'],
                    duration_millis = raw_stage['durationMillis']
                )
                stages_stats.append(stage)

        build_stats = BuildStats(
            job_name = self.job_name,
            build_url = self.url,
            build_id = raw_stats['id'],
            finished_at_secs = timestamp,
            status = raw_stats['status'],
            duration_millis = raw_stats['durationMillis'],
            stages = stages_stats,
        )

        return build_stats


    @classmethod
    def get_build_stats_endpoint(cls, build_url):
        return '{}/wfapi/describe'.format(build_url)
