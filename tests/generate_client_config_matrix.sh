#!/bin/sh
# Copyright (C) 2026 Cerostep
#
# Representative client configuration generation tests using isolated UCI
# data and a temporary copy of the generator. Missing OpenWrt modules are
# replaced with limited stand-ins when running on a development host.

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/../root/etc/homeproxy_plus"
if [ ! -r "$SOURCE_DIR/scripts/generate_client.uc" ]; then
	SOURCE_DIR=/etc/homeproxy_plus
fi

TEST_DIR="$(mktemp -d /tmp/homeproxy-plus-matrix.XXXXXX)"
HP_DIR="$TEST_DIR/homeproxy_plus"
RUN_DIR="$TEST_DIR/run"
UCI_DIR="$TEST_DIR/config"
UCI_CONFIG="$UCI_DIR/homeproxy_plus"
GENERATOR="$HP_DIR/scripts/generate_client.uc"
RULESET_FILE="$RUN_DIR/test-matrix-ruleset.json"
FAKE_MOD_DIR="$TEST_DIR/fake-modules"
FAILED=0
MODULE_ARGS=""

cleanup() {
	rm -rf "$TEST_DIR"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

for command in ucode; do
	if ! command -v "$command" >/dev/null 2>&1; then
		echo "Required command not found: $command" >&2
		exit 1
	fi
done

if [ ! -x /usr/bin/sing-box ]; then
	echo "Bundled /usr/bin/sing-box is not executable." >&2
	exit 1
fi

if [ ! -r "$SOURCE_DIR/scripts/generate_client.uc" ]; then
	echo "Client configuration generator not found in $SOURCE_DIR" >&2
	exit 1
fi

mkdir -p "$HP_DIR" "$RUN_DIR" "$UCI_DIR"
cp -R "$SOURCE_DIR/scripts" "$SOURCE_DIR/lib" "$SOURCE_DIR/resources" "$HP_DIR/"
sed -i \
	-e "s|'/etc/homeproxy_plus'|'$HP_DIR'|g" \
	-e "s|'/var/run/homeproxy_plus'|'$RUN_DIR'|g" \
	"$HP_DIR/scripts/homeproxy_plus.uc"
sed -i "s|/etc/homeproxy_plus/lib/singbox-versions.json|$HP_DIR/lib/singbox-versions.json|g" \
	"$HP_DIR/lib/singbox_compat.uc"
sed -i "s|const uci = cursor();|const uci = cursor('$UCI_DIR');|" \
	"$HP_DIR/lib/config_client.uc"

# Only the two synthetic IPv4 addresses in the bypass case are needed when
# the OpenWrt validate_data utility is not installed.
if [ ! -x /sbin/validate_data ]; then
	cat > "$TEST_DIR/validate_data" <<'EOF'
#!/bin/sh
case "$1:$2" in
	ip4addr:8.8.8.8|ip4addr:223.5.5.5) exit 0 ;;
	*) exit 1 ;;
esac
EOF
	chmod 700 "$TEST_DIR/validate_data"
	sed -i "s|/sbin/validate_data|$TEST_DIR/validate_data|g" \
		"$HP_DIR/scripts/homeproxy_plus.uc"
	echo "Using a limited validate_data stand-in for the test addresses."
fi

