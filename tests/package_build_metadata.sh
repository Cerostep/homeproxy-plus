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
sed -i 's/^Installed-Size: .*/Installed-Size: 1234/' "$control"
cp "$control" "$FIXTURE_DIR/ipk-control"
cp "$3/CONTROL/postinst-pkg" "$FIXTURE_DIR/ipk-postinst-pkg"
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
		--script)
			case "$2" in
				post-install:*) cp "${2#post-install:}" "$FIXTURE_DIR/apk-post-install" ;;
				post-upgrade:*) cp "${2#post-upgrade:}" "$FIXTURE_DIR/apk-post-upgrade" ;;
			esac
			shift 2 ;;
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
export FIXTURE_DIR="$TEST_DIR"

assert_ipk_metadata() {
	test "$(sed -n 's/^Installed-Size: //p' "$TEST_DIR/ipk-control")" = '1234'
	grep -Fxq 'Description: HomeProxy-Plus proxy platform for OpenWrt' "$TEST_DIR/ipk-control"
}

bash "$TEST_DIR/.github/build-ipk.sh" ipk release x86_64 "v${base_version}-alpha.1"
ipk_file="$TEST_DIR/.github/luci-app-homeproxy-plus_${base_version}~alpha.1_x86_64.ipk"
test -f "$ipk_file"
assert_ipk_metadata
bash "$TEST_DIR/.github/build-ipk.sh" apk release x86_64 "v${base_version}-alpha.1"
test -f "$TEST_DIR/.github/luci-app-homeproxy-plus_${base_version}_alpha1_x86_64.apk"
bash "$TEST_DIR/.github/build-ipk.sh" ipk snapshot x86_64
ipk_file="$(compgen -G "$TEST_DIR/.github/luci-app-homeproxy-plus_*~abc1234_x86_64.ipk")"
test -n "$ipk_file"
assert_ipk_metadata

if bash "$TEST_DIR/.github/build-ipk.sh" ipk release x86_64 v999999.0.0 2>/dev/null; then
	echo "Mismatched release tag was accepted." >&2
	exit 1
fi

cat > "$TEST_DIR/functions.sh" <<'EOF'
add_group_and_user() { :; }
default_postinst() {
	echo default_postinst >> "$FIXTURE_DIR/calls"
	return "${DEFAULT_POSTINST_STATUS:-0}"
}
EOF
cat > "$TEST_DIR/rpcd" <<'EOF'
#!/bin/sh
echo "rpcd $*" >> "$FIXTURE_DIR/calls"
exit "${RPCD_RELOAD_STATUS:-0}"
EOF
cat > "$TEST_DIR/ignore-rm" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TEST_DIR/rpcd" "$TEST_DIR/ignore-rm"

for script in ipk-postinst-pkg apk-post-install apk-post-upgrade; do
	sed -e 's@${IPKG_INSTROOT}/lib/functions.sh@'"$TEST_DIR"'/functions.sh@g' \
		-e 's@/etc/init.d/rpcd@'"$TEST_DIR"'/rpcd@g' \
		-e 's@rm -f @'"$TEST_DIR"'/ignore-rm -f @g' \
		-e 's@rm -rf @'"$TEST_DIR"'/ignore-rm -rf @g' \
		"$TEST_DIR/$script" > "$TEST_DIR/$script.test"

	: > "$TEST_DIR/calls"
	IPKG_INSTROOT= sh "$TEST_DIR/$script.test"
	test "$(grep -c '^rpcd reload$' "$TEST_DIR/calls")" -eq 1

	: > "$TEST_DIR/calls"
	if IPKG_INSTROOT= RPCD_RELOAD_STATUS=1 sh "$TEST_DIR/$script.test" 2>"$TEST_DIR/error"; then
		echo "$script accepted an rpcd reload failure." >&2
		exit 1
	fi
	grep -q 'failed to reload rpcd' "$TEST_DIR/error"

	: > "$TEST_DIR/calls"
	IPKG_INSTROOT="$TEST_DIR/offline" sh "$TEST_DIR/$script.test"
	if grep -q '^rpcd ' "$TEST_DIR/calls"; then
		echo "$script reloaded rpcd during an offline installation." >&2
		exit 1
	fi
done

for script in apk-post-install apk-post-upgrade; do
	: > "$TEST_DIR/calls"
	if IPKG_INSTROOT= DEFAULT_POSTINST_STATUS=1 sh "$TEST_DIR/$script.test"; then
		echo "$script accepted a default_postinst failure." >&2
		exit 1
	fi
	if grep -q '^rpcd ' "$TEST_DIR/calls"; then
		echo "$script reloaded rpcd after default_postinst failed." >&2
		exit 1
	fi
	: > "$TEST_DIR/calls"
	IPKG_INSTROOT= IPKG_NO_SCRIPT=1 sh "$TEST_DIR/$script.test"
	test ! -s "$TEST_DIR/calls"
done

echo "Standalone package metadata checks passed with fixture packaging tools."
