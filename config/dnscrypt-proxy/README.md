# Stealth DNS Infrastructure (v2026.05)

## 🚀 Key Features

- **Stealth Anonymization**: Utilizes **Anonymized DNSCrypt** and **Oblivious DoH (ODoH)** to decouple your IP from your DNS queries via a multi-hop relay network.
- **DPI Evasion**: Prioritizes **HTTP/3 (QUIC)** transport, making DNS traffic statistically indistinguishable from standard HTTPS/UDP traffic (video streams, modern web apps).
- **CDN Optimization (Secure ECS)**: Implementation of **EDNS Client Subnet** metadata routed via relays. Content Delivery Networks (Google, Apple, Netflix) see the relay's subnet and provide the fastest local mirrors, while your origin IP remains hidden.
- **Hyper-Caching**: Aggressive caching strategy (`TTL: 1 week`, `10k+ entries`) reduces network entropy and ensures uptime during ISP-level UDP shaping or "carpet" blocking.
- **Local Deterministic Filtering**: Professional-grade blocklists (HaGezi Multi PRO + OISD) with 114k+ rules processed locally to evade provider-level DNS hijacking and SNI triggers.

## 📂 Project Structure

The project follows a decoupled, **Git-ready architecture** separating static configuration from volatile runtime data.

```text
~/.config/dnscrypt-proxy/
├── dnscrypt-proxy.toml          # Master Configuration (Entry Point)
├── README.md                    # Project Documentation (Global Overview)
├── rules/                       # [GIT] User-defined static rules
│   ├── blocked-ips.txt               # IP-level blocklist/sinkhole
│   ├── captive-portals.txt           # OS-specific connectivity overrides
│   ├── cloaking-rules.txt            # Local DNS hijacking/aliasing (HOSTS replacement)
│   ├── domains-allowlist.txt         # Global overrides (False Positive protection)
│   ├── domains-blocklist.conf        # "Recipe" for blocklist generation (URLs)
│   ├── domains-blocklist-local-additions.txt  # Personal custom blocks
│   ├── domains-time-restricted.txt   # Schedule-based blocking rules
│   └── forwarding-rules.txt          # Local zone upstream routing
├── scripts/                     # [GIT] Automation Toolchain
│   ├── setup.sh                      # One-click deployment & system hardening
│   ├── health-check.sh               # PhD-level system diagnostic suite
│   └── update-maintenance.sh         # Autonomous blocklist aggregator
├── docs/                        # [GIT] Technical Specifications
│   └── audit.md                 # Architectural audit and tool analysis
├── system/                      # [GIT] OS Integration
│   └── com.x0r.dnscrypt.maintenance.plist  # macOS LaunchDaemon (Scheduler)
├── backups/                     # Recovery data
│   └── dnscrypt-proxy.toml.backup.stable # Last known good configuration
└── dns-update/                  # Utility directory
    └── secrets.conf                  # API keys for private feeds (0 bytes)
```

## 🛠️ Blocklist Generation Logic

The `domains-blocklist.txt` is an aggregated artifact and is **not stored in Git**.

### The Process:
1. **Source Parsing**: The `rules/domains-blocklist.conf` defines high-fidelity upstream providers.
2. **Intelligent Aggregation**: The `scripts/update-maintenance.sh` script (called via `setup.sh` or Launchd) downloads all sources.
3. **Suffix Pruning**: The generation logic automatically removes redundant subdomains to maximize memory efficiency.
4. **Decoupled Placement**: The final artifact is stored in `/opt/homebrew/var/cache/dnscrypt-proxy/`.

## 🔧 Installation & Deployment

To deploy this elite stack on any macOS system with a single command:

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url> ~/.config/dnscrypt-proxy
   ```
2. **Execute Automated Setup**:
   ```bash
   cd ~/.config/dnscrypt-proxy
   chmod +x scripts/setup.sh
   ./scripts/setup.sh
   ```
   *The `setup.sh` script will automatically:*
   - Check and install all dependencies (Homebrew/DNSCrypt).
   - Configure system directories and permissions.
   - Harden all macOS network interfaces (Anti-Leak).
   - Initialize the maintenance scheduler.
   - Execute the final health-check suite.

## 🛡️ Backup & Rollback Procedure

The `backups/` directory must **always** contain a verified stable configuration.

### How to Rollback:
If connectivity is lost or `health-check.sh` fails after manual changes:
1. **Stop service**: `sudo brew services stop dnscrypt-proxy`
2. **Restore**: `cp ~/.config/dnscrypt-proxy/backups/dnscrypt-proxy.toml.backup.stable ~/.config/dnscrypt-proxy/dnscrypt-proxy.toml`
3. **Restart**: `sudo brew services start dnscrypt-proxy`

---
