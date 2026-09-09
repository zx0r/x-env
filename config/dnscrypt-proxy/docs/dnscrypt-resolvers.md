## List of servers to use

Servers from the `public-resolvers` source (see down below) can be viewed here: https://dnscrypt.info/public-servers
The proxy will automatically pick working servers from this list. Note that the `require_*` filters do **NOT** apply when using this setting.
By default, this list is empty and all registered servers matching the `require_*` filters will be used instead.

### Reference Links

**Public DNS server directories**
- Interactive list of public DNS servers: https://dnscrypt.info/public-servers
- Interactive map of public DNS servers: https://dnscrypt.info/map
- Public DNS server status: https://status.dnscrypt.info

**Resolver sources and downloads**
- Stable download URLs: https://github.com/DNSCrypt/dnscrypt-resolvers/tree/master/v3
- Mirror: https://download.dnscrypt.info/dnscrypt-resolvers/v3/
- Additional DNS server sources: https://github.com/jedisct1/dnscrypt-proxy/wiki/DNS-server-sources

**Anonymized DNS relays**
- Relay list: https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/relays.md
- Direct download: https://download.dnscrypt.info/dnscrypt-resolvers/v3/relays.md

**Oblivious DoH (ODoH)**
- ODoH servers: https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/odoh-servers.md
- ODoH servers (direct): https://download.dnscrypt.info/dnscrypt-resolvers/v3/odoh-servers.md
- ODoH relays: https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/odoh-relays.md
- ODoH relays (direct): https://download.dnscrypt.info/dnscrypt-resolvers/v3/odoh-relays.md

### Minisign Public Key
```bash
# This key is used to verify the authenticity and integrity of downloaded resolver lists. 
# The `dnscrypt-proxy` utility handles verification automatically.
RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3
```

source: https://github.com/dnscrypt/dnscrypt-resolvers
