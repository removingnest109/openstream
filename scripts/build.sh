#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/bin}"
TARGET="${1:-native}"

mkdir -p "$OUT_DIR"

if [[ ! -f "$ROOT_DIR/internal/webassets/frontend/build/index.html" ]]; then
	echo "Missing embedded web assets in internal/webassets/frontend/build." >&2
	echo "Run 'cd internal/webassets/frontend && npm install && npm run build' first." >&2
	exit 1
fi

case "$TARGET" in
	linux-arm64)
		GOOS_VALUE="linux"
		GOARCH_VALUE="arm64"
		GOARM_VALUE=""
		OUTPUT_NAME="openstream-linux-arm64"
		;;
	linux-armv7)
		GOOS_VALUE="linux"
		GOARCH_VALUE="arm"
		GOARM_VALUE="7"
		OUTPUT_NAME="openstream-linux-armv7"
		;;
	native)
		GOOS_VALUE="$(go env GOOS)"
		GOARCH_VALUE="$(go env GOARCH)"
		GOARM_VALUE="$(go env GOARM 2>/dev/null || true)"
		OUTPUT_NAME="openstream-${GOOS_VALUE}-${GOARCH_VALUE}"
		if [[ "$GOARCH_VALUE" == "arm" && -n "$GOARM_VALUE" ]]; then
			OUTPUT_NAME+="v${GOARM_VALUE}"
		fi
		;;
	*)
		echo "Usage: $0 [linux-arm64|linux-armv7|native]" >&2
		exit 1
		;;
esac

OUTPUT_PATH="$OUT_DIR/$OUTPUT_NAME"

echo "Building $OUTPUT_NAME..."

if [[ -n "$GOARM_VALUE" && "$GOARCH_VALUE" == "arm" ]]; then
	GOOS="$GOOS_VALUE" GOARCH="$GOARCH_VALUE" GOARM="$GOARM_VALUE" CGO_ENABLED=0 \
		go build -trimpath -ldflags='-s -w' -o "$OUTPUT_PATH" ./cmd/server
else
	GOOS="$GOOS_VALUE" GOARCH="$GOARCH_VALUE" CGO_ENABLED=0 \
		go build -trimpath -ldflags='-s -w' -o "$OUTPUT_PATH" ./cmd/server
fi

echo "Built $OUTPUT_PATH"
