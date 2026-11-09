#!/bin/sh
# Copyright (C) 2026 Cerostep

homeproxy_network_state() {
	printf '%s\n' "$RUN_DIR/.network-owned"
}

homeproxy_state_has() {
	[ -f "$(homeproxy_network_state)" ] &&
		grep -Fqx -- "$1" "$(homeproxy_network_state)"
}

homeproxy_rule_exists() {
	local family="$1" mark="$2" table="$3" output mark_hex
	mark_hex="$(printf '0x%x' "$mark" 2>/dev/null)" || return 1
	if [ "$family" = 6 ]; then
		output="$(ip -6 rule show)" || return 1
	else
		output="$(ip rule show)" || return 1
	fi

	printf '%s\n' "$output" | awk -v dec="$mark" -v hex="$mark_hex" -v table="$table" '
	{
		matched_mark = 0
		matched_table = 0
		for (i = 1; i < NF; i++) {
			if ($i == "fwmark") {
				split($(i + 1), value, "/")
				if (value[1] == dec || tolower(value[1]) == tolower(hex))
					matched_mark = 1
			}
			if (($i == "lookup" || $i == "table") && $(i + 1) == table)
				matched_table = 1
		}
		if (matched_mark && matched_table)
			found = 1
	}
	END { exit !found }'
}

homeproxy_route_table_output() {
	local family="$1" table="$2" output
	if [ "$family" = 6 ]; then
		output="$(ip -6 route show table all)" || return 1
	else
		output="$(ip route show table all)" || return 1
	fi

	printf '%s\n' "$output" | awk -v table="$table" '
	{
		for (i = 1; i < NF; i++) {
			if ($i == "table" && $(i + 1) == table) {
				print
				break
			}
		}
	}'
}

homeproxy_add_rule() {
	local family="$1" mark="$2" table="$3" entry="rule|$1|$2|$3"

	if homeproxy_state_has "$entry" && homeproxy_rule_exists "$family" "$mark" "$table"; then
		return 0
	fi
	if ! homeproxy_state_has "$entry" && homeproxy_rule_exists "$family" "$mark" "$table"; then
		return 0
	fi

	if [ "$family" = 6 ]; then
		ip -6 rule add fwmark "$mark" table "$table" || return 1
	else
		ip rule add fwmark "$mark" table "$table" || return 1
	fi

	if ! homeproxy_state_has "$entry"; then
		printf '%s\n' "$entry" >> "$(homeproxy_network_state)" || {
			if [ "$family" = 6 ]; then
				ip -6 rule del fwmark "$mark" table "$table" 2>/dev/null || true
			else
				ip rule del fwmark "$mark" table "$table" 2>/dev/null || true
			fi
			return 1
		}
	fi
}

homeproxy_add_route() {
	local family="$1" kind="$2" table="$3" device="$4"
	local entry="route|$family|$kind|$table|$device" output owned=0
	homeproxy_state_has "$entry" && owned=1

	output="$(homeproxy_route_table_output "$family" "$table")" || return 1

	if [ "$kind" = local ]; then
		if printf '%s\n' "$output" | grep -Eq '^local (default|0\.0\.0\.0/0|::/0) dev lo([[:space:]]|$)'; then
			return 0
		fi
		if [ "$family" = 6 ]; then
			ip -6 route add local ::/0 dev lo table "$table" || return 1
		else
			ip route add local 0.0.0.0/0 dev lo table "$table" || return 1
		fi
	else
		if printf '%s\n' "$output" | grep -Eq "^default dev $device([[:space:]]|$)"; then
			return 0
		fi
		if printf '%s\n' "$output" | grep -Eq '^default([[:space:]]|$)'; then
			log "Error: a conflicting default route already exists in table $table."
			return 1
		fi
		if [ "$family" = 6 ]; then
			ip -6 route add default dev "$device" table "$table" || return 1
		else
			ip route add default dev "$device" table "$table" || return 1
		fi
	fi

	if [ "$owned" -eq 0 ]; then
		if ! printf '%s\n' "$entry" >> "$(homeproxy_network_state)"; then
			log "Error: failed to record ownership of the route in table $table."
			if [ "$family" = 6 ]; then
				if [ "$kind" = local ]; then
					ip -6 route del local ::/0 dev lo table "$table" 2>/dev/null ||
						log "Error: failed to roll back the untracked IPv6 local route in table $table."
				else
					ip -6 route del default dev "$device" table "$table" 2>/dev/null ||
						log "Error: failed to roll back the untracked IPv6 default route in table $table."
				fi
			elif [ "$kind" = local ]; then
				ip route del local 0.0.0.0/0 dev lo table "$table" 2>/dev/null ||
					log "Error: failed to roll back the untracked IPv4 local route in table $table."
			else
				ip route del default dev "$device" table "$table" 2>/dev/null ||
					log "Error: failed to roll back the untracked IPv4 default route in table $table."
			fi
			return 1
		fi
	fi
}

