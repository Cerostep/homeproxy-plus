#!/bin/sh
# Copyright (C) 2026 Cerostep

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

RUN_DIR="$TMP_DIR/run"
mkdir -p "$RUN_DIR"
export RUN_DIR

log() {
	:
}

ip() {
	case "$*" in
		'route show table all')
			printf '%s\n' \
				'unreachable 0.0.0.0/0 dev lo table 104' \
				'local default dev lo table 103 scope host'
			;;
		'-6 route show table all')
			printf '%s\n' \
				'unreachable default dev lo table 104' \
				'local default dev lo table 103 metric 1024'
			;;
		'rule show'|'-6 rule show')
			return 0
			;;
		'route add '*|'-6 route add '*)
			printf '%s\n' "$*" >> "$TMP_DIR/route-add-calls"
			;;
		*)
			echo "Unexpected ip invocation: $*" >&2
			return 1
			;;
	esac
}

. "$ROOT/root/etc/homeproxy_plus/scripts/service_network.sh"

homeproxy_add_route 4 local 103 lo
homeproxy_add_route 6 local 103 lo
homeproxy_route_exists 4 local 103 lo
homeproxy_route_exists 6 local 103 lo

test ! -e "$TMP_DIR/route-add-calls"
test ! -e "$RUN_DIR/.network-owned"

echo "BusyBox table-all routes are recognized without claiming ownership."
