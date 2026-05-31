#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_SOURCE="${SERVICE_SOURCE:-$ROOT_DIR/scripts/openstream.service}"
SERVICE_NAME="$(basename "$SERVICE_SOURCE")"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME"
WEB_UI_SOURCE="${WEB_UI_SOURCE:-$ROOT_DIR/webui}"
BIN_SOURCE="${BIN_SOURCE:-}"

preferred_binary_path() {
	local goos goarch goarm candidate
	goos="$(go env GOOS)"
	goarch="$(go env GOARCH)"
	goarm="$(go env GOARM 2>/dev/null || true)"
	candidate="$ROOT_DIR/bin/openstream-${goos}-${goarch}"
	if [[ "$goarch" == "arm" && -n "$goarm" ]]; then
		candidate+="v${goarm}"
	fi
	printf '%s\n' "$candidate"
}

if [[ "$EUID" -ne 0 ]]; then
	echo "Run this script as root (for example: sudo ./scripts/install.sh)." >&2
	exit 1
fi

if [[ ! -f "$SERVICE_SOURCE" ]]; then
	echo "Missing service file at $SERVICE_SOURCE." >&2
	exit 1
fi

exec_start_line="$(grep -E '^ExecStart=' "$SERVICE_SOURCE" | tail -n 1 || true)"
web_ui_line="$(grep -E '^Environment=WEB_UI_DIR=' "$SERVICE_SOURCE" | tail -n 1 || true)"

if [[ -z "$exec_start_line" ]]; then
	echo "Could not find ExecStart in $SERVICE_SOURCE." >&2
	exit 1
fi

if [[ -z "$web_ui_line" ]]; then
	echo "Could not find WEB_UI_DIR in $SERVICE_SOURCE." >&2
	exit 1
fi

BIN_DEST="${exec_start_line#ExecStart=}"
WEB_UI_DEST="${web_ui_line#Environment=WEB_UI_DIR=}"

if [[ -z "$BIN_SOURCE" ]]; then
	preferred_bin="$(preferred_binary_path)"
	if [[ -f "$preferred_bin" ]]; then
		BIN_SOURCE="$preferred_bin"
	elif compgen -G "$ROOT_DIR/bin/openstream-*" >/dev/null; then
		BIN_SOURCE="$(find "$ROOT_DIR/bin" -maxdepth 1 -type f -name 'openstream-*' | sort | head -n 1)"
	else
		echo "No built binary found in $ROOT_DIR/bin. Run scripts/build.sh first or set BIN_SOURCE." >&2
		exit 1
	fi
fi

if [[ ! -f "$BIN_SOURCE" ]]; then
	echo "Binary not found at $BIN_SOURCE." >&2
	exit 1
fi

if [[ ! -f "$WEB_UI_SOURCE/index.html" ]]; then
	echo "Missing web UI assets in $WEB_UI_SOURCE. Run scripts/rebuild-web.sh first or set WEB_UI_SOURCE." >&2
	exit 1
fi

echo "Installing binary to $BIN_DEST..."
install -D -m 0755 "$BIN_SOURCE" "$BIN_DEST"

echo "Installing web UI to $WEB_UI_DEST..."
rm -rf "$WEB_UI_DEST"
mkdir -p "$WEB_UI_DEST"
cp -a "$WEB_UI_SOURCE"/. "$WEB_UI_DEST"/

echo "Installing systemd service to $SERVICE_DEST..."
install -D -m 0644 "$SERVICE_SOURCE" "$SERVICE_DEST"

echo "Reloading systemd and enabling $SERVICE_NAME..."
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo "Installed Openstream successfully."