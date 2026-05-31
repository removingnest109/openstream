#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$ROOT_DIR/flutter}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/flutter}"
DESKTOP_FILE_SOURCE="${DESKTOP_FILE_SOURCE:-$ROOT_DIR/scripts/openstream-client.desktop}"

usage() {
	echo "Usage: $0" >&2
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Required command not found: $1" >&2
		exit 1
	fi
}

build_linux() {
	case "$(uname -s)" in
		Linux)
			;;
		*)
			echo "Linux desktop builds must be run on Linux." >&2
			exit 1
			;;
	esac

	echo "Building Flutter Linux release..."
	(
		cd "$FLUTTER_DIR"
		flutter build linux --release
	)

	local bundle_dir output_dir
	bundle_dir="$FLUTTER_DIR/build/linux/x64/release/bundle"
	output_dir="$DIST_DIR/linux"
	rm -rf "$output_dir"
	mkdir -p "$output_dir"
	cp -a "$bundle_dir"/. "$output_dir"/
	cp -a "$DESKTOP_FILE_SOURCE" "$output_dir/openstream-client.desktop"

	local package_dir archive_path
	package_dir="$DIST_DIR/openstream-linux-client"
	archive_path="$DIST_DIR/openstream-linux-client.zip"
	rm -rf "$package_dir"
	mkdir -p "$package_dir/openstream"
	cp -a "$output_dir"/. "$package_dir/openstream"/
	install -m 0755 "$ROOT_DIR/scripts/install-client.sh" "$package_dir/install-client.sh"
	rm -f "$archive_path"
	(
		cd "$package_dir"
		zip -rq "$archive_path" install-client.sh openstream
	)

	echo "Wrote $output_dir"
	echo "Wrote $archive_path"
}

require_command flutter
require_command zip

if [[ ! -f "$FLUTTER_DIR/pubspec.yaml" ]]; then
	echo "Missing Flutter project at $FLUTTER_DIR." >&2
	exit 1
fi

mkdir -p "$DIST_DIR"

if [[ "$#" -gt 0 ]]; then
	usage
	exit 1
fi

build_linux