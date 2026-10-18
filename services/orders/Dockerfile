# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 python:3.12-slim AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir .

FROM --platform=linux/amd64 python:3.12-slim AS runtime
# Pull in all available Debian security updates. The scanner currently reports
# these Python packages from Debian's system site-packages as vulnerable; the
# application runs from /opt/venv, so remove the unused distro copies rather
# than leaving duplicate old metadata in the runtime image.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y purge python3-setuptools python3-urllib3 python3-msgpack \
    && apt-get -y --purge autoremove \
    && rm -rf /var/lib/apt/lists/*
# The application runtime does not need pip's build tooling, but keeping the
# remaining system pip current avoids shipping a known vulnerable installer.
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
