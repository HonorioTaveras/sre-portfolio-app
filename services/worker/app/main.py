# -----------------------------------------------------------------------------
# Worker Service -- Main Application
# Polls SQS for job messages, processes them, and updates job status in Postgres.
#
# This service uses the Datadog ddtrace library for APM instrumentation
# instead of the OTel SDK used in the API service. This gives us both
# approaches to demonstrate and discuss in interviews.
#
# Endpoints:
#   GET /health  -- liveness/readiness probe
#   GET /metrics -- Prometheus metrics scrape endpoint
# -----------------------------------------------------------------------------

from fastapi import FastAPI
from fastapi.responses import Response
from contextlib import asynccontextmanager
from prometheus_client import (
    Counter, Histogram, Gauge,
    generate_latest, CONTENT_TYPE_LATEST
)
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Text
from sqlalchemy.orm import sessionmaker, declarative_base
from datetime import datetime, timezone
import boto3
import os
import json
import time
import asyncio
import logging

from .processor import process_job

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)
logger = logging.getLogger(__name__)

# -----------------------------------------------------------------------------
# Database setup -- mirrors the API service connection
# -----------------------------------------------------------------------------
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://sre_admin:devpassword123!@localhost:5432/sre_portfolio"
)

engine       = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base         = declarative_base()


class Job(Base):
    """Mirror of the Job model from the API service."""
    __tablename__ = "jobs"
    id         = Column(Integer, primary_key=True, index=True)
    payload    = Column(Text, nullable=False)
    status     = Column(String(50), default="queued")
    result     = Column(Text, nullable=True)
    error      = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))


# -----------------------------------------------------------------------------
# Prometheus Metrics
# -----------------------------------------------------------------------------

# Tracks how many jobs were processed and whether they succeeded or failed
JOBS_PROCESSED = Counter(
    "worker_jobs_processed_total",
    "Total jobs processed by the worker",
    ["status"]  # success or failed
)

# Measures how long each job takes to process
JOB_DURATION = Histogram(
    "worker_job_duration_seconds",
    "Job processing duration in seconds",
    buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0]
)

# Shows how many jobs are currently being processed
# Useful for detecting stuck workers
JOBS_IN_FLIGHT = Gauge(
    "worker_jobs_in_flight",
    "Number of jobs currently being processed"
)

# Tracks SQS poll attempts -- useful for confirming the loop is running
SQS_POLLS = Counter(
    "worker_sqs_polls_total",
    "Total SQS poll attempts",
    ["result"]  # messages_found or empty
)


# -----------------------------------------------------------------------------
# SQS Polling Loop
# Runs as a background asyncio task alongside the FastAPI server.
# -----------------------------------------------------------------------------
async def poll_sqs():
    """
    Background task that continuously polls SQS for job messages.

    Uses long polling (WaitTimeSeconds=10) which keeps the connection
    open for up to 10 seconds waiting for messages. More efficient
    than short polling which returns immediately if the queue is empty.
    """
    queue_url = os.environ.get("SQS_QUEUE_URL")

    if not queue_url:
        logger.warning("SQS_QUEUE_URL not set -- SQS polling disabled")
        return

    sqs = boto3.client(
        "sqs",
        region_name=os.environ.get("AWS_REGION", "us-east-1")
    )

    logger.info(f"Starting SQS polling loop for queue: {queue_url}")

    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=10,      # Long polling
                VisibilityTimeout=300    # Hide message for 5 min while processing
            )

            messages = response.get("Messages", [])

            if not messages:
                SQS_POLLS.labels("empty").inc()
                await asyncio.sleep(1)
                continue

            SQS_POLLS.labels("messages_found").inc()
            logger.info(f"Received {len(messages)} messages from SQS")

            for message in messages:
                await process_message(sqs, queue_url, message)

        except Exception as e:
            logger.error(f"SQS polling error: {e}")
            await asyncio.sleep(5)  # Back off on error before retrying


async def process_message(sqs_client, queue_url: str, message: dict):
    """
    Process a single SQS message end to end.

    Workflow:
        1. Parse message to get job_id
        2. Load job from Postgres
        3. Update status to 'processing'
        4. Run process_job()
        5. Update status to 'completed' or 'failed'
        6. Delete message from SQS on success
    """
    db         = SessionLocal()
    start_time = time.time()
    job        = None

    try:
        body   = json.loads(message["Body"])
        job_id = body["job_id"]

        logger.info(f"Processing job {job_id}")
        JOBS_IN_FLIGHT.inc()

        job = db.query(Job).filter(Job.id == job_id).first()

        if not job:
            logger.error(f"Job {job_id} not found in database")
            sqs_client.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=message["ReceiptHandle"]
            )
            return

        # Mark as processing
        job.status     = "processing"
        job.updated_at = datetime.now(timezone.utc)
        db.commit()

        # Do the work
        payload = json.loads(job.payload)
        result  = process_job(payload)

        # Mark as completed
        job.status     = "completed"
        job.result     = json.dumps(result)
        job.updated_at = datetime.now(timezone.utc)
        db.commit()

        duration = time.time() - start_time
        JOBS_PROCESSED.labels("success").inc()
        JOB_DURATION.observe(duration)

        logger.info(f"Job {job_id} completed in {duration:.2f}s")

        # Delete from SQS -- processed successfully, no need to retry
        sqs_client.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=message["ReceiptHandle"]
        )

    except Exception as e:
        logger.error(f"Failed to process job: {e}")

        # Mark job as failed
        try:
            if job:
                job.status     = "failed"
                job.error      = str(e)
                job.updated_at = datetime.now(timezone.utc)
                db.commit()
        except Exception as db_error:
            logger.error(f"Failed to update job status: {db_error}")

        JOBS_PROCESSED.labels("failed").inc()
        # Do NOT delete the message -- SQS will retry up to maxReceiveCount
        # then move it to the DLQ automatically

    finally:
        JOBS_IN_FLIGHT.dec()
        db.close()


# -----------------------------------------------------------------------------
# Application Lifespan
# -----------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    polling_task = asyncio.create_task(poll_sqs())
    logger.info("Worker service started")
    yield
    polling_task.cancel()
    logger.info("Worker service stopped")


app = FastAPI(
    title="SRE Portfolio Worker",
    description="Background job processor",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/health")
def health():
    """Health check for Kubernetes probes."""
    return {"status": "ok", "service": "worker"}


@app.get("/metrics")
def metrics():
    """Prometheus metrics scrape endpoint."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )
