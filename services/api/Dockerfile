# -----------------------------------------------------------------------------
# API Service Dockerfile
# Multi-stage build -- keeps the final image small by separating
# the build environment from the runtime environment.
#
# Stage 1 (builder): installs all dependencies
# Stage 2 (runtime): copies only the installed packages, not the build tools
# This typically cuts image size by 50-70% compared to a single stage build
# -----------------------------------------------------------------------------

# ---- Stage 1: Builder ----
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy requirements first -- Docker caches this layer separately.
# If requirements.txt hasn't changed, Docker skips the pip install
# on subsequent builds which saves significant time.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt && \
    pip install --no-cache-dir --prefix=/install "setuptools==69.5.1"


# ---- Stage 2: Runtime ----
FROM python:3.12-slim

# Upgrade OS packages to get latest security patches
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed packages from builder stage only -- no build tools
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ ./app/

# Create a non-root user -- running as root in a container is a security risk
# If the app is compromised, the attacker has limited privileges
RUN useradd --no-create-home --shell /bin/false appuser
USER appuser

# Expose the port uvicorn listens on
EXPOSE 8000

# Start the FastAPI application
# --host 0.0.0.0 makes it accessible from outside the container
CMD ["opentelemetry-instrument", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