setup_dev_environment() {
	mkdir -p "$FAKE_MOD_DIR/luci"
	need_fakes=0

	if ! ucode -e 'import { connect } from "ubus";' 2>/dev/null; then
		need_fakes=1
		cat > "$FAKE_MOD_DIR/ubus.uc" <<'EOF'
/* Stand-in for hosts without ubusd: no WAN DNS, the generator falls back
 * to its built-in defaults. */
export function connect() {
	return { call: (...args) => null };
};
EOF
	fi

	if ! ucode -e 'import { cursor } from "uci";' 2>/dev/null; then
		need_fakes=1
		cat > "$FAKE_MOD_DIR/uci.uc" <<'EOF'
/* Minimal read-only UCI backend for development hosts without
 * ucode-mod-uci. Parses <config_dir>/<name> files; supports
 * config/option/list with single or double quotes. */
import { readfile } from 'fs';

let config_dir = '/etc/config';

function split_words(line) {
	let words = [], cur = null, quote = null;

	for (let i = 0; i < length(line); i++) {
		const c = substr(line, i, 1);

		if (quote) {
			if (c === quote)
				quote = null;
			else if (c === '\\' && quote === '"')
				cur += substr(line, ++i, 1);
			else
				cur += c;
		} else if (c === "'" || c === '"') {
			quote = c;
			if (cur === null)
				cur = '';
		} else if (c === ' ' || c === '\t' || c === '\r') {
			if (cur !== null) {
				push(words, cur);
				cur = null;
			}
		} else {
			cur = (cur ?? '') + c;
		}
	}

	if (cur !== null)
		push(words, cur);

	return words;
}

function load_config(name) {
	let sections = [], cur = null, index = 0;
	const content = readfile(config_dir + '/' + name);

	if (!content)
		return sections;

	for (let raw in split(content, '\n')) {
		const words = split_words(trim(raw));

		if (!length(words) || substr(words[0], 0, 1) === '#')
			continue;

		if (words[0] === 'config') {
			cur = {
				'.type': words[1],
				'.name': words[2] ?? sprintf('cfg%02d', index++),
				'.anonymous': words[2] === null
			};
			push(sections, cur);
		} else if (words[0] === 'option' && cur) {
			cur[words[1]] = words[2] ?? '';
		} else if (words[0] === 'list' && cur) {
			if (type(cur[words[1]]) !== 'array')
				cur[words[1]] = [];
			push(cur[words[1]], words[2] ?? '');
		}
	}

	return sections;
}

export function cursor(dir) {
	if (dir)
		config_dir = dir;

	let cache = {};

	function sections_of(cfg) {
		if (!cache[cfg])
			cache[cfg] = load_config(cfg);
		return cache[cfg];
	}

	function find_section(cfg, name) {
		for (let s in sections_of(cfg)) {
			if (s['.name'] === name)
				return s;
		}
		return null;
	}

	return {
		load: function(cfg) {
			cache[cfg] = load_config(cfg);
			return true;
		},
		get: function(cfg, section, option) {
			const s = find_section(cfg, section);
			if (!s)
				return null;
			if (option === null)
				return s['.type'];
			return s[option] ?? null;
		},
		get_all: function(cfg, section) {
			return find_section(cfg, section);
		},
		foreach: function(cfg, stype, cb) {
			for (let s in sections_of(cfg)) {
				if (s['.type'] === stype)
					cb(s);
			}
		}
	};
};
EOF
	fi

	if ! ucode -e 'import { urldecode_params } from "luci.http";' 2>/dev/null; then
		need_fakes=1
		cat > "$FAKE_MOD_DIR/luci/http.uc" <<'EOF'
/* Stand-in for hosts without LuCI: unused on the generation path. */
export function urldecode_params(str) {
	return {};
};
EOF
	fi

	if [ "$need_fakes" -eq 1 ]; then
		MODULE_ARGS="-L $FAKE_MOD_DIR"
		echo "Development mode: injected stand-in ucode modules from $FAKE_MOD_DIR"
	fi
}

setup_dev_environment

write_common_sections() {
	cat > "$UCI_CONFIG" <<'EOF'
config homeproxy_plus 'infra'
	option common_port '22,53,80,443'
	option mixed_port '5430'
	option redirect_port '5431'
	option tproxy_port '5432'
	option dns_port '5433'
	option dns_redirect '1'
	option ntp_server 'time.apple.com'
	option udp_timeout '300'
	option tun_name 'singtunp0'
	option tun_addr4 '172.20.0.1/30'
	option tun_addr6 'fdfe:dcba:9876:1::1/126'
	option tun_mtu '9000'
	option table_mark '103'
	option self_mark '103'
	option tproxy_mark '104'
	option tun_mark '105'

config homeproxy_plus 'migration'
	option crontab '1'

config homeproxy_plus 'control'
	option lan_proxy_mode 'disabled'

config homeproxy_plus 'server'
	option log_level 'warn'

config node 'testnode'
	option label 'Matrix Test Node'
	option type 'shadowsocks'
	option address '192.0.2.1'
	option port '8388'
	option shadowsocks_encrypt_method 'aes-128-gcm'
	option password 'homeproxy-plus-matrix-test'
EOF

	if [ ! -s "$UCI_CONFIG" ]; then
		echo "Failed to write seed configuration to $UCI_CONFIG" >&2
		exit 1
	fi
}

