# Multi-stage Dockerfile for HealthLink
# Supports both FastAPI backend and Streamlit UI
# Build arg: SERVICE_TYPE (api or ui)

ARG SERVICE_TYPE=api

FROM python:3.12-slim as builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Final stage
FROM python:3.12-slim

ARG SERVICE_TYPE=api

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH" \
    SERVICE_TYPE=${SERVICE_TYPE}

# Set port based on service type
ENV PORT=${SERVICE_TYPE:+8501}
ENV PORT=${PORT:-8000}

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Create app directory
WORKDIR /app

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/data /app/logs

# Create non-root user
RUN useradd -m -u 1000 healthlink && \
    chown -R healthlink:healthlink /app
USER healthlink

# Expose port (default 8000 for API, 8501 for UI)
EXPOSE ${PORT}

# Health check - differs by service type
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD if [ "$SERVICE_TYPE" = "ui" ]; then \
            curl -f http://localhost:8501/_stcore/health || exit 1; \
        else \
            curl -f http://localhost:8000/api/v1/health || exit 1; \
        fi

# Run application based on SERVICE_TYPE
CMD if [ "$SERVICE_TYPE" = "ui" ]; then \
        exec streamlit run ui/streamlit_app.py --server.port=8501 --server.address=0.0.0.0; \
    else \
        exec uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1; \
    fi
