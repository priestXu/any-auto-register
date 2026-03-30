FROM node:20-bookworm-slim AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build


FROM python:3.12-slim-bookworm AS app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
    && python -m playwright install --with-deps chromium

RUN useradd --create-home --shell /bin/bash appuser

USER appuser
RUN python -m camoufox fetch

USER root
COPY . .
COPY --from=frontend-builder /app/static ./static

RUN mkdir -p /app/data \
    && chown -R appuser:appuser /app /home/appuser /ms-playwright

USER appuser

ENV HOST=0.0.0.0 \
    PORT=8000 \
    SOLVER_PORT=8889 \
    APP_DATA_DIR=/app/data \
    APP_AUTO_START_SOLVER=1 \
    APP_DISABLE_CONDA_WARNING=1 \
    APP_SOLVER_HEADLESS=1 \
    APP_SOLVER_BROWSER_TYPE=camoufox

EXPOSE 8000 8889

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8000/api/health || exit 1

CMD ["python", "main.py"]
