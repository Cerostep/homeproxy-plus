// Copyright (C) 2026 Cerostep

'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

String.prototype.format = function(value) { return this.replace('%s', value); };

const root = path.join(__dirname, '..', 'htdocs/luci-static/resources');
const client = fs.readFileSync(path.join(root, 'view/homeproxy_plus/client.js'), 'utf8');
const start = client.indexOf("\t\tso = ss.option(form.ListValue, 'node', _('Node'),");
const end = client.indexOf("\t\tso = ss.option(form.ListValue, 'domain_resolver'", start);
assert.ok(start !== -1 && end !== -1, 'Routing node selector must exist');

const sections = [
	{ '.name': 'route_a', node: 'shared_node' },
	{ '.name': 'route_b', node: 'shared_node' }
];
const uci = {
	sections(config, type, callback) {
		for (const section of sections)
			callback(section);
	}
};
const helperSource = fs.readFileSync(path.join(root, 'homeproxy_plus.js'), 'utf8');
const hp = new Function('baseclass', 'form', 'uci', '_', helperSource)(
	{ extend: (value) => value },
	{ DynamicList: { extend: (value) => value } },
	uci, (value) => value
);
const section = {
	option() {
		return { value() {} };
	}
};
const L = { bind: (fn, self, ...args) => fn.bind(self, ...args) };
const selector = new Function('ss', 'form', 'proxy_nodes', '_', 'L', 'hp', 'data',
	`let so; ${client.slice(start, end)}; return so;`)(
	section, { ListValue: {} }, { shared_node: 'Shared node' }, (value) => value, L, hp, ['homeproxy_plus']
);

function accepts(sectionId, value) {
	if (!value && selector.rmempty === false)
		return false;
	return !selector.validate || selector.validate(sectionId, value) === true;
}

assert.equal(accepts('route_a', 'shared_node'), true);
assert.equal(accepts('route_b', 'shared_node'), true);
assert.equal(accepts('route_b', ''), false);
