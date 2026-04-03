# -----------------------------------------------------------------------------
# API Service Tests
# Basic integration tests that run against a real Postgres database.
# These tests verify the core job lifecycle works end to end.
#
# The test database is spun up as a Docker service in GitHub Actions.
# Locally you can run: pytest services/api/tests/ -v
# with docker-compose postgres running.
# -----------------------------------------------------------------------------

import pytest
import json
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

# Set test database URL before importing the app
# This overrides the default DATABASE_URL in db.py
os.environ["DATABASE_URL"] = os.environ.get(
    "DATABASE_URL",
    "postgresql://test:test@localhost:5432/test_db"
)
os.environ["SQS_QUEUE_URL"] = ""  # Disable SQS in tests

from app.main import app
from app.db import get_db, engine
from app.models import Base

# Create all tables in the test database
Base.metadata.create_all(bind=engine)

# Create a test client -- simulates HTTP requests without running a real server
client = TestClient(app)


def test_health():
    """Health endpoint should always return 200 with status ok."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["service"] == "api"


def test_create_job():
    """Creating a job should return 201 with a job_id."""
    response = client.post(
        "/jobs",
        json={"task": "test_task", "processing_time": 1}
    )
    assert response.status_code == 201
    data = response.json()
    assert "job_id" in data
    assert data["status"] == "queued"


def test_get_job():
    """Getting a job by ID should return the job details."""
    # First create a job
    create_response = client.post(
        "/jobs",
        json={"task": "test_get", "processing_time": 1}
    )
    job_id = create_response.json()["job_id"]

    # Then retrieve it
    get_response = client.get(f"/jobs/{job_id}")
    assert get_response.status_code == 200
    data = get_response.json()
    assert data["id"] == job_id
    assert data["status"] == "queued"


def test_get_job_not_found():
    """Getting a non-existent job should return 404."""
    response = client.get("/jobs/99999")
    assert response.status_code == 404


def test_list_jobs():
    """Listing jobs should return a list with count."""
    response = client.get("/jobs")
    assert response.status_code == 200
    data = response.json()
    assert "jobs" in data
    assert "count" in data
    assert isinstance(data["jobs"], list)


def test_metrics():
    """Metrics endpoint should return Prometheus format data."""
    response = client.get("/metrics")
    assert response.status_code == 200
    # Prometheus metrics always contain this header
    assert b"# HELP" in response.content
