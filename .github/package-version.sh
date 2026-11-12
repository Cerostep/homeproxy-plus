#!/bin/bash
# Copyright (C) 2026 Cerostep
# SPDX-License-Identifier: GPL-3.0-only

package_version_for_release_tag() {
	local pkg_mgr="$1"
	local pkg_version="$2"
	local release_tag="$3"
	local version_regex='^v?((0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))(-alpha(\.(0|[1-9][0-9]*))?)?$'

	if [[ ! "$release_tag" =~ $version_regex ]]; then
		echo "Unsupported release tag: $release_tag (expected vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-alpha[.N])" >&2
		return 1
	fi

	local release_version="${BASH_REMATCH[1]}"
	local prerelease="${BASH_REMATCH[5]}"
	local prerelease_number="${BASH_REMATCH[7]}"

	if [ "$release_version" != "$pkg_version" ]; then
		echo "Release tag version $release_version does not match package base version $pkg_version." >&2
		return 1
	fi

	if [ -z "$prerelease" ]; then
		printf '%s\n' "$pkg_version"
		return 0
	fi

	local alpha_suffix="alpha"
	if [ -n "$prerelease_number" ]; then
		alpha_suffix="alpha.$prerelease_number"
	fi

	case "$pkg_mgr" in
	apk)
		printf '%s_%s\n' "$pkg_version" "${alpha_suffix/./}"
		;;
	ipk)
		printf '%s~%s\n' "$pkg_version" "$alpha_suffix"
		;;
	*)
		echo "Unsupported package manager: $pkg_mgr (expected apk or ipk)." >&2
		return 1
		;;
	esac
}
