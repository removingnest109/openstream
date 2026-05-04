#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DB_PATH="${DB_PATH:-$PWD/openstream.db}"
MUSIC_LIBRARY_PATH="${MUSIC_LIBRARY_PATH:-$PWD/music}"
PORT="${PORT:-9090}"

mkdir -p "$(dirname "$DB_PATH")" "$MUSIC_LIBRARY_PATH"

go run ./cmd/server
