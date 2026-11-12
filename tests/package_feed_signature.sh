#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir "$TEST_DIR/feed"
cat > "$TEST_DIR/feed/Packages" <<'EOF'
Package: luci-app-homeproxy-plus
Version: 1.2.3
Size: 1234
Description: HomeProxy-Plus proxy platform for OpenWrt
EOF
gzip -n -c "$TEST_DIR/feed/Packages" > "$TEST_DIR/feed/Packages.gz"

usign -G -s "$TEST_DIR/secret.key" -p "$TEST_DIR/public.key"
bash "$ROOT/.github/sign-ipk-feed.sh" \
	"$TEST_DIR/secret.key" "$TEST_DIR/public.key" "$TEST_DIR/feed"
usign -V -m "$TEST_DIR/feed/Packages" -p "$TEST_DIR/public.key" \
	-x "$TEST_DIR/feed/Packages.sig" -q
gzip -dc "$TEST_DIR/feed/Packages.gz" |
	usign -V -m - -p "$TEST_DIR/public.key" \
		-x "$TEST_DIR/feed/Packages.sig" -q

if usign -V -m "$TEST_DIR/feed/Packages.gz" -p "$TEST_DIR/public.key" \
	-x "$TEST_DIR/feed/Packages.sig" -q 2>/dev/null; then
	echo "Compressed Packages.gz unexpectedly passed verification." >&2
	exit 1
fi

usign -G -s "$TEST_DIR/other-secret.key" -p "$TEST_DIR/other-public.key"
if bash "$ROOT/.github/sign-ipk-feed.sh" \
	"$TEST_DIR/other-secret.key" "$TEST_DIR/public.key" "$TEST_DIR/feed" \
	2>/dev/null; then
	echo "A signing key that does not match the trusted public key was accepted." >&2
	exit 1
fi

printf 'Tampered\n' >> "$TEST_DIR/feed/Packages"
if usign -V -m "$TEST_DIR/feed/Packages" -p "$TEST_DIR/public.key" \
	-x "$TEST_DIR/feed/Packages.sig" -q 2>/dev/null; then
	echo "A modified feed index passed signature verification." >&2
	exit 1
fi

test "$(usign -F -p "$ROOT/.github/homeproxy-plus-feed.pub")" = 'a776627ae8fe95d2'
echo "IPK feed signing and signature verification checks passed."