homeproxy_route_exists() {
	local family="$1" kind="$2" table="$3" device="$4" output
	output="$(homeproxy_route_table_output "$family" "$table")" || return 1

	if [ "$kind" = local ]; then
		printf '%s\n' "$output" | grep -Eq '^local (default|0\.0\.0\.0/0|::/0) dev lo([[:space:]]|$)'
	else
		printf '%s\n' "$output" | grep -Eq "^default dev $device([[:space:]]|$)"
	fi
}

homeproxy_network_start() {
	local routing_mode="$1" proxy_mode="$2" outbound_node="$3"
	local ipv6_support dns_port table_mark

	mkdir -p "$RUN_DIR"
	: >> "$(homeproxy_network_state)"
	config_load "$CONF"
	config_get_bool ipv6_support "config" "ipv6_support" "0"
	config_get dns_port "infra" "dns_port" "5433"
	mkdir -p "$DNSMASQ_DIR"
	echo "conf-dir=$DNSMASQ_DIR" > "$DNSMASQ_DIR/../dnsmasq-homeproxy_plus.conf"
	for dns_file in redirect-dns.conf gfw_list.conf china_list.conf proxy_list.conf; do
		rm -f "$DNSMASQ_DIR/$dns_file"
	done

	case "$routing_mode" in
	bypass_mainland_china|custom|global)
		cat <<-EOF > "$DNSMASQ_DIR/redirect-dns.conf"
			no-poll
			no-resolv
			server=127.0.0.1#$dns_port
		EOF
		;;
	gfwlist)
		local gfw_nftset_v6=""
		[ "$ipv6_support" -eq 0 ] || gfw_nftset_v6=",6#inet#fw4#homeproxy_plus_gfw_list_v6"
		sed -r -e "s/(.*)/server=\/\1\/127.0.0.1#$dns_port\nnftset=\/\1\\/4#inet#fw4#homeproxy_plus_gfw_list_v4$gfw_nftset_v6/g" \
			"$HP_DIR/resources/gfw_list.txt" > "$DNSMASQ_DIR/gfw_list.conf"
		;;
	proxy_mainland_china)
		sed -r -e "s/(.*)/server=\/\1\/127.0.0.1#$dns_port/g" \
			"$HP_DIR/resources/china_list.txt" > "$DNSMASQ_DIR/china_list.conf"
		;;
	esac

	if [ "$routing_mode" != "custom" ] && [ -s "$HP_DIR/resources/proxy_list.txt" ]; then
		local wan_nftset_v6=""
		[ "$ipv6_support" -eq 0 ] || wan_nftset_v6=",6#inet#fw4#homeproxy_plus_wan_proxy_addr_v6"
		sed -r -e '/^\s*$/d' -e "s/(.*)/server=\/\1\/127.0.0.1#$dns_port\nnftset=\/\1\\/4#inet#fw4#homeproxy_plus_wan_proxy_addr_v4$wan_nftset_v6/g" \
			"$HP_DIR/resources/proxy_list.txt" > "$DNSMASQ_DIR/proxy_list.conf"
	fi

	if ! /etc/init.d/dnsmasq restart >/dev/null 2>&1; then
		log "Error: failed to reload dnsmasq."
		return 1
	fi

	config_get table_mark "infra" "table_mark" "103"
	case "$proxy_mode" in
	redirect_tproxy)
		local outbound_udp_node tproxy_mark
		config_get outbound_udp_node "config" "main_udp_node" "nil"
		if [ "$outbound_udp_node" != "nil" ] || [ "$routing_mode" = custom ]; then
			config_get tproxy_mark "infra" "tproxy_mark" "104"
			homeproxy_add_rule 4 "$tproxy_mark" "$table_mark" || return 1
			homeproxy_add_route 4 local "$table_mark" lo || return 1

			if [ "$ipv6_support" -eq 1 ]; then
				homeproxy_add_rule 6 "$tproxy_mark" "$table_mark" || return 1
				homeproxy_add_route 6 local "$table_mark" lo || return 1
			fi
		fi
		;;
	redirect_tun|tun)
		local tun_name tun_mark tun_owner_file="$RUN_DIR/.tun-device"
		config_get tun_name "infra" "tun_name" "singtunp0"
		config_get tun_mark "infra" "tun_mark" "105"
		if ip link show "$tun_name" >/dev/null 2>&1; then
			if [ ! -f "$tun_owner_file" ] || [ "$(cat "$tun_owner_file")" != "$tun_name" ]; then
				log "Error: refusing to use an existing unowned TUN device: $tun_name."
				return 1
			fi
		else
			ip tuntap add mode tun user root name "$tun_name" || return 1
			if ! printf '%s\n' "$tun_name" > "$tun_owner_file"; then
				ip tuntap del mode tun name "$tun_name" 2>/dev/null || true
				return 1
			fi
		fi
		ip link set "$tun_name" up || return 1

		homeproxy_add_route 4 default "$table_mark" "$tun_name" || return 1
		homeproxy_add_rule 4 "$tun_mark" "$table_mark" || return 1

		if [ "$ipv6_support" -eq 1 ]; then
			homeproxy_add_route 6 default "$table_mark" "$tun_name" || return 1
			homeproxy_add_rule 6 "$tun_mark" "$table_mark" || return 1
		fi
		;;
	esac

	return 0
}

