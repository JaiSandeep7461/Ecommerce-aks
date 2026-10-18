# syntax=docker/dockerfile:1

# Pin the Python security release and Debian family. The explicit Bookworm
# tag avoids stale Debian 13 system-Python package metadata from the moving
# python:3.12-slim tag while staying on the Python 3.12 security branch.
FROM --platform=linux/amd64 python:3.12.15-slim-bookworm AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir .

FROM --platform=linux/amd64 python:3.12.15-slim-bookworm AS runtime
# Pull in available Debian security updates. The application runs from its
# isolated venv, so it does not need a distribution-wide Python package set.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y --purge autoremove \
    && rm -rf /var/lib/apt/lists/*
# Keep the runtime installer current; no application build step runs here.
RUN python -m pip install --no-cache-dir --upgrade pip setuptools
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
COPY --from=build /opt/venv /opt/venv
COPY app ./app

USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz', timeout=2).status == 200 else 1)"]

CMD ["python", "-m", "app.main"]
