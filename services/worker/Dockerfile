# -----------------------------------------------------------------------------
# Worker Service Dockerfile
# Uses ddtrace-run to wrap uvicorn for Datadog APM auto-instrumentation.
# ddtrace-run automatically traces all requests and database queries
# without any code changes to the application itself.
# -----------------------------------------------------------------------------

# ---- Stage 1: Builder ----
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy requirements first for Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---- Stage 2: Runtime ----
FROM python:3.12-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ ./app/

# Non-root user for security
RUN useradd --no-create-home --shell /bin/false appuser
USER appuser

# Worker runs on port 8001 to avoid conflict with API on 8000
EXPOSE 8001

# ddtrace-run wraps uvicorn and instruments it automatically
# DD_AGENT_HOST and DD_TRACE_AGENT_PORT injected via environment variables
CMD ["ddtrace-run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
