#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PACKAGE_DIR="${1:-.}"
INDEX="$PACKAGE_DIR/Packages"
TEMP_INDEX="$PACKAGE_DIR/.Packages.$$"
trap 'rm -f "$TEMP_INDEX"' EXIT

: > "$TEMP_INDEX"
package_count=0

while IFS= read -r -d '' package; do
	filename="${package##*/}"
	file_size="$(stat -c '%s' "$package")"
	sha256="$(sha256sum "$package" | cut -d ' ' -f 1)"

	control="$(tar -xzOf "$package" ./control.tar.gz | tar -xzOf - ./control)"
	if grep -Eq '^(Filename|Size|SHA256sum):' <<< "$control"; then
		echo "IPK control unexpectedly contains feed-only metadata: $filename" >&2
		exit 1
	fi

	awk -v filename="$filename" -v size="$file_size" -v sha256="$sha256" '
		/^Description:/ {
			print "Filename: " filename
			print "Size: " size
			print "SHA256sum: " sha256
		}
		{ print }
	' <<< "$control" >> "$TEMP_INDEX"
	printf '\n' >> "$TEMP_INDEX"
	package_count=$((package_count + 1))
done < <(find "$PACKAGE_DIR" -maxdepth 1 -type f -name 'luci-app-homeproxy-plus_*.ipk' -print0 | sort -z)

if [ "$package_count" -eq 0 ]; then
	echo "No HomeProxy-Plus IPK files found in $PACKAGE_DIR" >&2
	exit 1
fi

mv "$TEMP_INDEX" "$INDEX"
gzip -n -c "$INDEX" > "$PACKAGE_DIR/Packages.gz"
