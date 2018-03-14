from collections import namedtuple


BuildStats = namedtuple('BuildStats', [
    'job_name',
    'build_id',
    'build_url',
    'finished_at_secs',
    'status',
    'duration_millis',
    'stages',
    'test_stats'
])

BuildStats.is_build_finished = lambda self: self.status != 'IN_PROGRESS'


StageStats = namedtuple('StageStats', [
    'name',
    'status',
    'duration_millis'
])


TestStats = namedtuple('TestStats', [
    'total',
    'passed',
    'errors',
    'failures',
    'not_run',
    'inconclusive',
    'ignored',
    'skipped',
    'invalid',
    'report_url'
])
