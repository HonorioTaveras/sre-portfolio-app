# -----------------------------------------------------------------------------
# API Service -- Main Application
# FastAPI application that accepts job submissions, writes them to Postgres,
# and enqueues them to SQS for the worker service to process.
#
# Endpoints:
#   GET  /health   -- liveness/readiness probe for Kubernetes
#   GET  /metrics  -- Prometheus metrics scrape endpoint
#   POST /jobs     -- submit a new job
#   GET  /jobs/:id -- get job status and result
# -----------------------------------------------------------------------------

from fastapi import FastAPI, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from contextlib import asynccontextmanager
from prometheus_client import (
    Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
)
import boto3
import os
import json
import time
import logging

from .db import get_db, engine
from .models import Base, Job
from .telemetry import setup_telemetry

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)
logger = logging.getLogger(__name__)

# -----------------------------------------------------------------------------
# Prometheus Metrics
# These are the custom metrics your Grafana dashboards will visualize.
# Prometheus scrapes them from the /metrics endpoint.
# -----------------------------------------------------------------------------

# Counts every request broken down by method, endpoint, and status code
REQUEST_COUNT = Counter(
    "api_requests_total",
    "Total number of API requests",
    ["method", "endpoint", "status"]
)

# Measures how long each request takes -- used for p99 latency dashboards
REQUEST_LATENCY = Histogram(
    "api_request_duration_seconds",
    "API request duration in seconds",
    ["endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

# Tracks jobs by status -- lets you see queued vs completed vs failed over time
JOB_STATUS_COUNT = Counter(
    "api_jobs_total",
    "Total jobs created by status",
    ["status"]
)


# -----------------------------------------------------------------------------
# Application Lifespan
# Code here runs once on startup and once on shutdown.
# Used to create DB tables and initialize tracing.
# -----------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting API service")
    Base.metadata.create_all(bind=engine)  # Create tables if they don't exist
    setup_telemetry(service_name="sre-portfolio-api")
    yield
    # Shutdown
    logger.info("Shutting down API service")


app = FastAPI(
    title="SRE Portfolio API",
    description="Job submission and status API",
    version="1.0.0",
    lifespan=lifespan
)


# -----------------------------------------------------------------------------
# Routes
# -----------------------------------------------------------------------------

@app.get("/health")
def health():
    """
    Health check endpoint.
    Kubernetes readiness and liveness probes hit this endpoint.
    Returns 200 OK when the service is ready to accept traffic.
    """
    return {"status": "ok", "service": "api"}


@app.get("/metrics")
def metrics():
    """
    Prometheus metrics endpoint.
    Prometheus scrapes this on a schedule (default every 15s).
    The pod annotation prometheus.io/scrape: "true" tells Prometheus
    to discover and scrape this endpoint automatically.
    """
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


@app.post("/jobs", status_code=201)
def create_job(payload: dict, db: Session = Depends(get_db)):
    """
    Submit a new job for processing.

    Creates a job record in Postgres with status 'queued',
    then sends a message to SQS so the worker picks it up.

    Args:
        payload: Arbitrary JSON dict describing the work to be done

    Returns:
        job_id: The ID to use for polling job status
    """
    start_time = time.time()

    try:
        # Write job to database
        job = Job(
            payload=json.dumps(payload),
            status="queued"
        )
        db.add(job)
        db.commit()
        db.refresh(job)

        logger.info(f"Created job {job.id} with payload {payload}")

        # Send message to SQS so the worker picks it up
        # SQS_QUEUE_URL is injected as an environment variable
        queue_url = os.environ.get("SQS_QUEUE_URL")
        if queue_url:
            sqs = boto3.client(
                "sqs",
                region_name=os.environ.get("AWS_REGION", "us-east-1")
            )
            sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps({"job_id": job.id})
            )
            logger.info(f"Enqueued job {job.id} to SQS")
        else:
            # SQS not configured -- local dev mode
            logger.warning("SQS_QUEUE_URL not set -- job created but not enqueued")

        # Record metrics
        REQUEST_COUNT.labels("POST", "/jobs", "201").inc()
        REQUEST_LATENCY.labels("/jobs").observe(time.time() - start_time)
        JOB_STATUS_COUNT.labels("queued").inc()

        return {"job_id": job.id, "status": job.status}

    except Exception as e:
        logger.error(f"Failed to create job: {e}")
        REQUEST_COUNT.labels("POST", "/jobs", "500").inc()
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/jobs/{job_id}")
def get_job(job_id: int, db: Session = Depends(get_db)):
    """
    Get the status and result of a job.

    Args:
        job_id: The job ID returned from POST /jobs

    Returns:
        Job details including current status and result if completed
    """
    start_time = time.time()

    job = db.query(Job).filter(Job.id == job_id).first()

    if not job:
        REQUEST_COUNT.labels("GET", "/jobs/{id}", "404").inc()
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")

    REQUEST_COUNT.labels("GET", "/jobs/{id}", "200").inc()
    REQUEST_LATENCY.labels("/jobs/{id}").observe(time.time() - start_time)

    return {
        "id":         job.id,
        "status":     job.status,
        "payload":    json.loads(job.payload),
        "result":     json.loads(job.result) if job.result else None,
        "error":      job.error,
        "created_at": job.created_at.isoformat(),
        "updated_at": job.updated_at.isoformat()
    }


@app.get("/jobs")
def list_jobs(
    status: str = None,
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """
    List jobs with optional status filter.

    Args:
        status: Optional filter -- queued, processing, completed, failed
        limit:  Max number of jobs to return (default 20)
    """
    query = db.query(Job)

    if status:
        query = query.filter(Job.status == status)

    jobs = query.order_by(Job.created_at.desc()).limit(limit).all()

    return {
        "jobs": [
            {
                "id":         j.id,
                "status":     j.status,
                "created_at": j.created_at.isoformat()
            }
            for j in jobs
        ],
        "count": len(jobs)
    }