write_bypass_case() {
	write_common_sections
	cat >> "$UCI_CONFIG" <<'EOF'

config homeproxy_plus 'config'
	option main_node 'testnode'
	option main_udp_node 'same'
	option dns_server '8.8.8.8'
	option china_dns_server '223.5.5.5'
	option routing_mode 'bypass_mainland_china'
	option routing_port 'common'
	option proxy_mode 'redirect_tproxy'
	option ipv6_support '1'
	option log_level 'warn'
EOF
}

write_custom_base() {
	write_common_sections
	cat >> "$UCI_CONFIG" <<'EOF'

config homeproxy_plus 'config'
	option main_node 'nil'
	option routing_mode 'custom'
	option proxy_mode 'redirect_tproxy'
	option ipv6_support '1'
	option log_level 'warn'

config homeproxy_plus 'dns'
	option default_strategy 'prefer_ipv4'
	option default_server 'default-dns'
	option disable_cache '0'
	option disable_cache_expire '0'
	option client_subnet '1.2.3.0/24'
	option cache_file_store_rdrc '1'
	option cache_file_rdrc_timeout '604800'

config dns_server 'remoteudp'
	option label 'Remote UDP'
	option enabled '1'
	option type 'udp'
	option server '8.8.8.8'
	option server_port '53'
	option address_resolver 'default-dns'
	option address_strategy 'ipv4_only'

config dns_server 'doh'
	option label 'Remote DoH'
	option enabled '1'
	option type 'https'
	option server 'dns.google'
	option path '/dns-query'
	option tls_sni 'dns.google'
	option address_resolver 'default-dns'
EOF
}

write_custom_full_case() {
	write_custom_base
	cat >> "$UCI_CONFIG" <<'EOF'

config homeproxy_plus 'routing'
	option default_outbound 'testnode-route'
	option default_outbound_dns 'default-dns'
	option domain_strategy 'prefer_ipv4'
	option udp_timeout '300'

config routing_node 'testnode-route'
	option label 'Matrix Test Node Route'
	option enabled '1'
	option node 'testnode'
	option domain_resolver 'default-dns'
	option domain_strategy 'prefer_ipv4'

config routing_node 'testurltest'
	option label 'Matrix Test URLTest'
	option enabled '1'
	option node 'urltest'
	list urltest_nodes 'testnode'
	option urltest_url 'https://www.gstatic.com/generate_204'
	option urltest_interval '600'
	option urltest_tolerance '50'

config routing_rule 'rr-override'
	option label 'Override route'
	option enabled '1'
	list domain_suffix 'example.com'
	option action 'route'
	option outbound 'direct-out'
	option override_address '1.1.1.1'
	option udp_disable_domain_unmapping '1'
	option tls_fragment '1'
	option tls_fragment_fallback_delay '500'
	option tls_record_fragment '1'

config routing_rule 'rr-options'
	option label 'Route options'
	option enabled '1'
	list ip_cidr '8.8.8.8/32'
	option action 'route-options'
	option udp_connect '1'
	option udp_timeout '300'

config routing_rule 'rr-disabled'
	option label 'Disabled route'
	option enabled '0'
	list domain_suffix 'disabled.example'
	option action 'route'
	option outbound 'direct-out'

config ruleset 'testset'
	option label 'Matrix Test IP Set'
	option enabled '1'
	option type 'local'
	option format 'source'
	option path '@RULESET_FILE@'

config dns_rule 'dr-strategy'
	option label 'Legacy strategy conversion'
	option enabled '1'
	list domain_suffix '.cn'
	option action 'route'
	option server 'default-dns'
	option domain_strategy 'prefer_ipv4'

config dns_rule 'dr-qtype'
	option label 'Explicit query types'
	option enabled '1'
	list domain_keyword 'example'
	list query_type 'A'
	list query_type 'AAAA'
	option action 'route'
	option server 'doh'
	option dns_disable_cache '1'
	option rewrite_ttl '300'
	option client_subnet '5.6.7.0/24'

config dns_rule 'dr-response'
	option label 'Response matching'
	option enabled '1'
	list domain_regex '^stun\..+'
	list rule_set 'testset'
	option rule_set_ip_cidr_match_response '1'
	option action 'route'
	option server 'default-dns'

config dns_rule 'dr-reject'
	option label 'Reject SVCB'
	option enabled '1'
	list query_type '64'
	list query_type '65'
	option action 'reject'
	option reject_method 'default'

config dns_rule 'dr-predefined'
	option label 'NXDOMAIN ads'
	option enabled '1'
	list domain_keyword 'ads'
	option action 'predefined'
	option predefined_rcode 'NXDOMAIN'

config dns_rule 'dr-disabled'
	option label 'Disabled DNS rule'
	option enabled '0'
	list domain_suffix '.disabled'
	option action 'route'
	option server 'default-dns'
EOF

	sed -i "s|@RULESET_FILE@|$RULESET_FILE|" "$UCI_CONFIG"
	cat > "$RULESET_FILE" <<'EOF'
{ "version": 3, "rules": [ { "ip_cidr": ["203.0.113.0/24"] } ] }
EOF
}

