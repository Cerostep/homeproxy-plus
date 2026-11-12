#!/bin/bash
# Copyright (C) 2026 Cerostep
# Copyright (C) 2023 Tianling Shen <cnsztl@immortalwrt.org>

set -o errexit
set -o pipefail

PKG_MGR="${1:-apk}"
RELEASE_TYPE="${2:-snapshot}"
TARGET_ARCH="${3:?OpenWrt package architecture is required (aarch64_generic, i386_pentium4, or x86_64)}"
RELEASE_TAG="${4:-${GITHUB_REF_NAME:-}}"

case "$TARGET_ARCH" in
	aarch64_generic|i386_pentium4|x86_64) ;;
	*)
		echo "Unsupported OpenWrt package architecture: $TARGET_ARCH (supported: aarch64_generic, i386_pentium4, x86_64)" >&2
		exit 1
		;;
esac

export PKG_SOURCE_DATE_EPOCH="$(date "+%s")"
export SOURCE_DATE_EPOCH="$PKG_SOURCE_DATE_EPOCH"

BASE_DIR="$(cd "$(dirname $0)"; pwd)"
PKG_DIR="$BASE_DIR/.."

PKG_NAME="luci-app-homeproxy-plus"
PKG_BASE_VERSION="0.1.2"
if [ "$RELEASE_TYPE" == "release" ]; then
	. "$BASE_DIR/package-version.sh"
	PKG_VERSION="$(package_version_for_release_tag "$PKG_MGR" \
		"$PKG_BASE_VERSION" "$RELEASE_TAG")"
else
	PKG_VERSION="$PKG_SOURCE_DATE_EPOCH~$(git rev-parse --short HEAD)"
fi

TEMP_DIR="$(mktemp -d -p "$BASE_DIR")"
trap 'rm -rf "$TEMP_DIR"' EXIT
TEMP_PKG_DIR="$TEMP_DIR/$PKG_NAME"
mkdir -p "$TEMP_PKG_DIR/lib/upgrade/keep.d/"
mkdir -p "$TEMP_PKG_DIR/usr/lib/lua/luci/i18n/"
mkdir -p "$TEMP_PKG_DIR/www/"
if [ "$PKG_MGR" == "apk" ]; then
	mkdir -p "$TEMP_PKG_DIR/lib/apk/packages/"
else
	mkdir -p "$TEMP_PKG_DIR/CONTROL/"
fi

