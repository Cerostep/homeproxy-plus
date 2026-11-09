/*
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * Copyright (C) 2026 Cerostep
 */

'use strict';

import { executeCommand, removeBlankAttrs, shellQuote } from '../scripts/homeproxy_plus.uc';
import { getSingBoxFeatures } from './singbox_compat.uc';
import { writefile } from 'fs';

function report(message) {
	system(`printf '%s\\n' ${shellQuote(message)} >&2`);
}

function safeErrorSummary(text) {
	if (!text)
		return '';

	let summary = trim(split(text, '\n')[0]);
	summary = replace(summary,
		/("(password|secret|token|private[_-]?key|uuid)"\s*:\s*")[^"]*"/ig,
		'$1<redacted>"');
	summary = replace(summary,
		/((password|secret|token|private[_-]?key|uuid)\s*[:=]\s*)[^\s,;]+/ig,
		'$1<redacted>');
	return substr(summary, 0, 512);
}

export function writeValidatedConfig(config, path) {
	const features = getSingBoxFeatures();
	if (!features.compatible) {
		report(features.error || 'unsupported sing-box version');
		return false;
	}

	writefile(path, sprintf('%.J\n', removeBlankAttrs(config)));

	const result = executeCommand('/usr/bin/sing-box', 'check', '--config', shellQuote(path));
	if (result.exitcode !== 0) {
		const summary = safeErrorSummary(result.stderr || result.stdout);
		report(summary ? `sing-box check failed: ${summary}` :
			'sing-box rejected the generated configuration');
		system(`rm -f ${shellQuote(path)}`);
		return false;
	}

	return true;
};
