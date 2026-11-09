#!/usr/bin/ucode
/*
 * Copyright (C) 2026 Cerostep
 */

'use strict';

import { writefile } from 'fs';
import { cursor } from 'uci';
import { isEmpty, RUN_DIR } from './homeproxy_plus.uc';

const cfgname = 'homeproxy_plus';
const uci = cursor();
uci.load(cfgname);

const routing_mode = uci.get(cfgname, 'config', 'routing_mode') || 'bypass_mainland_china',
      proxy_mode = uci.get(cfgname, 'config', 'proxy_mode') || 'redirect_tproxy';

let outbound_node, tun_name;
if (match(proxy_mode, /tun/)) {
	if (routing_mode === 'custom')
		outbound_node = uci.get(cfgname, 'routing', 'default_outbound') || 'nil';
	else
		outbound_node = uci.get(cfgname, 'config', 'main_node') || 'nil';

	if (outbound_node !== 'nil')
		tun_name = uci.get(cfgname, 'infra', 'tun_name') || 'singtunp0';
}

let forward = [],
    input = [];

if (tun_name) {
	push(forward, `oifname ${tun_name} counter accept comment "!${cfgname}: accept tun forward"`);
	push(input ,`iifname ${tun_name} counter accept comment "!${cfgname}: accept tun input"`);
}

uci.foreach(cfgname, 'server', (s) => {
	if (s.enabled !== '1' || s.firewall !== '1')
		return;

	let proto = s.network || '{ tcp, udp }';
	push(input, `meta l4proto ${proto} th dport ${s.port} counter accept comment "!${cfgname}: accept server ${s['.name']}"`);
});

if (!isEmpty(forward))
	writefile(RUN_DIR + '/fw4_forward.nft', join('\n', forward) + '\n');

if (!isEmpty(input))
	writefile(RUN_DIR + '/fw4_input.nft', join('\n', input) + '\n');
