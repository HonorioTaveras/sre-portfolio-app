# -----------------------------------------------------------------------------
# OpenTelemetry Setup
# Configures distributed tracing for the API service.
# Traces are sent to the OTel Collector which fans them out to
# Grafana Tempo and Datadog simultaneously.
#
# Auto-instrumentation handles FastAPI routes and SQLAlchemy queries
# automatically -- no manual span creation needed for basic tracing.
# -----------------------------------------------------------------------------

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
import os
import logging

logger = logging.getLogger(__name__)


def setup_telemetry(service_name: str) -> None:
    """
    Initialize OpenTelemetry tracing.

    Sets up:
    - TracerProvider with OTLP exporter pointing at the OTel Collector
    - BatchSpanProcessor for efficient span export
    - Auto-instrumentation for FastAPI and SQLAlchemy

    Args:
        service_name: Identifies this service in traces (e.g. "api", "worker")
    """
    # OTEL_EXPORTER_OTLP_ENDPOINT is injected via environment variable.
    # In Kubernetes it points to the OTel Collector service.
    # Locally it can be skipped -- tracing is optional for local dev.
    otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")

    if not otlp_endpoint:
        logger.info("OTEL_EXPORTER_OTLP_ENDPOINT not set -- tracing disabled")
        return

    try:
        # Create a tracer provider -- the central object that manages tracing
        provider = TracerProvider()

        # OTLP exporter sends spans to the OTel Collector over gRPC
        exporter = OTLPSpanExporter(endpoint=otlp_endpoint)

        # BatchSpanProcessor buffers spans and sends them in batches
        # for efficiency -- better than sending one span at a time
        provider.add_span_processor(BatchSpanProcessor(exporter))

        # Register as the global tracer provider
        trace.set_tracer_provider(provider)

        # Auto-instrument FastAPI -- adds spans for every HTTP request
        FastAPIInstrumentor.instrument()

        # Auto-instrument SQLAlchemy -- adds spans for every DB query
        # This is how you see "SELECT * FROM jobs" in your traces
        SQLAlchemyInstrumentor().instrument()

        logger.info(f"Tracing enabled for {service_name} -> {otlp_endpoint}")

    except Exception as e:
        # Never crash the app because tracing failed
        logger.warning(f"Failed to initialize tracing: {e}")
