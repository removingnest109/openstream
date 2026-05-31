#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

default_service_source() {
	if [[ -f "$SCRIPT_DIR/openstream.service" ]]; then
		printf '%s\n' "$SCRIPT_DIR/openstream.service"
		return
	fi
	printf '%s\n' "$ROOT_DIR/scripts/openstream.service"
}

default_web_ui_source() {
	if [[ -f "$SCRIPT_DIR/webui/index.html" ]]; then
		printf '%s\n' "$SCRIPT_DIR/webui"
		return
	fi
	printf '%s\n' "$ROOT_DIR/webui"
}

preferred_binary_name() {
	local machine
	machine="$(uname -m)"
	case "$machine" in
		x86_64)
			printf '%s\n' 'openstream-linux-amd64'
			;;
		aarch64|arm64)
			printf '%s\n' 'openstream-linux-arm64'
			;;
		armv7l|armv7)
			printf '%s\n' 'openstream-linux-armv7'
			;;
		*)
			printf '%s\n' ''
			;;
	esac
}

default_binary_source() {
	local preferred_name candidate
	preferred_name="$(preferred_binary_name)"
	for candidate in \
		"$SCRIPT_DIR/$preferred_name" \
		"$ROOT_DIR/bin/$preferred_name"
	do
		if [[ -n "$preferred_name" && -f "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return
		fi
	done

	for candidate in \
		"$SCRIPT_DIR"/openstream-* \
		"$ROOT_DIR/bin"/openstream-*
	do
		if [[ -f "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return
		fi
	done

	printf '%s\n' ''
}

SERVICE_SOURCE="${SERVICE_SOURCE:-$(default_service_source)}"
SERVICE_NAME="$(basename "$SERVICE_SOURCE")"
SERVICE_DEST="/etc/systemd/system/$SERVICE_NAME"
WEB_UI_SOURCE="${WEB_UI_SOURCE:-$(default_web_ui_source)}"
BIN_SOURCE="${BIN_SOURCE:-$(default_binary_source)}"

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
	echo "No installable binary found next to this script or in $ROOT_DIR/bin. Set BIN_SOURCE explicitly if needed." >&2
	exit 1
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