# syntax=docker/dockerfile:1

# Pin the Python patch release and use Debian Trixie for the runtime OS.
FROM --platform=linux/amd64 python:3.12.15-slim-trixie AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir . && \
    python -m pip check

FROM --platform=linux/amd64 python:3.12.15-slim-trixie AS runtime
# Apply current OS security updates before copying only the application runtime.
RUN apt-get update \
    && apt-get -y upgrade \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
COPY --from=build /opt/venv /opt/venv
COPY app ./app

# pip, setuptools, and wheel are build/install tools, not runtime requirements.
# Removing them also removes pip's embedded vendor SBOM, which otherwise makes
# Trivy report obsolete vendored package versions as if they were installed
# application dependencies (including msgpack 1.1.2, setuptools 70.3.0, and
# urllib3 2.7.0). App dependencies remain installed in /opt/venv.
RUN find /usr/local/lib/python3.12/site-packages /opt/venv/lib/python3.12/site-packages \
      -maxdepth 1 \
      \( -name 'pip' -o -name 'pip-*.dist-info' \
         -o -name 'setuptools' -o -name 'setuptools-*.dist-info' \
         -o -name 'wheel' -o -name 'wheel-*.dist-info' \) \
      -exec rm -rf {} + \
    && rm -f /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.12 \
       /opt/venv/bin/pip /opt/venv/bin/pip3 /opt/venv/bin/pip3.12

USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os,urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz', timeout=2).status == 200 else 1)"]

CMD ["python", "-m", "app.main"]
