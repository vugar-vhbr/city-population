# Multi-stage build for optimized image size and security

# Stage 1: Builder - Install dependencies
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies to a specific directory
# This allows us to copy only the installed packages to the final image
RUN pip install --no-cache-dir --user -r requirements.txt


# Stage 2: Runtime - Minimal production image
FROM python:3.11-slim

# Create non-root user for security
# Running as root in containers is a security risk
RUN useradd --create-home --shell /bin/bash appuser

# Set working directory
WORKDIR /app

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY app/ /app/app/

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Add user's local bin to PATH
ENV PATH=/home/appuser/.local/bin:$PATH

# Expose application port
EXPOSE 8000

# Health check for Docker/K8s
# Checks if the API is responding every 30 seconds
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Run application with Uvicorn ASGI server
# --host 0.0.0.0: Listen on all interfaces
# --port 8000: Application port
# --workers 1: Number of worker processes (increase for production)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
