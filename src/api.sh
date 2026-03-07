#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=python-version depName=python packageName=python
PYTHON_VERSION=3.14.3

mise exec python@$PYTHON_VERSION -- pip install -r requirements.txt

WORKDIR=$(dirname "$0")
pushd "$WORKDIR"
mise exec python@$PYTHON_VERSION -- uvicorn api.main:app --host 127.0.0.1 --port 8000
popd
