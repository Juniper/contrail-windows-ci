import time


class FinishedBuildStatsPublisher(object):

    def __init__(self, collector, publisher):
        self.collector = collector
        self.publisher = publisher

    def collect_and_publish(self, delay_ms=1000):
        while True:
            stats = self.collector.collect()
            if stats.status != 'IN_PROGRESS':
                break

            time.sleep(delay_ms / 1000.0)

        self.publisher.publish(stats)
