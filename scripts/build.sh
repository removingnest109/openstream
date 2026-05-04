#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
go mod tidy
go build -o bin/openstream ./cmd/server
