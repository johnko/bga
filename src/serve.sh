#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=python-version depName=python packageName=python
PYTHON_VERSION=3.14.3

# renovate: datasource=golang-version depName=golang packageName=golang
GOLANG_VERSION=1.25.8

WORKDIR=$(dirname "$0")
pushd "$WORKDIR"
# mise exec python@$PYTHON_VERSION -- pip install -r requirements.txt
# mise exec python@$PYTHON_VERSION -- uvicorn api.main:app --host 127.0.0.1 --port 8000
mise exec go@$GOLANG_VERSION -- go clean
mise exec go@$GOLANG_VERSION -- go run ./golang/api/main.go
popd
