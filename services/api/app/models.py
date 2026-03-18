# -----------------------------------------------------------------------------
# Database Models
# SQLAlchemy ORM models that map Python classes to database tables.
# The Job model represents a unit of work submitted via the API
# and processed by the worker service.
# -----------------------------------------------------------------------------

from sqlalchemy import Column, Integer, String, DateTime, Text
from sqlalchemy.orm import declarative_base
from datetime import datetime, timezone

Base = declarative_base()


class Job(Base):
    """
    Represents a job submitted to the system.

    Lifecycle:
        queued -> processing -> completed
                            -> failed
    """
    __tablename__ = "jobs"

    id         = Column(Integer, primary_key=True, index=True)
    payload    = Column(Text, nullable=False)          # JSON string of job input
    status     = Column(String(50), default="queued")  # queued, processing, completed, failed
    result     = Column(Text, nullable=True)           # JSON string of job output
    error      = Column(Text, nullable=True)           # Error message if failed
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))

    def __repr__(self):
        return f"<Job id={self.id} status={self.status}>"
