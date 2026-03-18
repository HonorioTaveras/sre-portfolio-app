# -----------------------------------------------------------------------------
# Database Connection
# Manages the SQLAlchemy engine and session factory.
# get_db() is a FastAPI dependency that provides a database session
# to route handlers and automatically closes it when the request is done.
# -----------------------------------------------------------------------------

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator
import os


# DATABASE_URL is injected as an environment variable.
# Format: postgresql://username:password@host:port/dbname
# In Kubernetes this comes from a secret mounted into the pod.
# For local development it comes from docker-compose.
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://sre_admin:devpassword123!@localhost:5432/sre_portfolio"
)

# create_engine sets up the connection pool.
# pool_pre_ping=True checks connections before using them,
# which handles cases where the DB restarted.
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    echo=False  # Set to True to log all SQL queries for debugging
)

# SessionLocal is the factory for creating database sessions
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency that provides a database session per request.

    Usage in a route:
        @app.get("/jobs")
        def list_jobs(db: Session = Depends(get_db)):
            return db.query(Job).all()

    The session is automatically closed after the request completes,
    even if an exception is raised.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
