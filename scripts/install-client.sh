#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_SOURCE="${SOURCE:-$SCRIPT_DIR/openstream}"
if [[ ! -d "$DEFAULT_SOURCE" ]]; then
	DEFAULT_SOURCE="${SOURCE:-$ROOT_DIR/dist/flutter/linux}"
fi
INSTALL_DIR="${INSTALL_DIR:-/opt/openstream-client}"
BIN_NAME="${BIN_NAME:-openstream_flutter}"
LAUNCHER_NAME="${LAUNCHER_NAME:-openstream-client}"
DESKTOP_FILE_NAME="${DESKTOP_FILE_NAME:-openstream-client.desktop}"
APPLICATIONS_DIR="${APPLICATIONS_DIR:-/usr/share/applications}"

if [[ "$EUID" -ne 0 ]]; then
	echo "Run this script as root (for example: sudo ./scripts/install-client.sh)." >&2
	exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
	echo "Linux client installs must be run on Linux." >&2
	exit 1
fi

if [[ ! -d "$DEFAULT_SOURCE" ]]; then
	echo "Missing Linux client bundle at $DEFAULT_SOURCE." >&2
	echo "Build it first with ./scripts/build-client-release.sh or extract the release tarball next to this script." >&2
	exit 1
fi

if [[ ! -f "$DEFAULT_SOURCE/$BIN_NAME" ]]; then
	echo "Expected binary not found at $DEFAULT_SOURCE/$BIN_NAME." >&2
	exit 1
fi

if [[ ! -f "$DEFAULT_SOURCE/$DESKTOP_FILE_NAME" ]]; then
	echo "Expected desktop file not found at $DEFAULT_SOURCE/$DESKTOP_FILE_NAME." >&2
	echo "Build it first with ./scripts/build-client-release.sh." >&2
	exit 1
fi

echo "Installing Linux client bundle to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$DEFAULT_SOURCE"/. "$INSTALL_DIR"/
chmod 0755 "$INSTALL_DIR/$BIN_NAME"

echo "Installing launcher to /usr/local/bin/$LAUNCHER_NAME..."
install -D -m 0755 /dev/stdin "/usr/local/bin/$LAUNCHER_NAME" <<EOF
#!/usr/bin/env bash
exec "$INSTALL_DIR/$BIN_NAME" "\$@"
EOF

echo "Installing desktop entry to $APPLICATIONS_DIR/$DESKTOP_FILE_NAME..."
install -D -m 0644 "$DEFAULT_SOURCE/$DESKTOP_FILE_NAME" "$APPLICATIONS_DIR/$DESKTOP_FILE_NAME"

echo "Installed Openstream Linux client successfully."