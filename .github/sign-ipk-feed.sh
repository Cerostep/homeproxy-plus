#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

if [ "$#" -ne 3 ]; then
	echo "Usage: $0 <secret-key> <public-key> <feed-directory>" >&2
	exit 2
fi

SECRET_KEY="$1"
PUBLIC_KEY="$2"
FEED_DIR="$3"
INDEX="$FEED_DIR/Packages"
COMPRESSED_INDEX="$FEED_DIR/Packages.gz"
SIGNATURE="$FEED_DIR/Packages.sig"

for file in "$SECRET_KEY" "$PUBLIC_KEY" "$INDEX" "$COMPRESSED_INDEX"; do
	if [ ! -s "$file" ]; then
		echo "Required signing input is missing or empty: $file" >&2
		exit 1
	fi
done

if ! gzip -dc "$COMPRESSED_INDEX" | cmp -s - "$INDEX"; then
	echo "Packages.gz does not match Packages" >&2
	exit 1
fi

SECRET_FINGERPRINT="$(usign -F -s "$SECRET_KEY")"
PUBLIC_FINGERPRINT="$(usign -F -p "$PUBLIC_KEY")"
if [ "$SECRET_FINGERPRINT" != "$PUBLIC_FINGERPRINT" ]; then
	echo "Feed signing key does not match the pinned public key (secret: $SECRET_FINGERPRINT, public: $PUBLIC_FINGERPRINT)" >&2
	exit 1
fi

usign -S -m "$INDEX" -s "$SECRET_KEY" -x "$SIGNATURE"
usign -V -m "$INDEX" -p "$PUBLIC_KEY" -x "$SIGNATURE" -q
