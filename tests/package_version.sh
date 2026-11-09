#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
. "$ROOT/.github/package-version.sh"

assert_version() {
	local expected="$1"
	local actual
	actual="$(package_version_for_release_tag "$2" "$3" "$4")"
	if [ "$actual" != "$expected" ]; then
		echo "Expected package version '$expected', got '$actual'." >&2
		exit 1
	fi
}

assert_invalid() {
	if package_version_for_release_tag "$1" "$2" "$3" >/dev/null 2>&1; then
		echo "Unexpectedly accepted release tag '$3'." >&2
		exit 1
	fi
}

assert_version '0.1.0_alpha' apk '0.1.0' 'v0.1.0-alpha'
assert_version '0.1.0_alpha.1' apk '0.1.0' 'v0.1.0-alpha.1'
assert_version '0.1.0~alpha' ipk '0.1.0' 'v0.1.0-alpha'
assert_version '0.1.0~alpha.2' ipk '0.1.0' '0.1.0-alpha.2'
assert_version '0.1.0' apk '0.1.0' 'v0.1.0'
assert_version '0.1.0' ipk '0.1.0' '0.1.0'
assert_invalid apk '0.1.0' 'v0.2.0-alpha.1'
assert_invalid apk '0.1.0' 'v0.1.0-beta.1'
assert_invalid apk '0.1.0' 'v0.1.0-alpha.01'
assert_invalid unsupported '0.1.0' 'v0.1.0-alpha.1'

echo "Release package version mapping checks passed."
