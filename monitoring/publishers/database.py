from sqlalchemy import BigInteger, ForeignKey, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base


MonitoringBase = declarative_base()


class Build(MonitoringBase):
    __tablename__ = 'builds'

    id = Column(Integer, primary_key=True)
    job_name = Column(String(4096), nullable=False)
    build_id = Column(Integer, nullable=False)
    build_url = Column(String(4096), nullable=False)
    finished_at_secs = Column(BigInteger, nullable=False)
    status = Column(String(4096), nullable=False)
    duration_millis = Column(BigInteger, nullable=False)

    @classmethod
    def from_build_stats(cls, build_stats):
        build = cls(
            job_name = build_stats.job_name,
            build_id = build_stats.build_id,
            build_url = build_stats.build_url,
            finished_at_secs = build_stats.finished_at_secs,
            status = build_stats.status,
            duration_millis = build_stats.duration_millis,
        )

        build.stages = [Stage.from_stage_stats(stage) for stage in build_stats.stages]

        return build

    def __repr__(self):
        return "<Build(id={}, name={}, build_id={})>".format(self.id, self.job_name, self.build_id)


class Stage(MonitoringBase):
    __tablename__ = 'stages'

    id = Column(Integer, primary_key=True)
    build_id = Column(Integer, ForeignKey('builds.id'))
    name = Column(String(4096), nullable=False)
    status = Column(String(4096), nullable=False)
    duration_millis = Column(BigInteger, nullable=False)

    build = relationship('Build', back_populates='stages')

    @classmethod
    def from_stage_stats(cls, stage_stats):
        return cls(
            name = stage_stats.name,
            status = stage_stats.status,
            duration_millis = stage_stats.duration_millis,
        )

    def __repr__(self):
        return "<Stage(id={}, build_id={}, name={})>".format(self.id, self.build.build_id, self.name)


Build.stages = relationship('Stage', order_by=Stage.id, back_populates='build')
