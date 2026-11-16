// Copyright (C) 2026 Cerostep

'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

String.prototype.format = function(value) { return this.replace('%s', value); };

function element(tag, attributes = {}, children = []) {
	if (Array.isArray(tag))
		return { children: tag };

	const classes = new Set((attributes.class || '').split(' '));
	const node = {
		tag, ...attributes,
		children: Array.isArray(children) ? children : [ children ],
		classList: {
			add: (name) => classes.add(name),
			contains: (name) => classes.has(name)
		},
		querySelector(selector) {
			if (selector === '.cbi-section-create-name')
				return this.children[0].children[0];
			if (selector === '.cbi-section-create > .cbi-button-add')
				return this.children[1];
		}
	};
	return node;
}

const configs = {};
const uci = {
	get(config, id, key) {
		const section = configs[config]?.[id];
		return key ? section?.[key] : section;
	},
	add(config, type, id) {
		configs[config] ??= {};
		configs[config][id] = { '.name': id, '.type': type };
		return id;
	},
	set(config, id, key, value) {
		configs[config][id][key] = value;
	}
};
let validator;
const ui = {
	addValidator(input, datatype, optional, callback) {
		assert.equal(datatype, 'string');
		validator = callback;
	},
	createHandlerFn(section, callback) { return callback.bind(section); }
};
const source = fs.readFileSync(path.join(__dirname,
	'../htdocs/luci-static/resources/homeproxy_plus.js'), 'utf8');
const hp = new Function('baseclass', 'dom', 'form', 'uci', 'ui', 'E', '_', source)(
	{ extend: (value) => value },
	{ findClassInstance: (node) => node.map },
	{ DynamicList: { extend: (value) => value } },
	uci, ui, element, (value) => value
);

function createSection(type, readonly = false, previousMap = null) {
	const map = { config: 'homeproxy_plus', readonly, data: uci };
	const section = {
		addremove: true,
		sectiontype: type,
		map,
		titleFn: () => null,
		getPreviousModalMap: () => previousMap && { map: previousMap },
		renderMoreOptionsModal(id) {
			return { id, label: uci.get(map.config, id, 'label') };
		}
	};
	validator = null;
	const el = hp.renderSectionAdd(section, 'grid-create');
	return { section, el, input: el.querySelector('.cbi-section-create-name'),
		button: el.querySelector('.cbi-section-create > .cbi-button-add'), validate: validator };
}

for (const type of ['node', 'server', 'routing_node', 'routing_rule', 'dns_server', 'dns_rule', 'ruleset']) {
	configs.homeproxy_plus = {};
	const previousMap = {};
	const { section, input, button, validate } = createSection(type, false, previousMap);

	assert.equal(validate(''), true);
	assert.equal(button.disabled, true);
	assert.equal(validate('node-1'), true);
	assert.equal(button.disabled, null);
	input.value = 'node-1';
	const result = button.click({});
	assert.equal(result.label, 'node-1');
	assert.match(result.id, /^[A-Za-z0-9_]+$/);
	assert.equal(previousMap.addedSection, result.id);
	assert.equal(uci.get('homeproxy_plus', result.id, '.type'), type);
	assert.match(validate('node-1'), /unique UCI identifier/);
	assert.equal(button.disabled, true);
	uci.set('homeproxy_plus', result.id, 'label', 'renamed');
	assert.equal(hp.loadDefaultLabel('homeproxy_plus', result.id), 'renamed');
	assert.match(validate('node-1'), /unique UCI identifier/);
	assert.match(validate('node.1'), /valid UCI identifier/);
	assert.throws(() => section.handleAdd({}, 'node-1'), /unique UCI identifier/);
	assert.throws(() => section.handleAdd({}, 'node.1'), /valid UCI identifier/);

	assert.equal(validate('Node_1'), true);
	const ordinary = section.handleAdd({}, 'Node_1');
	assert.equal(ordinary.id, 'Node_1');
	assert.equal(ordinary.label, undefined);
	assert.notEqual(section.handleAdd({}, 'node-_').id, section.handleAdd({}, 'node_-').id);
	assert.throws(() => section.handleAdd({}, result.id), /unique UCI identifier/);
}

const readonly = createSection('node', true);
assert.equal(readonly.input.disabled, true);
assert.equal(readonly.button.disabled, true);
assert.equal(readonly.validate, null);

const nodeView = fs.readFileSync(path.join(__dirname,
	'../htdocs/luci-static/resources/view/homeproxy_plus/node.js'), 'utf8');
assert.match(nodeView, /hp\.renderSectionAdd\(this, arguments\[0\]\)/);

const failure = createSection('node');
failure.section.renderMoreOptionsModal = () => Promise.reject(new Error('save failed'));
failure.section.handleAdd({}, 'failed-name').then(
	() => { throw new Error('Failure was not propagated'); },
	(error) => { assert.equal(error.message, 'save failed'); }
);
