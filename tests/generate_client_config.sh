#!/bin/sh
# Copyright (C) 2026 Cerostep

set -eu

HP_DIR=/etc/homeproxy_plus
GENERATOR="$HP_DIR/scripts/generate_client.uc"
TEST_DIR="$(mktemp -d /tmp/homeproxy-plus-client-config.XXXXXX)"
CONFIG="$TEST_DIR/sing-box.json"

cleanup() {
	rm -rf "$TEST_DIR"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if [ "$(id -u)" -ne 0 ]; then
	echo "Run this test as root on the OpenWrt/ImmortalWrt device." >&2
	exit 1
fi

for command in ucode uci; do
	if ! command -v "$command" >/dev/null 2>&1; then
		echo "Required command not found: $command" >&2
		exit 1
	fi
done

if [ ! -x /usr/bin/sing-box ]; then
	echo "Bundled /usr/bin/sing-box is not executable." >&2
	exit 1
fi

if [ ! -r "$GENERATOR" ]; then
	echo "Client configuration generator not found: $GENERATOR" >&2
	exit 1
fi

if ! HP_CLIENT_CONFIG_OUTPUT="$CONFIG" \
	ucode -L "$HP_DIR/scripts" -S "$GENERATOR"; then
	echo "LuCI client configuration generation failed." >&2
	exit 1
fi

if [ ! -s "$CONFIG" ]; then
	echo "Client configuration generator produced no JSON file." >&2
	exit 1
fi

if ! /usr/bin/sing-box check --config "$CONFIG"; then
	echo "sing-box rejected the full client configuration generated from UCI." >&2
	exit 1
fi

echo "Full client configuration generated from UCI and accepted by sing-box."
