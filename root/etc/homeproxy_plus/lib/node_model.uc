/*
 * SPDX-License-Identifier: GPL-2.0-only
 * Copyright (C) 2026 Cerostep
 */

'use strict';

import { md5 } from 'digest';

function canonicalize(value) {
	if (type(value) === 'object') {
		let result = {};
		for (let key in sort(keys(value)))
			result[key] = canonicalize(value[key]);
		return result;
	}

	if (type(value) === 'array') {
		let result = [];
		for (let item in value)
			push(result, canonicalize(item));
		return result;
	}

	return value;
}

export function nodeFingerprint(node) {
	let identity = {};
	for (let key in keys(node)) {
		if (match(key, /^\./) || key in ['label', 'grouphash', 'enabled'])
			continue;
		if (node[key] === null || node[key] === '')
			continue;
		identity[key] = (key === 'port') ? int(node[key]) : node[key];
	}

	return md5(sprintf('%J', canonicalize(identity)));
};

export function toNodeModel(config, sourceId) {
	const port = int(config?.port);
	if (type(config) !== 'object' || !config.type ||
	    !config.address || !port || port < 1 || port > 65535 ||
	    type(sourceId) !== 'string' || !length(sourceId))
		return null;

	const options = {};
	const credentials = {};
	const baseFields = ['label', 'type', 'address', 'port', 'grouphash', 'enabled'];
	const credentialField = /(password|private_key|client_key|secret|token|username|uuid|auth_payload|auth_key|mac_key|ech_key)$/i;

	for (let key in keys(config)) {
		if (key in baseFields)
			continue;
		if (match(key, credentialField))
			credentials[key] = config[key];
		else
			options[key] = config[key];
	}

	const fingerprint = nodeFingerprint(config);

	return {
		id: md5(sourceId + ':' + fingerprint),
		fingerprint,
		name: config.label,
		type: config.type,
		server: config.address,
		server_port: port,
		enabled: true,
		source: {
			kind: 'subscription',
			id: sourceId
		},
		options,
		credentials
	};
};

export function fromNodeModel(model) {
	const port = int(model?.server_port);
	if (type(model) !== 'object' || type(model.source) !== 'object' ||
	    model.source.kind !== 'subscription' || !model.source.id ||
	    !model.type || !model.server || !port || port < 1 || port > 65535 ||
	    type(model.options) !== 'object' || type(model.credentials) !== 'object')
		return null;

	let config = {
		label: model.name,
		type: model.type,
		address: model.server,
		port: sprintf('%d', port),
		grouphash: model.source.id,
		enabled: model.enabled ? '1' : '0'
	};

	for (let key in keys(model.options))
		config[key] = model.options[key];
	for (let key in keys(model.credentials))
		config[key] = model.credentials[key];

	return config;
};