homeproxy_network_stop() {
	local cleanup_failed=0 state_cleanup_failed=0 kind family field1 field2 field3
	if [ -f "$(homeproxy_network_state)" ]; then
		while IFS='|' read -r kind family field1 field2 field3; do
			case "$kind" in
			rule)
				if homeproxy_rule_exists "$family" "$field1" "$field2"; then
					if [ "$family" = 6 ]; then
						ip -6 rule del fwmark "$field1" table "$field2" 2>/dev/null || {
							log "Error: failed to remove owned IPv6 policy rule for mark $field1."
							state_cleanup_failed=1
						}
					else
						ip rule del fwmark "$field1" table "$field2" 2>/dev/null || {
							log "Error: failed to remove owned IPv4 policy rule for mark $field1."
							state_cleanup_failed=1
						}
					fi
				fi
				;;
			route)
				if homeproxy_route_exists "$family" "$field1" "$field2" "$field3"; then
					if [ "$family" = 6 ] && [ "$field1" = local ]; then
						ip -6 route del local ::/0 dev lo table "$field2" 2>/dev/null || {
							log "Error: failed to remove owned IPv6 local route from table $field2."
							state_cleanup_failed=1
						}
					elif [ "$family" = 4 ] && [ "$field1" = local ]; then
						ip route del local 0.0.0.0/0 dev lo table "$field2" 2>/dev/null || {
							log "Error: failed to remove owned IPv4 local route from table $field2."
							state_cleanup_failed=1
						}
					elif [ "$family" = 6 ]; then
						ip -6 route del default dev "$field3" table "$field2" 2>/dev/null || {
							log "Error: failed to remove owned IPv6 default route from table $field2."
							state_cleanup_failed=1
						}
					else
						ip route del default dev "$field3" table "$field2" 2>/dev/null || {
							log "Error: failed to remove owned IPv4 default route from table $field2."
							state_cleanup_failed=1
						}
					fi
				fi
				;;
			esac
		done < "$(homeproxy_network_state)"
		if [ "$state_cleanup_failed" -eq 0 ]; then
			rm -f "$(homeproxy_network_state)"
		else
			cleanup_failed=1
		fi
	fi

	rm -f "$DNSMASQ_DIR/../dnsmasq-homeproxy_plus.conf"
	rm -rf "$DNSMASQ_DIR"
	if ! /etc/init.d/dnsmasq restart >/dev/null 2>&1; then
		log "Error: failed to reload dnsmasq while stopping the service."
		cleanup_failed=1
	fi

	return "$cleanup_failed"
}
