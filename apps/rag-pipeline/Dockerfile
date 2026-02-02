# =============================================================================
# RAG Pipeline Docker Image
# =============================================================================
# Multi-stage build for minimal image size
# =============================================================================

FROM python:3.11-slim as builder

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# =============================================================================
# Production image
# =============================================================================

FROM python:3.11-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy application
COPY rag_pipeline.py .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('${QDRANT_URL}/collections', timeout=5)" || exit 1

# Default command (interactive mode)
ENTRYPOINT ["python", "rag_pipeline.py"]
CMD ["--help"]
