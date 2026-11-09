#!/bin/sh
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -eu

OPENWRT_ARCH="${1:?OpenWrt package architecture is required}"
OUTPUT="${2:?output path is required}"

case "$OPENWRT_ARCH" in
	aarch64_generic)
		SHA256="e735580c1eaf3f7b0da9129e5d50eb16f2e3d58c648f28fc4f30e263c3126385"
		;;
	i386_pentium4)
		SHA256="edf5cdff3e0dfdc3fc1fd61b4a1efe215074e31e867717405ec17a9a5a92b19f"
		;;
	x86_64)
		SHA256="f87a26cce8c1f86016eae8423311aeaee119b3222c2f7afc3db0c1c368ac5a36"
		;;
	*)
		echo "Unsupported OpenWrt package architecture: $OPENWRT_ARCH (supported: aarch64_generic, i386_pentium4, x86_64)" >&2
		exit 1
		;;
esac

VERSION="1.14.4"
ARCHIVE_NAME="sing-box_${VERSION}_openwrt_${OPENWRT_ARCH}.ipk"
ARCHIVE_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/${ARCHIVE_NAME}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

curl -fL --retry 3 "$ARCHIVE_URL" -o "$TEMP_DIR/$ARCHIVE_NAME"
printf '%s  %s\n' "$SHA256" "$TEMP_DIR/$ARCHIVE_NAME" | sha256sum --check

mkdir -p "$(dirname "$OUTPUT")"
tar -xOzf "$TEMP_DIR/$ARCHIVE_NAME" data.tar.gz |
	tar -xzOf - ./usr/bin/sing-box > "$TEMP_DIR/sing-box"
test -s "$TEMP_DIR/sing-box"
chmod 0755 "$TEMP_DIR/sing-box"
mv "$TEMP_DIR/sing-box" "$OUTPUT"
