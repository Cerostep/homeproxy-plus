#!/bin/sh
# Copyright (C) 2026 Cerostep

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

test -f "$ROOT/root/etc/config/homeproxy_plus"
test -f "$ROOT/root/etc/init.d/homeproxy_plus"
test -f "$ROOT/root/etc/capabilities/homeproxy_plus.json"
test -f "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
test -f "$ROOT/root/usr/share/luci/menu.d/luci-app-homeproxy-plus.json"
test -f "$ROOT/root/usr/share/rpcd/acl.d/luci-app-homeproxy-plus.json"
test -f "$ROOT/root/etc/homeproxy_plus/scripts/homeproxy_plus.uc"
test -f "$ROOT/root/etc/homeproxy_plus/lib/singbox_compat.uc"
test -f "$ROOT/root/etc/homeproxy_plus/lib/singbox-versions.json"
test -f "$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
test -f "$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
test -f "$ROOT/root/etc/homeproxy_plus/lib/config_server.uc"
if head -n 1 "$ROOT/root/etc/homeproxy_plus/lib/config_server.uc" | grep -q '^#!'; then
	echo "Imported config_server.uc must not contain a script shebang" >&2
	exit 1
fi
test -f "$ROOT/root/etc/homeproxy_plus/lib/config_validate.uc"
test -f "$ROOT/tests/generate_client_config.sh"
test -f "$ROOT/tests/generate_client_config_matrix.sh"
test -f "$ROOT/.github/fetch-sing-box.sh"
test -f "$ROOT/root/etc/homeproxy_plus/scripts/service_network.sh"
test -f "$ROOT/root/etc/homeproxy_plus/scripts/firewall_lifecycle.sh"
test -f "$ROOT/root/etc/homeproxy_plus/scripts/firewall.uc"
test -f "$ROOT/root/etc/homeproxy_plus/scripts/migrate_config.uc"
test ! -e "$ROOT/root/etc/homeproxy_plus/scripts/import_legacy_config.sh"
test ! -e "$ROOT/root/etc/uci-defaults/luci-app-homeproxy-plus-migration"
grep -q 'ucode "/etc/homeproxy_plus/scripts/migrate_config.uc" || exit 1' \
	"$ROOT/root/etc/uci-defaults/luci-app-homeproxy-plus"
grep -q 'export function getSingBoxFeatures' \
	"$ROOT/root/etc/homeproxy_plus/scripts/homeproxy_plus.uc"
grep -q "from '../lib/singbox_compat.uc'" \
	"$ROOT/root/etc/homeproxy_plus/scripts/homeproxy_plus.uc"
grep -q 'getSingBoxFeatures();' \
	"$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "option mixed_port '5430'" "$ROOT/root/etc/config/homeproxy_plus"
grep -q "option tun_name 'singtunp0'" "$ROOT/root/etc/config/homeproxy_plus"
grep -q "option table_mark '103'" "$ROOT/root/etc/config/homeproxy_plus"
test ! -e "$ROOT/root/etc/config/homeproxy"
test ! -e "$ROOT/root/etc/init.d/homeproxy"
test ! -e "$ROOT/root/etc/capabilities/homeproxy.json"
grep -q '/usr/bin/curl --head.*--max-time 3' \
	"$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q '+curl' "$ROOT/Makefile"
grep -q 'Depends: libc, ca-bundle, curl,' "$ROOT/.github/build-ipk.sh"
grep -q 'package_version_for_release_tag' "$ROOT/.github/build-ipk.sh"
grep -q 'RELEASE_TAG=.*GITHUB_REF_NAME' "$ROOT/.github/build-ipk.sh"
grep -q 'github.event.release.tag_name' "$ROOT/.github/workflows/build-ipk.yml"
grep -A6 'name: Publishing APK files to GitHub Artifacts' "$ROOT/.github/workflows/build-ipk.yml" |
	grep -q 'archive: true'
grep -A6 'name: Publishing IPK files to GitHub Artifacts' "$ROOT/.github/workflows/build-ipk.yml" |
	grep -q 'archive: true'
grep -A8 '^  publish:$' "$ROOT/.github/workflows/build-ipk.yml" |
	grep -q '^      contents: write$'
