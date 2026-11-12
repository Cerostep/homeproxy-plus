#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/.github" "$TEST_DIR/htdocs" "$TEST_DIR/root" \
	"$TEST_DIR/po/zh_Hans" "$TEST_DIR/bin"
cp "$ROOT/.github/build-ipk.sh" "$ROOT/.github/package-version.sh" "$TEST_DIR/.github/"
base_version="$(sed -n 's/^PKG_BASE_VERSION="\([^"]*\)"$/\1/p' "$TEST_DIR/.github/build-ipk.sh")"
[[ "$base_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
touch "$TEST_DIR/htdocs/fixture" "$TEST_DIR/root/fixture" \
	"$TEST_DIR/po/zh_Hans/homeproxy_plus.po"

cat > "$TEST_DIR/.github/fetch-sing-box.sh" <<'EOF'
#!/bin/sh
set -eu
mkdir -p "$(dirname "$2")"
printf 'fixture binary\n' > "$2"
EOF
cat > "$TEST_DIR/bin/po2lmo" <<'EOF'
#!/bin/sh
touch "$2"
EOF
cat > "$TEST_DIR/bin/git" <<'EOF'
#!/bin/sh
printf 'abc1234\n'
EOF
cat > "$TEST_DIR/bin/ipkg-build" <<'EOF'
#!/bin/sh
set -eu
control="$3/CONTROL/control"
name="$(sed -n 's/^Package: //p' "$control")"
version="$(sed -n 's/^Version: //p' "$control")"
arch="$(sed -n 's/^Architecture: //p' "$control")"
test "$name" = 'luci-app-homeproxy-plus'
test "$arch" = 'x86_64'
test -s "$3/usr/bin/sing-box"
touch "$4/${name}_${version}_${arch}.ipk"
EOF
cat > "$TEST_DIR/bin/apk" <<'EOF'
#!/bin/sh
set -eu
test "$1" = mkpkg
shift
name= version= arch= output= files=
while [ "$#" -gt 0 ]; do
	case "$1" in
		--info)
			case "$2" in
				name:*) name="${2#name:}" ;;
				version:*) version="${2#version:}" ;;
				arch:*) arch="${2#arch:}" ;;
			esac
			shift 2 ;;
		--files) files="$2"; shift 2 ;;
		--output) output="$2"; shift 2 ;;
		*) shift 2 ;;
	esac
done
test "$name" = 'luci-app-homeproxy-plus'
test "$arch" = 'x86_64'
test -n "$version"
test -s "$files/usr/bin/sing-box"
touch "$output"
EOF
chmod +x "$TEST_DIR/bin/"*
export PATH="$TEST_DIR/bin:$PATH"

bash "$TEST_DIR/.github/build-ipk.sh" ipk release x86_64 "v${base_version}-alpha.1"
test -f "$TEST_DIR/.github/luci-app-homeproxy-plus_${base_version}~alpha.1_x86_64.ipk"
bash "$TEST_DIR/.github/build-ipk.sh" apk release x86_64 "v${base_version}-alpha.1"
test -f "$TEST_DIR/.github/luci-app-homeproxy-plus_${base_version}_alpha1_x86_64.apk"
bash "$TEST_DIR/.github/build-ipk.sh" ipk snapshot x86_64
compgen -G "$TEST_DIR/.github/luci-app-homeproxy-plus_*~abc1234_x86_64.ipk" >/dev/null

if bash "$TEST_DIR/.github/build-ipk.sh" ipk release x86_64 v999999.0.0 2>/dev/null; then
	echo "Mismatched release tag was accepted." >&2
	exit 1
fi

echo "Standalone package metadata checks passed with fixture packaging tools."
