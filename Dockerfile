# syntax=docker/dockerfile:1.7
# -------- Frontend build --------
FROM node:20-alpine AS frontend
WORKDIR /build
COPY frontend/package.json frontend/package-lock.json* ./
RUN --mount=type=cache,target=/root/.npm \
    npm install --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

# -------- Runtime --------
FROM python:3.12-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    STATIC_DIR=/app/static \
    DATA_DIR=/data

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends tini ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/app ./app
COPY --from=frontend /build/dist ./static

RUN groupadd -r raptorr && useradd -r -g raptorr -u 10001 raptorr \
    && mkdir -p /data && chown -R raptorr:raptorr /app /data

USER raptorr

VOLUME ["/data"]
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/api/health',timeout=3).status==200 else 1)"

ENTRYPOINT ["tini", "--"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
