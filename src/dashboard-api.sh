#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=python-version depName=python packageName=python
PYTHON_VERSION=3.13.11

mise exec python@$PYTHON_VERSION -- pip install "fastapi[standard]"

WORKDIR=$(dirname "$0")
pushd "$WORKDIR"
  mise exec python@$PYTHON_VERSION -- fastapi dev dashboard-api.py
popd
