# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 Cerostep
# Copyright (C) 2022-2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

LUCI_TITLE:=HomeProxy-Plus proxy platform for OpenWrt
LUCI_PKGARCH:=$(ARCH_PACKAGES)
USERID:=sing-box=5566:sing-box=5566
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
LUCI_DEPENDS:= \
	+ca-bundle \
	+curl \
	+kmod-inet-diag \
	+kmod-tun \
	+kmod-nft-queue \
	+firewall4 \
	+kmod-nft-tproxy \
	+ucode-mod-digest

PKG_NAME:=luci-app-homeproxy-plus

define Build/Prepare/luci-app-homeproxy-plus
	@test "$(ARCH_PACKAGES)" = "aarch64_generic" -o "$(ARCH_PACKAGES)" = "i386_pentium4" -o "$(ARCH_PACKAGES)" = "x86_64" || { echo "Unsupported sing-box package architecture: $(ARCH_PACKAGES)" >&2; exit 1; }
	sh "$(CURDIR)/.github/fetch-sing-box.sh" "$(ARCH_PACKAGES)" "$(PKG_BUILD_DIR)/root/usr/bin/sing-box"
endef

define Package/luci-app-homeproxy-plus/conffiles
/etc/config/homeproxy_plus
/etc/homeproxy_plus/certs/
/etc/homeproxy_plus/ruleset/
/etc/homeproxy_plus/resources/direct_list.txt
/etc/homeproxy_plus/resources/proxy_list.txt
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
