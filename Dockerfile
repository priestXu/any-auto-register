# syntax=docker/dockerfile:1.7

FROM node:20-bookworm-slim AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package.json frontend/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY frontend/ ./
RUN npm run build


FROM python:3.12-slim-bookworm AS app

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG no_proxy

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    ALL_PROXY=${ALL_PROXY} \
    NO_PROXY=${NO_PROXY} \
    http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    all_proxy=${all_proxy} \
    no_proxy=${no_proxy}

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libdbus-glib-1-2 \
        libdrm2 \
        libgbm1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxkbcommon0 \
        libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir -r requirements.txt \
    && python -m playwright install --with-deps chromium

RUN useradd --create-home --shell /bin/bash appuser

USER appuser
RUN python -m camoufox fetch

USER root
COPY main.py ./
COPY api ./api
COPY core ./core
COPY platforms ./platforms
COPY services ./services
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