grep -q 'node_tcping:' "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q 'server_listener_status:' "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "popen('/bin/netstat -ln')" "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "fields\\[5\\] !== 'LISTEN'" "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "method: 'server_listener_status'" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "poll.add(() =>" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "listener.transport === transport" "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "listener.address === address" "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
if grep -q 'transports\.every' "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"; then
	echo "Listener probe must use ucode-compatible array iteration" >&2
	exit 1
fi
grep -q 'system(.*nc.*3000)' "$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "match(readfile('/proc/uptime').*\\^(\[0-9\]+\\[\\.\\]\[0-9\]+)" \
	"$ROOT/root/usr/share/rpcd/ucode/luci.homeproxy_plus"
grep -q "method: 'node_tcping'" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q "form.DummyValue, '_tcp_latency', _('Latency')" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q 'o.textvalue = function(section_id)' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q 'poll.add(refreshNodeLatencies, 60)' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"

if grep -R -n -E \
	'(/etc/config/homeproxy([./"]|$)|/etc/homeproxy/|/var/run/homeproxy/|luci\.homeproxy([ "'\'']|$)|luci-app-homeproxy([ "'\'']|$))' \
	"$ROOT/Makefile" "$ROOT/root" "$ROOT/htdocs"; then
	echo "Found a runtime namespace that can collide with HomeProxy." >&2
	exit 1
fi

for script in "$ROOT"/root/etc/init.d/homeproxy_plus \
	"$ROOT"/root/etc/homeproxy_plus/scripts/*.sh; do
	sh -n "$script"
done

jq -e . "$ROOT/root/usr/share/luci/menu.d/luci-app-homeproxy-plus.json" >/dev/null
jq -e . "$ROOT/root/usr/share/rpcd/acl.d/luci-app-homeproxy-plus.json" >/dev/null
grep -q "executeCommand('/usr/bin/sing-box', 'check'" \
	"$ROOT/root/etc/homeproxy_plus/lib/config_validate.uc"
! grep -q '+sing-box' "$ROOT/Makefile"
grep -q 'LUCI_PKGARCH:=$(ARCH_PACKAGES)' "$ROOT/Makefile"
grep -q 'USERID:=sing-box=5566:sing-box=5566' "$ROOT/Makefile"
grep -q 'Require-User: sing-box=5566:sing-box=5566' "$ROOT/.github/build-ipk.sh"
grep -Eq 'aarch64_generic|i386_pentium4|x86_64' "$ROOT/.github/fetch-sing-box.sh"
grep -q 'openwrt_x86_64.ipk' "$ROOT/.github/workflows/sing-box-compatibility.yml"
grep -q 'if \[ "$client_enabled" = "1" \] && ! mv -f "$client_staged" "$client_config"' \
	"$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'if \[ "$server_enabled" = "1" \] && ! mv -f "$server_staged" "$server_config"' \
	"$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'config_foreach _mark_enabled_server server' \
	"$ROOT/root/etc/init.d/homeproxy_plus"
if grep -q 'config_get_bool server_enabled "server" "enabled"' \
	"$ROOT/root/etc/init.d/homeproxy_plus"; then
	echo "Server runtime must follow enabled server entries, not the removed global switch" >&2
	exit 1
fi
grep -q "uci.foreach(cfgname, 'server'" \
	"$ROOT/root/etc/homeproxy_plus/scripts/firewall.uc"
if grep -q "uci.get(cfgname, 'server', 'enabled')" \
	"$ROOT/root/etc/homeproxy_plus/scripts/firewall.uc"; then
	echo "Server firewall rules must follow enabled server entries" >&2
	exit 1
fi
grep -q 'export function nodeFingerprint' \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q 'export function toNodeModel' \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q 'export function fromNodeModel' \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q "id: md5(sourceId + ':' + fingerprint)" \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q "key in \\['label', 'grouphash', 'enabled'\\]" \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q "enabled: model.enabled ? '1' : '0'" \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q "const baseFields = \\['label', 'type', 'address', 'port', 'grouphash', 'enabled'\\]" \
	"$ROOT/root/etc/homeproxy_plus/lib/node_model.uc"
grep -q 'fromNodeModel, nodeFingerprint, toNodeModel' \
	"$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
grep -q 'if (!sing_features.compatible)' \
	"$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
grep -q 'if (call(main) === false)' \
	"$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
! grep -q 'md5(cfg.label)' "$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
! grep -q 'calcStringMD5(config.label)' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q 'new Set(subinfo.map' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q 'new Map()' "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q 'Failed to save imported nodes: %s' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
grep -q 'function getNodeIdentityHash' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
! grep -q 'function to_node_model\\|function from_node_model\\|function node_fingerprint' \
	"$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
grep -q 'if (!parsed_model && incomplete_subscriptions\[cfg.grouphash\])' \
	"$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
grep -Fq "via_proxy === '1' && service_action('stop')" \
	"$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc"
test "$(grep -c 'uci.commit(uciconfig)' "$ROOT/root/etc/homeproxy_plus/scripts/update_subscriptions.uc")" -eq 1
grep -q 'sing-box-c.json.reload-backup' "$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'restoring the previous validated configuration' "$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'export function writeValidatedConfig' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_validate.uc"
grep -q 'writeValidatedConfig(config, config_path)' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
grep -q 'writeValidatedConfig(config, RUN_DIR' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_server.uc"
grep -Fq "getenv('HP_CLIENT_CONFIG_OUTPUT')" \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
grep -q 'dns_strategy_to_query_type' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
grep -q "case 'prefer_ipv4':" \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
grep -q 'domain_strategy cannot be combined with an explicit query_type' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
grep -q 'the outbound rule item was removed in sing-box 1.14' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
grep -q 'store_dns: strToBool(cache_file_store_rdrc)' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
! grep -q 'store_rdrc: strToBool\|rdrc_timeout: strToTime' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc"
# DNS rules must not emit the legacy strategy action option rejected by
# sing-box 1.14+; only outbound domain_resolver blocks may keep it.
test "$(grep -c 'strategy: cfg.domain_strategy' \
	"$ROOT/root/etc/homeproxy_plus/lib/config_client.uc")" -eq 2
grep -q 'ucode -L "$HP_DIR/scripts" -S "$GENERATOR"' \
	"$ROOT/tests/generate_client_config.sh"
grep -q '/usr/bin/sing-box check --config "$CONFIG"' \
	"$ROOT/tests/generate_client_config.sh"
grep -q 'homeproxy_network_start' "$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'homeproxy_network_stop' "$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'homeproxy_state_has' "$ROOT/root/etc/homeproxy_plus/scripts/service_network.sh"
grep -q 'homeproxy_add_rule' "$ROOT/root/etc/homeproxy_plus/scripts/service_network.sh"
grep -q 'homeproxy_add_route' "$ROOT/root/etc/homeproxy_plus/scripts/service_network.sh"
grep -q 'network-owned' "$ROOT/root/etc/homeproxy_plus/scripts/service_network.sh"
grep -q 'homeproxy_firewall_start' "$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'homeproxy_firewall_stop' "$ROOT/root/etc/init.d/homeproxy_plus"
grep -q 'export function getSingBoxFeatures' \
	"$ROOT/root/etc/homeproxy_plus/lib/singbox_compat.uc"
grep -q 'features.unknown_tags.map' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q 'Unknown sing-box build tags are disabled: %s.' \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "m = new form.Map('homeproxy_plus');" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "id: 'homeproxy-plus-page-intro'" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "tabmenu.parentNode.insertBefore" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "E('h2', {}, _('HomeProxy-Plus'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "E('p', {}, _('A plus edition of HomeProxy for OpenWrt / ImmortalWrt, kept in step with verified stable sing-box releases.'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
if grep -q "id: 'status_bar'" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"; then
	echo "Client service status must not render in the page header area" >&2
	exit 1
fi
grep -q "ss.option(form.DummyValue, '_service_status', _('Service Status'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "so.renderWidget = function(section_id)" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "status.textContent = renderStatus(res)" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "status.style.color = res ? 'green' : 'red'" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "style: 'color:red'" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
if grep -q "so.textvalue" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"; then
	echo "Client service status must not use DummyValue textvalue for DOM nodes" >&2
	exit 1
fi
grep -q "_('Active')" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
grep -q "_('Stopped')" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js"
default_outbound_dns_line=$(grep -n "so = ss.option(form.ListValue, 'default_outbound_dns'," \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js" | cut -d: -f1)
service_status_line=$(grep -n "so = ss.option(form.DummyValue, '_service_status'," \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/client.js" | cut -d: -f1)
if [ "$default_outbound_dns_line" -ge "$service_status_line" ]; then
	echo "Client service status must render below Default outbound DNS" >&2
	exit 1
fi
grep -q "m = new form.Map('homeproxy_plus');" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "id: 'homeproxy-plus-page-intro'" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "tabmenu.parentNode.insertBefore" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "E('h2', {}, _('HomeProxy-Plus'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "E('p', {}, _('A plus edition of HomeProxy for OpenWrt / ImmortalWrt, kept in step with verified stable sing-box releases.'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
if grep -q "m.section(form.NamedSection, 'server', 'homeproxy_plus'" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"; then
	echo "Server page must not render the global server enable section" >&2
	exit 1
fi
grep -q "m.section(form.GridSection, 'server');" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
if grep -q "m.section(form.GridSection, 'server', _('Server settings'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"; then
	echo "Server grid section must not render a heading" >&2
	exit 1
fi
server_enable_options=$(grep -c "s.option(form.Flag, 'enabled', _('Enable'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js")
if [ "$server_enable_options" -ne 1 ]; then
	echo "Per-server enable option must remain while the global option is removed" >&2
	exit 1
fi
grep -q "s.option(form.DummyValue, '_server_status', _('Status'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "o.textvalue = function()" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "querySelectorAll('td\\[data-name=\"_server_status\"\\]')" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "status.textContent = server.active ? _('Active') : _('Stopped')" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
grep -q "status.style.color = server.active ? 'green' : 'red'" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js"
server_name_line=$(grep -n "o = s.option(form.Value, 'label', _('Label'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js" | cut -d: -f1)
server_status_line=$(grep -n "o = s.option(form.DummyValue, '_server_status', _('Status'))" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/server.js" | cut -d: -f1)
if [ "$server_name_line" -ge "$server_status_line" ]; then
	echo "Server status must render after the server name" >&2
	exit 1
fi
for view in node status; do
	grep -q "id: 'homeproxy-plus-page-intro'" \
		"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/$view.js"
	grep -q "tabmenu.parentNode.insertBefore" \
		"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/$view.js"
	grep -q "E('h2', {}, _('HomeProxy-Plus'))" \
		"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/$view.js"
	grep -q "E('p', {}, _('A plus edition of HomeProxy for OpenWrt / ImmortalWrt, kept in step with verified stable sing-box releases.'))" \
		"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/$view.js"
done
grep -q "m = new form.Map('homeproxy_plus');" \
	"$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"
if grep -q "Edit nodes" "$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/node.js"; then
	echo "Node Settings must not render the Edit nodes map heading" >&2
	exit 1
fi
grep -q 'unknown_tags' "$ROOT/root/etc/homeproxy_plus/lib/singbox_compat.uc"
grep -q "'with_naive_outbound'" "$ROOT/root/etc/homeproxy_plus/lib/singbox_compat.uc"
jq -e '.minimum == "1.14.0" and .current == "1.14.4" and (.supported_versions | length == 2)' \
	"$ROOT/root/etc/homeproxy_plus/lib/singbox-versions.json" >/dev/null
jq -r '.supported_versions[]' "$ROOT/root/etc/homeproxy_plus/lib/singbox-versions.json" |
	while IFS= read -r version; do
		grep -q -- "- v$version" "$ROOT/.github/workflows/sing-box-compatibility.yml"
	done
STATUS_VIEW="$ROOT/htdocs/luci-static/resources/view/homeproxy_plus/status.js"
if grep -q "form.NamedSection, 'config', 'homeproxy_plus', _(" "$STATUS_VIEW"; then
	echo "Status page sections must be sub-tabs, not titled h3 sections" >&2
	exit 1
fi
grep -q "s.tab('connection', _('Connection check'))" "$STATUS_VIEW"
grep -q "s.tab('resources', _('Resources management'))" "$STATUS_VIEW"
grep -q "s.tab('core', _('Core Details'))" "$STATUS_VIEW"
grep -q "hp.getBuiltinFeatures()" "$STATUS_VIEW"
grep -q "s.taboption('core', form.ListValue, 'log_level'" "$STATUS_VIEW"
grep -q "o.ucisection = 'server'" "$STATUS_VIEW"
grep -q "const LOG_LEVELS = \['trace', 'debug', 'info', 'warn', 'error', 'fatal', 'panic'\]" "$STATUS_VIEW"

echo "Package identity and config-swap checks passed."
