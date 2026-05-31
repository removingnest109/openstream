#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WEB_UI_SOURCE="${WEB_UI_SOURCE:-$ROOT_DIR/webui}"
TARGETS=()

usage() {
	echo "Usage: $0 [all|native|linux-arm64|linux-armv7 ...]" >&2
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Required command not found: $1" >&2
		exit 1
	fi
}

target_binary_name() {
	case "$1" in
		linux-arm64)
			printf '%s\n' 'openstream-linux-arm64'
			;;
		linux-armv7)
			printf '%s\n' 'openstream-linux-armv7'
			;;
		native)
			local goos goarch goarm name
			goos="$(go env GOOS)"
			goarch="$(go env GOARCH)"
			goarm="$(go env GOARM 2>/dev/null || true)"
			name="openstream-${goos}-${goarch}"
			if [[ "$goarch" == "arm" && -n "$goarm" ]]; then
				name+="v${goarm}"
			fi
			printf '%s\n' "$name"
			;;
		*)
			echo "Unsupported target: $1" >&2
			exit 1
			;;
	esac
}

normalize_targets() {
	if [[ "$#" -eq 0 ]]; then
		TARGETS=(native)
		return
	fi

	for target in "$@"; do
		case "$target" in
			all)
				TARGETS=(native linux-arm64 linux-armv7)
				return
				;;
			native|linux-arm64|linux-armv7)
				TARGETS+=("$target")
				;;
			*)
				usage
				exit 1
				;;
		esac
	done
	mapfile -t TARGETS < <(printf '%s\n' "${TARGETS[@]}" | awk '!seen[$0]++')
}

build_target() {
	local target="$1"
	echo "Building $target release assets..."
	"$ROOT_DIR/scripts/build.sh" "$target"
}

package_target() {
	local target="$1"
	local binary_name package_dir stage_dir zip_path
	binary_name="$(target_binary_name "$target")"
	package_dir="$DIST_DIR/$binary_name"
	stage_dir="$package_dir/openstream"
	zip_path="$DIST_DIR/$binary_name.zip"

	if [[ ! -f "$ROOT_DIR/bin/$binary_name" ]]; then
		echo "Expected binary missing: $ROOT_DIR/bin/$binary_name" >&2
		exit 1
	fi

	rm -rf "$package_dir"
	mkdir -p "$stage_dir"

	install -m 0755 "$ROOT_DIR/bin/$binary_name" "$stage_dir/$binary_name"
	install -m 0755 "$ROOT_DIR/scripts/install.sh" "$stage_dir/install.sh"
	install -m 0644 "$ROOT_DIR/scripts/openstream.service" "$stage_dir/openstream.service"
	cp -a "$WEB_UI_SOURCE" "$stage_dir/webui"

	rm -f "$zip_path"
	(
		cd "$package_dir"
		zip -rq "$zip_path" openstream
	)

	echo "Created $zip_path"
}

require_command go
require_command zip

if [[ ! -f "$WEB_UI_SOURCE/index.html" ]]; then
	echo "Missing web UI assets in $WEB_UI_SOURCE. Run scripts/rebuild-web.sh first or set WEB_UI_SOURCE." >&2
	exit 1
fi

mkdir -p "$DIST_DIR"
normalize_targets "$@"

for target in "${TARGETS[@]}"; do
	build_target "$target"
	package_target "$target"
done