cp -fpR "$PKG_DIR/htdocs"/* "$TEMP_PKG_DIR/www/"
cp -fpR "$PKG_DIR/root"/* "$TEMP_PKG_DIR/"
sh "$BASE_DIR/fetch-sing-box.sh" "$TARGET_ARCH" "$TEMP_PKG_DIR/usr/bin/sing-box"

cat > "$TEMP_PKG_DIR/lib/upgrade/keep.d/$PKG_NAME" <<-EOF
/etc/homeproxy_plus/certs/
/etc/homeproxy_plus/ruleset/
/etc/homeproxy_plus/resources/direct_list.txt
/etc/homeproxy_plus/resources/proxy_list.txt
EOF

po2lmo "$PKG_DIR/po/zh_Hans/homeproxy_plus.po" "$TEMP_PKG_DIR/usr/lib/lua/luci/i18n/homeproxy_plus.zh-cn.lmo"

if [ "$PKG_MGR" == "apk" ]; then
	echo "sing-box=5566:sing-box=5566" > "$TEMP_PKG_DIR/lib/apk/packages/$PKG_NAME.rusers"
	find "$TEMP_PKG_DIR" -type f,l -printf '/%P\n' | sort > "$TEMP_PKG_DIR/lib/apk/packages/$PKG_NAME.list"
	echo "/etc/config/homeproxy_plus" >> "$TEMP_PKG_DIR/lib/apk/packages/$PKG_NAME.conffiles"
	cat "$TEMP_PKG_DIR/lib/apk/packages/$PKG_NAME.conffiles" | while IFS= read -r file; do
		[ -f "$TEMP_PKG_DIR/$file" ] || continue
		sha256sum "$TEMP_PKG_DIR/$file" | sed "s,$TEMP_PKG_DIR/,," >> "$TEMP_PKG_DIR/lib/apk/packages/$PKG_NAME.conffiles_static"
	done

	echo -e '#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
export root="${IPKG_INSTROOT}"
export pkgname="'"$PKG_NAME"'"
add_group_and_user
default_postinst || exit $?
[ -n "${IPKG_INSTROOT}" ] || { rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload || {
		echo "HomeProxy-Plus: failed to reload rpcd after installation" >&2
		exit 1
	}
	exit 0
}' > "$TEMP_DIR/post-install"

	echo -e '#!/bin/sh
export PKG_UPGRADE=1
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
export root="${IPKG_INSTROOT}"
export pkgname="'"$PKG_NAME"'"
add_group_and_user
default_postinst || exit $?
[ -n "${IPKG_INSTROOT}" ] || { rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload || {
		echo "HomeProxy-Plus: failed to reload rpcd after upgrade" >&2
		exit 1
	}
	exit 0
}' > "$TEMP_DIR/post-upgrade"

	echo -e '#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
export root="${IPKG_INSTROOT}"
export pkgname="'"$PKG_NAME"'"
default_prerm' > "$TEMP_DIR/pre-deinstall"

	apk mkpkg \
		--info "name:$PKG_NAME" \
		--info "version:$PKG_VERSION" \
		--info "description:HomeProxy-Plus proxy platform for OpenWrt" \
		--info "arch:$TARGET_ARCH" \
		--info "origin:homeproxy-plus" \
		--info "url:" \
		--info "maintainer:HomeProxy-Plus contributors" \
		--info "provides:" \
		--script "post-install:$TEMP_DIR/post-install" \
		--script "post-upgrade:$TEMP_DIR/post-upgrade" \
		--script "pre-deinstall:$TEMP_DIR/pre-deinstall" \
		--info "depends:libc ca-bundle curl kmod-inet-diag kmod-tun firewall4 kmod-nft-queue kmod-nft-tproxy ucode-mod-digest" \
		--files "$TEMP_PKG_DIR" \
		--output "$TEMP_DIR/${PKG_NAME}_${PKG_VERSION}.apk"

	mv "$TEMP_DIR/${PKG_NAME}_${PKG_VERSION}.apk" "$BASE_DIR/${PKG_NAME}_${PKG_VERSION}_${TARGET_ARCH}.apk"
else
	mkdir -p "$TEMP_PKG_DIR/CONTROL/"

	cat > "$TEMP_PKG_DIR/CONTROL/control" <<-EOF
		Package: $PKG_NAME
		Version: $PKG_VERSION
		Depends: libc, ca-bundle, curl, kmod-inet-diag, kmod-tun, firewall4, kmod-nft-queue, kmod-nft-tproxy, ucode-mod-digest
		SourceName: $PKG_NAME
		Require-User: sing-box=5566:sing-box=5566
		Section: luci
		SourceDateEpoch: $PKG_SOURCE_DATE_EPOCH
		Maintainer: HomeProxy-Plus contributors
		Architecture: $TARGET_ARCH
		Installed-Size: TO-BE-FILLED-BY-IPKG-BUILD
		Description: HomeProxy-Plus proxy platform for OpenWrt
	EOF
	chmod 0644 "$TEMP_PKG_DIR/CONTROL/control"

	echo -e "/etc/config/homeproxy_plus" > "$TEMP_PKG_DIR/CONTROL/conffiles"

	echo -e '#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_postinst $0 $@' > "$TEMP_PKG_DIR/CONTROL/postinst"
	chmod 0755 "$TEMP_PKG_DIR/CONTROL/postinst"

	cat > "$TEMP_PKG_DIR/CONTROL/postinst-pkg" <<'EOF'
[ -n "${IPKG_INSTROOT}" ] && exit 0

rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/
/etc/init.d/rpcd reload || {
	echo 'HomeProxy-Plus: failed to reload rpcd after installation or upgrade' >&2
	exit 1
}
exit 0
EOF
	chmod 0755 "$TEMP_PKG_DIR/CONTROL/postinst-pkg"


	cat > "$TEMP_PKG_DIR/CONTROL/prerm" <<'EOF'
#!/bin/sh

[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s "${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0

. "${IPKG_INSTROOT}/lib/functions.sh"
default_prerm "$0" "$@"

exit 0
EOF
	chmod 0755 "$TEMP_PKG_DIR/CONTROL/prerm"

	cat > "$TEMP_PKG_DIR/CONTROL/postrm" <<'EOF'
#!/bin/sh

[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0

# Avoid modifying the host filesystem during offline operations
[ -n "${IPKG_INSTROOT}" ] && exit 0

# Remove HomeProxy-Plus configuration
rm -f /etc/config/homeproxy_plus
rm -rf /etc/homeproxy_plus

# Remove runtime data
rm -rf /var/run/homeproxy_plus
rm -rf /etc/init.d/homeproxy_plus

# Remove HomeProxy-Plus static resources
rm -rf /www/luci-static/resources/homeproxy_plus

exit 0
EOF
	chmod 0755 "$TEMP_PKG_DIR/CONTROL/postrm"


	ipkg-build -m "" "$TEMP_PKG_DIR" "$TEMP_DIR"

	mv "$TEMP_DIR/${PKG_NAME}_${PKG_VERSION}_${TARGET_ARCH}.ipk" "$BASE_DIR/${PKG_NAME}_${PKG_VERSION}_${TARGET_ARCH}.ipk"
fi
