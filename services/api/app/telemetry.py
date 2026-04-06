# -----------------------------------------------------------------------------
# OpenTelemetry Setup
# Configures distributed tracing for the API service.
# Traces are sent to the OTel Collector which fans them out to
# Grafana Tempo and Datadog simultaneously.
#
# Uses lazy imports so the app starts successfully even if OTel
# packages have compatibility issues -- tracing is observability
# infrastructure and should never crash the application.
# -----------------------------------------------------------------------------

import os
import logging
# Ensure pkg_resources is available for OTel instrumentation packages
import pkg_resources  # noqa: F401

logger = logging.getLogger(__name__)


def setup_telemetry(service_name: str) -> None:
    """
    Initialize OpenTelemetry tracing.

    Gracefully handles missing or incompatible OTel packages --
    the application always starts, tracing is best-effort.

    Args:
        service_name: Identifies this service in traces
    """
    otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")

    if not otlp_endpoint:
        logger.info("OTEL_EXPORTER_OTLP_ENDPOINT not set -- tracing disabled")
        return

    try:
        from opentelemetry import trace
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

        provider = TracerProvider()
        exporter = OTLPSpanExporter(endpoint=otlp_endpoint)
        provider.add_span_processor(BatchSpanProcessor(exporter))
        trace.set_tracer_provider(provider)

        # Auto-instrument FastAPI and SQLAlchemy
        try:
            from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
            FastAPIInstrumentor.instrument()
            logger.info("FastAPI auto-instrumentation enabled")
        except Exception as e:
            logger.warning(f"FastAPI instrumentation unavailable: {e}")

        try:
            from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
            SQLAlchemyInstrumentor().instrument()
            logger.info("SQLAlchemy auto-instrumentation enabled")
        except Exception as e:
            logger.warning(f"SQLAlchemy instrumentation unavailable: {e}")

        logger.info(f"Tracing enabled for {service_name} -> {otlp_endpoint}")

    except Exception as e:
        # Never crash the app because tracing failed
        logger.warning(f"Failed to initialize tracing: {e}")
