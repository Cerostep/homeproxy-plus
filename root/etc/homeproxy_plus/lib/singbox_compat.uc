/*
 * SPDX-License-Identifier: GPL-2.0-only
 * Copyright (C) 2026 Cerostep
 */

'use strict';

import { popen, readfile } from 'fs';

const CAPABILITY_TAGS = {
	with_acme: 'with_acme',
	with_grpc: 'with_grpc',
	with_gvisor: 'with_gvisor',
	with_quic: 'with_quic',
	with_utls: 'with_utls',
	with_wireguard: 'with_wireguard'
};
const KNOWN_BUILD_TAGS = [
	'with_dhcp',
	'with_clash_api',
	'with_tailscale',
	'with_ccm',
	'with_ocm',
	'with_cloudflared',
	'with_naive_outbound',
	'with_usbip',
	'with_openvpn',
	'with_openconnect',
	'with_purego',
	'badlinkname',
	'tfogo_checklinkname0',
	'with_musl'
];
const VERSION_POLICY = json(readfile('/etc/homeproxy_plus/lib/singbox-versions.json') || '{}');

function parseVersion(version) {
	const parts = match(version, /^([0-9]+)[.]([0-9]+)[.]([0-9]+)(-([0-9A-Za-z.-]+))?([+][0-9A-Za-z.-]+)?$/);

	if (!parts)
		return null;

	return {
		major: int(parts[1]),
		minor: int(parts[2]),
		patch: int(parts[3]),
		prerelease: parts[5] || null
	};
}

export function getSingBoxFeatures() {
	const features = {
		available: false,
		compatible: false,
		stable: false,
		version_supported: false,
		tags: [],
		unknown_tags: []
	};
	for (let capability in keys(CAPABILITY_TAGS))
		features[capability] = false;

	const fd = popen('/usr/bin/sing-box version');

	if (!fd) {
		features.error = 'unable to execute sing-box version';
		return features;
	}

	for (let line = fd.read('line'); length(line); line = fd.read('line')) {
		line = trim(line);

		const version = match(line, /^sing-box version (\S+)/);
		if (version)
			features.version = version[1];

		const tags = match(line, /^Tags: (.*)/);
		if (tags) {
			for (let tag in split(tags[1], ',')) {
				tag = trim(tag);
				if (tag && index(features.tags, tag) < 0)
					push(features.tags, tag);
			}
		}
	}

	fd.close();

	const parsed = features.version ? parseVersion(features.version) : null;
	features.available = !!features.version;
	if (!parsed) {
		features.error = features.available ?
			'unrecognized sing-box version format' :
			'sing-box version output was not recognized';
		return features;
	}

	features.version_major = parsed.major;
	features.version_minor = parsed.minor;
	features.version_patch = parsed.patch;
	features.stable = !parsed.prerelease;

	features.version_supported = features.stable &&
		index(VERSION_POLICY.supported_versions || [], features.version) >= 0;
	features.compatible = features.version_supported;

	for (let capability in keys(CAPABILITY_TAGS))
		features[capability] = features.compatible &&
			index(features.tags, CAPABILITY_TAGS[capability]) >= 0;

	const knownTags = [];
	for (let capability in keys(CAPABILITY_TAGS))
		push(knownTags, CAPABILITY_TAGS[capability]);
	for (let tag in KNOWN_BUILD_TAGS)
		push(knownTags, tag);

	for (let tag in features.tags) {
		if (index(knownTags, tag) < 0)
			push(features.unknown_tags, tag);
	}

	if (!features.version_supported)
		features.error = `unsupported sing-box version ${features.version}; update the compatibility matrix only after CI passes`;
	else if (length(features.unknown_tags))
		features.warning = 'unrecognized sing-box build tags are disabled';

	return features;
};

export function supportsSingBoxCapability(features, capability) {
	if (type(features) !== 'object' || !features.compatible ||
	    !(capability in CAPABILITY_TAGS))
		return false;

	return features[capability] === true;
};
