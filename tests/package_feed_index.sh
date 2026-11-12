#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/pkg/CONTROL" "$TEST_DIR/repo"
cat > "$TEST_DIR/pkg/CONTROL/control" <<'EOF'
Package: luci-app-homeproxy-plus
Version: 1.2.3
Architecture: x86_64
Installed-Size: 1234
Description: HomeProxy-Plus proxy platform for OpenWrt
EOF
printf '2.0\n' > "$TEST_DIR/pkg/debian-binary"
tar -czf "$TEST_DIR/pkg/control.tar.gz" -C "$TEST_DIR/pkg/CONTROL" ./control
tar -czf "$TEST_DIR/pkg/data.tar.gz" -C "$TEST_DIR/pkg" ./debian-binary
tar -czf "$TEST_DIR/repo/luci-app-homeproxy-plus_1.2.3_x86_64.ipk" \
	-C "$TEST_DIR/pkg" ./debian-binary ./data.tar.gz ./control.tar.gz

bash "$ROOT/.github/create-ipk-feed-index.sh" "$TEST_DIR/repo"
package="$TEST_DIR/repo/luci-app-homeproxy-plus_1.2.3_x86_64.ipk"
expected_size="$(stat -c '%s' "$package")"
expected_sha256="$(sha256sum "$package" | cut -d ' ' -f 1)"

grep -Fxq 'Package: luci-app-homeproxy-plus' "$TEST_DIR/repo/Packages"
grep -Fxq "Filename: ${package##*/}" "$TEST_DIR/repo/Packages"
grep -Fxq "Size: $expected_size" "$TEST_DIR/repo/Packages"
grep -Fxq "SHA256sum: $expected_sha256" "$TEST_DIR/repo/Packages"
grep -Fxq 'Installed-Size: 1234' "$TEST_DIR/repo/Packages"
grep -Fxq 'Description: HomeProxy-Plus proxy platform for OpenWrt' "$TEST_DIR/repo/Packages"
test "$(grep -c '^Size:' "$TEST_DIR/repo/Packages")" -eq 1
gzip -t "$TEST_DIR/repo/Packages.gz"
gzip -dc "$TEST_DIR/repo/Packages.gz" | cmp - "$TEST_DIR/repo/Packages"

mkdir "$TEST_DIR/empty"
if bash "$ROOT/.github/create-ipk-feed-index.sh" "$TEST_DIR/empty" 2>/dev/null; then
	echo "An empty feed index was accepted." >&2
	exit 1
fi

echo "IPK feed index metadata checks passed."
