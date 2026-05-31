#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$ROOT_DIR/flutter}"
FLUTTER_WEB_DIR="${FLUTTER_WEB_DIR:-$FLUTTER_DIR/build/web}"
WEB_UI_DIR="${WEB_UI_DIR:-$ROOT_DIR/webui}"

if ! command -v flutter >/dev/null 2>&1; then
	echo "flutter is not installed or not on PATH." >&2
	exit 1
fi

if [[ ! -f "$FLUTTER_DIR/pubspec.yaml" ]]; then
	echo "Missing Flutter project at $FLUTTER_DIR." >&2
	exit 1
fi

echo "Cleaning Flutter build output..."
	cd "$FLUTTER_DIR"
	flutter clean
	flutter pub get
	flutter build web --release

echo "Refreshing server web assets in $WEB_UI_DIR..."
	rm -rf "$WEB_UI_DIR"
	mkdir -p "$WEB_UI_DIR"
	cp -a "$FLUTTER_WEB_DIR"/. "$WEB_UI_DIR"/

echo "Rebuilt web bundle and synced assets to $WEB_UI_DIR"