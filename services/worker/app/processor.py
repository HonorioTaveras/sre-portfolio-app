# -----------------------------------------------------------------------------
# Job Processor
# Contains the actual business logic for processing jobs.
# Kept separate from main.py so it's easy to test in isolation.
#
# In a real system this might call external APIs, run ML models,
# generate reports, send emails etc. For this project it simulates
# work with a sleep and returns a result.
# -----------------------------------------------------------------------------

import json
import time
import logging

logger = logging.getLogger(__name__)


def process_job(payload: dict) -> dict:
    """
    Process a job payload and return a result.

    In a real system this function would do meaningful work.
    Here it simulates processing time and returns a result
    so we can demonstrate the full job lifecycle.

    Args:
        payload: The job payload submitted via POST /jobs

    Returns:
        result: Dict containing the processing result

    Raises:
        ValueError: If the payload is missing required fields
        Exception: Any processing errors bubble up to the caller
    """
    logger.info(f"Processing payload: {payload}")

    # Simulate work -- in a real system this would be your business logic
    processing_time = payload.get("processing_time", 1)
    time.sleep(min(processing_time, 5))  # Cap at 5 seconds for safety

    result = {
        "processed": True,
        "input":     payload,
        "output":    f"Processed {len(json.dumps(payload))} bytes",
        "duration":  processing_time
    }

    logger.info(f"Processing complete: {result}")
    return result
