<!-- Copyright (C) 2026 Cerostep -->

# IPK software feed

Releases publish a signed `Packages.gz` index alongside the architecture-specific
IPK files. The package manager uses this index to obtain the package download
size and description; `opkg status` does not retain those fields for packages
installed directly from an IPK file.

Trust the published signing key once, then add the release feed and refresh
package lists:

```sh
curl -fsSLo /tmp/homeproxy-plus-feed.pub \
  https://raw.githubusercontent.com/Cerostep/homeproxy-plus/master/.github/homeproxy-plus-feed.pub
test "$(usign -F -p /tmp/homeproxy-plus-feed.pub)" = 'a776627ae8fe95d2'
opkg-key add /tmp/homeproxy-plus-feed.pub
echo 'src/gz homeproxy_plus https://github.com/Cerostep/homeproxy-plus/releases/latest/download' >> /etc/opkg/customfeeds.conf
opkg update
```

For networks that cannot access GitHub directly, use the GH-Proxy URLs while
keeping the same public-key fingerprint check and package signature validation:

```sh
curl -fsSLo /tmp/homeproxy-plus-feed.pub \
  https://gh-proxy.org/https://github.com/Cerostep/homeproxy-plus/releases/latest/download/homeproxy-plus-feed.pub
test "$(usign -F -p /tmp/homeproxy-plus-feed.pub)" = 'a776627ae8fe95d2'
opkg-key add /tmp/homeproxy-plus-feed.pub
echo 'src/gz homeproxy_plus https://gh-proxy.org/https://github.com/Cerostep/homeproxy-plus/releases/latest/download' >> /etc/opkg/customfeeds.conf
opkg update
```

The public-key fingerprint is `a776627ae8fe95d2`. Do not disable opkg signature
verification. The corresponding private key is stored only as the GitHub Actions
secret `USIGN_SECRET_KEY`.

The configured OpenWrt architecture still determines which package can be
installed. The feed index contains all supported architectures.
