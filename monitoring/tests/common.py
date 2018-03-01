from stats import BuildStats


def get_build_stats_with_status(status):
    return BuildStats(
        job_name = 'Test',
        build_id = 1,
        build_url = 'http://1.2.3.4/',
        finished_at_secs = 2,
        status = status,
        duration_millis = 3,
        stages = [],
    )