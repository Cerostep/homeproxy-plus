/*
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * Copyright (C) 2026 Cerostep
 * Copyright (C) 2022-2025 ImmortalWrt.org
 */

'use strict';
'require form';
'require rpc';
'require uci';
'require ui';
'require view';

'require homeproxy_plus as hp';

const LOG_LEVELS = ['trace', 'debug', 'info', 'warn', 'error', 'fatal', 'panic'];

function renderCoreVersion(features) {
	const nodes = [
		E('strong', { 'style': features.compatible ? 'color:green' : 'color:red' },
			features.version || _('Unknown'))
	];

	if (!features.compatible)
		nodes.push(E('p', { 'style': 'color:red' },
			features.error || _('This sing-box version is incompatible; service start and reload are blocked.')));
	else if (features.warning)
		nodes.push(E('p', { 'style': 'color:orange' }, features.warning));

	return E('div', {}, nodes);
}

function addLogLevelValues(o) {
	for (let level of LOG_LEVELS)
		o.value(level, level);
	o.default = 'warn';
	o.rmempty = false;
}

function getConnStat(o, site) {
	const callConnStat = rpc.declare({
		object: 'luci.homeproxy_plus',
		method: 'connection_check',
		params: ['site'],
		expect: { '': {} }
	});

	o.default = E('div', { 'style': 'cbi-value-field' }, [
		E('button', {
			'class': 'btn cbi-button cbi-button-action',
			'click': ui.createHandlerFn(this, () => {
				return L.resolveDefault(callConnStat(site), {}).then((ret) => {
                                        let ele = o.default.firstElementChild.nextElementSibling;
					if (ret.result) {
						ele.style.setProperty('color', 'green');
                                                ele.innerHTML = _('passed');
					} else {
						ele.style.setProperty('color', 'red');
                                                ele.innerHTML = _('failed');
					}
				});
			})
		}, [ _('Check') ]),
		' ',
		E('strong', { 'style': 'color:gray' }, _('unchecked')),
	]);
}

function getResVersion(o, type) {
	const callResVersion = rpc.declare({
		object: 'luci.homeproxy_plus',
		method: 'resources_get_version',
		params: ['type'],
		expect: { '': {} }
	});

	const callResUpdate = rpc.declare({
		object: 'luci.homeproxy_plus',
		method: 'resources_update',
		params: ['type'],
		expect: { '': {} }
	});

	return L.resolveDefault(callResVersion(type), {}).then((res) => {
		let spanTemp = E('div', { 'style': 'cbi-value-field' }, [
			E('button', {
				'class': 'btn cbi-button cbi-button-action',
				'click': ui.createHandlerFn(this, () => {
					return L.resolveDefault(callResUpdate(type), {}).then((res) => {
						switch (res.status) {
						case 0:
							o.description = _('Successfully updated.');
							break;
						case 1:
							o.description = _('Update failed.');
							break;
						case 2:
							o.description = _('Already in updating.');
							break;
						case 3:
							o.description = _('Already at the latest version.');
							break;
						default:
							o.description = _('Unknown error.');
							break;
						}

						return o.map.reset();
					});
				})
			}, [ _('Check update') ]),
			' ',
			E('strong', { 'style': (res.error ? 'color:red' : 'color:green') },
				[ res.error ? 'not found' : res.version ]
			),
		]);

		o.default = spanTemp;
	});
}

return view.extend({
	load() {
		return hp.getBuiltinFeatures();
	},

	render(features) {
		let m, s, o;

		let tabmenu = document.getElementById('tabmenu');
		if (!tabmenu)
			throw new Error(_('Unable to find the LuCI page tab menu.'));

		if (!document.getElementById('homeproxy-plus-page-intro')) {
			tabmenu.parentNode.insertBefore(E('div', {
				class: 'cbi-section',
				id: 'homeproxy-plus-page-intro'
			}, [
				E('h2', {}, _('HomeProxy-Plus')),
				E('p', {}, _('The modern ImmortalWrt proxy platform for ARM64/AMD64.'))
			]), tabmenu);
		}

		m = new form.Map('homeproxy_plus');

		s = m.section(form.NamedSection, 'config', 'homeproxy_plus');
		s.anonymous = true;

		s.tab('connection', _('Connection check'));
		s.tab('resources', _('Resources management'));
		s.tab('core', _('Core Details'));

		o = s.taboption('connection', form.DummyValue, '_check_baidu', _('BaiDu'));
		o.cfgvalue = L.bind(getConnStat, this, o, 'baidu');

		o = s.taboption('connection', form.DummyValue, '_check_google', _('Google'));
		o.cfgvalue = L.bind(getConnStat, this, o, 'google');

		o = s.taboption('resources', form.DummyValue, '_china_ip4_version', _('China IPv4 list version'));
		o.cfgvalue = L.bind(getResVersion, this, o, 'china_ip4');
		o.rawhtml = true;

		o = s.taboption('resources', form.DummyValue, '_china_ip6_version', _('China IPv6 list version'));
		o.cfgvalue = L.bind(getResVersion, this, o, 'china_ip6');
		o.rawhtml = true;

		o = s.taboption('resources', form.DummyValue, '_china_list_version', _('China list version'));
		o.cfgvalue = L.bind(getResVersion, this, o, 'china_list');
		o.rawhtml = true;

		o = s.taboption('resources', form.DummyValue, '_gfw_list_version', _('GFW list version'));
		o.cfgvalue = L.bind(getResVersion, this, o, 'gfw_list');
		o.rawhtml = true;

		o = s.taboption('resources', form.Value, 'github_token', _('GitHub token'));
		o.password = true;
		o.renderWidget = function() {
			let node = form.Value.prototype.renderWidget.apply(this, arguments);

			(node.querySelector('.control-group') || node).appendChild(E('button', {
				'class': 'cbi-button cbi-button-apply',
				'title': _('Save'),
				'click': ui.createHandlerFn(this, () => {
					return this.map.save(null, true).then(() => {
						ui.changes.apply(true);
					});
				}, this.option)
			}, [ _('Save') ]));

			return node;
		}

		o = s.taboption('core', form.DummyValue, '_singbox_version', _('sing-box version'));
		o.cfgvalue = function() {
			return features.version || _('Unknown');
		};
		o.renderWidget = function() {
			return renderCoreVersion(features);
		};

		o = s.taboption('core', form.ListValue, 'log_level', _('Client log level'));
		addLogLevelValues(o);

		o = s.taboption('core', form.ListValue, 'server_log_level', _('Server log level'));
		o.ucioption = 'log_level';
		o.ucisection = 'server';
		addLogLevelValues(o);

		o = s.taboption('core', form.DummyValue, '_log_level_save', _('Save settings'));
		o.renderWidget = function() {
			return E('button', {
				'class': 'cbi-button cbi-button-apply',
				'title': _('Save'),
				'click': ui.createHandlerFn(this, () => {
					return this.map.save(null, true).then(() => {
						ui.changes.apply(true);
					});
				})
			}, [ _('Save') ]);
		}

		return m.render();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
