# AgroBERT: Advanced Agri-Product Price Prediction Using ML
# Multi-stage Docker build for production deployment

# Stage 1: Base Python Runtime
FROM python:3.10-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    wget \
    sqlite3 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Python Dependencies
FROM base as dependencies

# Copy requirements files
COPY requirements.txt ml_requirements.txt ./

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt && \
    pip install -r ml_requirements.txt

# Stage 3: Application Build
FROM dependencies as application

# Copy application code
COPY backend/ ./backend/
COPY frontend/ ./frontend/
COPY db/ ./db/
COPY assets/ ./assets/

# Copy configuration files
COPY .env.example .env
COPY render.yaml ./
COPY Procfile ./

# Create necessary directories
RUN mkdir -p ./logs ./cache ./models && \
    chmod +x ./backend/app_flask.py

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/api/v1/health || exit 1

# Expose port
EXPOSE 5000

# Stage 4: Production Runtime
FROM application as production

# Set non-root user for security
RUN useradd -m -u 1000 agrobert && \
    chown -R agrobert:agrobert /app

USER agrobert

# Run Flask application
CMD ["python", "-m", "backend.app_flask"]

# Stage 5: Development Runtime (optional)
FROM application as development

# Install additional development tools
RUN pip install jupyter jupyterlab ipython pytest pytest-cov black pylint

# Expose Jupyter port
EXPOSE 8888

# Default to Flask app
CMD ["python", "-m", "backend.app_flask"]
