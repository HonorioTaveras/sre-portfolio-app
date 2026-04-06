# -----------------------------------------------------------------------------
# OpenTelemetry Setup
# Configures distributed tracing using environment-variable-driven
# auto-configuration. The OTel SDK reads OTEL_EXPORTER_OTLP_ENDPOINT
# automatically when we initialize the TracerProvider.
# -----------------------------------------------------------------------------
import os
import logging

logger = logging.getLogger(__name__)


def setup_telemetry(service_name: str) -> None:
    """
    Initialize OpenTelemetry tracing.
    Uses explicit SDK setup with resource attributes for service identification.
    """
    otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not otlp_endpoint:
        logger.info("OTEL_EXPORTER_OTLP_ENDPOINT not set -- tracing disabled")
        return

    try:
        from opentelemetry import trace
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import SimpleSpanProcessor
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

        # Resource identifies this service in traces
        resource = Resource.create({
            "service.name": service_name,
            "service.version": os.environ.get("DD_VERSION", "unknown"),
            "deployment.environment": os.environ.get("DD_ENV", "dev"),
        })

        # Create provider with resource
        provider = TracerProvider(resource=resource)

        # Configure OTLP exporter
        # insecure=True is set via environment variable for 1.27.0 compatibility
        os.environ["OTEL_EXPORTER_OTLP_INSECURE"] = "true"
        exporter = OTLPSpanExporter(
            endpoint=otlp_endpoint,
        )

        # Batch processor -- buffers spans and exports in batches
        processor = SimpleSpanProcessor(exporter)
        provider.add_span_processor(processor)

        # Register as the global provider -- this is the critical step
        trace.set_tracer_provider(provider)

        logger.info(f"TracerProvider configured: {provider}")
        logger.info(f"Exporter endpoint: {otlp_endpoint}")

        # Auto-instrument FastAPI
        try:
            from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
            FastAPIInstrumentor().instrument()
            logger.info("FastAPI auto-instrumentation enabled")
        except Exception as e:
            logger.warning(f"FastAPI instrumentation unavailable: {e}")

        # Auto-instrument SQLAlchemy
        try:
            from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
            SQLAlchemyInstrumentor().instrument()
            logger.info("SQLAlchemy auto-instrumentation enabled")
        except Exception as e:
            logger.warning(f"SQLAlchemy instrumentation unavailable: {e}")

        logger.info(f"Tracing enabled for {service_name} -> {otlp_endpoint}")

    except Exception as e:
        logger.warning(f"Failed to initialize tracing: {e}", exc_info=True)
