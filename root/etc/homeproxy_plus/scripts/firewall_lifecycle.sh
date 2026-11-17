#!/bin/sh

homeproxy_firewall_start() {
	mkdir -p "$RUN_DIR"
	: > "$RUN_DIR/fw4_forward.nft"
	: > "$RUN_DIR/fw4_input.nft"
	: > "$RUN_DIR/fw4_post.nft"
	if ! ucode "$HP_DIR/scripts/firewall.uc"; then
		log "Error: failed to generate firewall rules."
		return 1
	fi
	if [ "$1" != "nil" ] &&
		! utpl -S "$HP_DIR/scripts/firewall_post.ut" > "$RUN_DIR/fw4_post.nft"; then
		log "Error: failed to generate client firewall rules."
		return 1
	fi
	if ! fw4 reload >/dev/null 2>&1; then
		log "Error: failed to reload firewall4."
		return 1
	fi

	return 0
}

homeproxy_firewall_stop() {
	local name cleanup_failed=0

	mkdir -p "$RUN_DIR"
	: > "$RUN_DIR/fw4_forward.nft"
	: > "$RUN_DIR/fw4_input.nft"
	: > "$RUN_DIR/fw4_post.nft"
	if ! fw4 reload >/dev/null 2>&1; then
		log "Error: failed to remove HomeProxy-Plus firewall includes."
		cleanup_failed=1
	fi

	for name in homeproxy_plus_dstnat_redir homeproxy_plus_output_redir \
		homeproxy_plus_redirect homeproxy_plus_redirect_proxy \
		homeproxy_plus_redirect_proxy_port homeproxy_plus_redirect_lanac \
		homeproxy_plus_mangle_prerouting homeproxy_plus_mangle_output \
		homeproxy_plus_mangle_tproxy homeproxy_plus_mangle_tproxy_port \
		homeproxy_plus_mangle_tproxy_lanac homeproxy_plus_mangle_mark \
		homeproxy_plus_mangle_tun homeproxy_plus_mangle_tun_mark; do
		if nft list chain inet fw4 "$name" >/dev/null 2>&1; then
			if ! nft flush chain inet fw4 "$name" 2>/dev/null; then
				log "Error: failed to flush owned firewall chain $name."
				cleanup_failed=1
			fi
		fi
	done
	for name in homeproxy_plus_dstnat_redir homeproxy_plus_output_redir \
		homeproxy_plus_redirect homeproxy_plus_redirect_proxy \
		homeproxy_plus_redirect_proxy_port homeproxy_plus_redirect_lanac \
		homeproxy_plus_mangle_prerouting homeproxy_plus_mangle_output \
		homeproxy_plus_mangle_tproxy homeproxy_plus_mangle_tproxy_port \
		homeproxy_plus_mangle_tproxy_lanac homeproxy_plus_mangle_mark \
		homeproxy_plus_mangle_tun homeproxy_plus_mangle_tun_mark; do
		if nft list chain inet fw4 "$name" >/dev/null 2>&1 &&
			! nft delete chain inet fw4 "$name" 2>/dev/null; then
			log "Error: failed to delete owned firewall chain $name."
			cleanup_failed=1
		fi
	done
	for name in homeproxy_plus_local_addr_v4 homeproxy_plus_local_addr_v6 \
		homeproxy_plus_gfw_list_v4 homeproxy_plus_gfw_list_v6 \
		homeproxy_plus_mainland_addr_v4 homeproxy_plus_mainland_addr_v6 \
		homeproxy_plus_wan_proxy_addr_v4 homeproxy_plus_wan_proxy_addr_v6 \
		homeproxy_plus_wan_direct_addr_v4 homeproxy_plus_wan_direct_addr_v6 \
		homeproxy_plus_routing_port; do
		if nft list set inet fw4 "$name" >/dev/null 2>&1; then
			if ! nft flush set inet fw4 "$name" 2>/dev/null ||
				! nft delete set inet fw4 "$name" 2>/dev/null; then
				log "Error: failed to remove owned firewall set $name."
				cleanup_failed=1
			fi
		fi
	done

	if ! fw4 reload >/dev/null 2>&1; then
		log "Error: failed to reload firewall4 while stopping the service."
		cleanup_failed=1
	fi

	return "$cleanup_failed"
}
