<!-- Copyright (C) 2026 Cerostep -->

# IPK software feed

Releases built with the feed-index workflow publish `Packages.gz` alongside
the architecture-specific IPK files. The package manager uses this index to
obtain the package download size and description; `opkg status` does not retain
those fields for packages installed directly from an IPK file.

To make the metadata available to LuCI's package manager, add the release feed
on the router and refresh package lists:

```sh
echo 'src/gz homeproxy_plus https://github.com/Cerostep/homeproxy-plus/releases/latest/download' >> /etc/opkg/customfeeds.conf
opkg update
```

The configured OpenWrt architecture still determines which package can be
installed. The feed index contains all supported architectures.