run_generator() {
	HP_CLIENT_CONFIG_OUTPUT="$TEST_DIR/$1.json" \
		ucode -L "$HP_DIR/scripts" $MODULE_ARGS -S "$GENERATOR" 2>&1
}

pass() {
	echo "PASS: $1"
}

fail() {
	FAILED=$((FAILED + 1))
	echo "FAIL: $1" >&2
}

expect_ok() {
	name="$1"
	shift
	echo "== Case: $name =="
	if output="$(run_generator "$name")"; then
		rc=0
	else
		rc=$?
	fi
	if [ -n "$output" ]; then
		echo "$output" | sed 's/^/    /'
	fi
	if [ $rc -ne 0 ]; then
		fail "$name: generator exited with $rc"
		return
	fi
	if [ ! -s "$TEST_DIR/$name.json" ]; then
		fail "$name: generator produced no JSON file"
		return
	fi
	if ! /usr/bin/sing-box check --config "$TEST_DIR/$name.json"; then
		fail "$name: sing-box rejected the generated configuration"
		return
	fi
	if [ "$name" = "custom-full" ] &&
	   ! grep -Eq '"tls_fragment_fallback_delay"[[:space:]]*:[[:space:]]*"500ms"' "$TEST_DIR/$name.json"; then
		fail "$name: expected a 500ms TLS fragment fallback delay"
		return
	fi
	for pattern in "$@"; do
		if ! printf '%s\n' "$output" | grep -q "$pattern"; then
			fail "$name: expected warning not found: $pattern"
			return
		fi
	done
	pass "$name"
}

expect_fail() {
	name="$1"
	pattern="$2"
	echo "== Case: $name =="
	if output="$(run_generator "$name")"; then
		rc=0
	else
		rc=$?
	fi
	if [ -n "$output" ]; then
		echo "$output" | sed 's/^/    /'
	fi
	if [ $rc -eq 0 ]; then
		fail "$name: generator unexpectedly succeeded"
		return
	fi
	if ! printf '%s\n' "$output" | grep -q "$pattern"; then
		fail "$name: expected error not found: $pattern"
		return
	fi
	pass "$name"
}

write_bypass_case
expect_ok "bypass-full"

write_custom_full_case
expect_ok "custom-full" \
	"was converted to a query_type match" \
	"store_rdrc was migrated to store_dns"

write_custom_base
cat >> "$UCI_CONFIG" <<'EOF'

config homeproxy_plus 'routing'
	option default_outbound 'direct-out'
	option default_outbound_dns 'default-dns'

config dns_rule 'dr-bad-outbound'
	option label 'Removed outbound item'
	option enabled '1'
	list domain_suffix '.bad'
	option action 'route'
	option server 'default-dns'
	option outbound 'direct-out'
EOF
expect_fail "negative-dns-outbound" "outbound rule item was removed in sing-box 1.14"

write_custom_base
cat >> "$UCI_CONFIG" <<'EOF'

config homeproxy_plus 'routing'
	option default_outbound 'direct-out'
	option default_outbound_dns 'default-dns'

config dns_rule 'dr-bad-combo'
	option label 'Strategy plus query_type'
	option enabled '1'
	list domain_suffix '.bad'
	option action 'route'
	option server 'default-dns'
	option domain_strategy 'prefer_ipv4'
	list query_type 'A'
EOF
expect_fail "negative-strategy-query-type" "cannot be combined with an explicit query_type"

if [ $FAILED -gt 0 ]; then
	echo "$FAILED case(s) failed; test data was isolated from the real UCI configuration." >&2
	exit 1
fi

echo "All matrix cases passed; test data was isolated from the real UCI configuration."
