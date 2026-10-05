# ---
# schema: "mdd-node-v1"
# id: ".meta/research/anti_patterns_registry.md"
# title: "Canonical Anti-Pattern Registry — macOS Fish Shell"
# layer: "Meta / Research"
# responsibility: "Deduplicated, synthesized registry of all known shell startup anti-patterns on macOS Apple Silicon. Supersedes anti_patterns_macOS.md (archived) and scratch_cli.md (archived)."
# dependencies: []
# backlinks: ["MAP_OF_CONTENT.md", "ARCHITECTURE_AUDIT.md", "sub_11ms_startup_latency_remediation.md"]
# created_at: "2026-10-04"
# updated_at: "2026-10-04"
# tags: ["anti-patterns", "performance", "macOS", "fish", "latency", "security"]
# ---

# Canonical Anti-Pattern Registry — macOS Fish Shell

> **Synthesized from:** `anti_patterns_macOS.md` (5,958 lines, archived), `scratch_cli.md` (archived), cross-referenced with all 19 research corpus files.
> **Current SLA baseline:** 11.0 ms ± 0.7 ms

---

## AP-1 — `fork()/posix_spawn()` per `$()` subshell on XNU

**Documented in:** `ARCHITECTURE_AUDIT.md` AP-1.1, `darwin_kernel_shim_latency.md` §2, `sub_11ms…` §2, `mise_shims…` §3  
**Cost:** ~3 ms per external call (Mach IPC overhead on XNU)  
**Status:** ✅ **ELIMINATED** — all external calls replaced with C++ builtins (`path normalize`, `path filter`, `string`)

**Pattern to avoid:**
```fish
# ❌ Spawns a fork for every invocation
set dir (command dirname $argv)
```

**Correct approach:**
```fish
# ✅ Zero fork — C++ builtin
set dir (path dirname $argv)
```

---

## AP-2 — `eval (tool --init)` dynamic hook forks

**Documented in:** `ARCHITECTURE_AUDIT.md` AP-1.2, `mise_shims…` §2.5, `startup_latency…` §III  
**Cost:** 80–300 ms (spawns interpreter + eval overhead per prompt)  
**Status:** ✅ **ELIMINATED** — `mise activate` replaced by static shim PATH injection

**Pattern to avoid:**
```fish
# ❌ Forks ruby/python/node VM on every prompt
eval (mise activate fish)
eval (rbenv init -)
eval (pyenv init -)
```

**Correct approach:**
```fish
# ✅ Static PATH prepend in 03-path.fish — zero runtime eval
set -g _mise_shims_dir "$HOME/.local/share/mise/shims"
```

---

## AP-3 — `eval (brew shellenv)` Ruby VM fork

**Documented in:** `ARCHITECTURE_AUDIT.md` AP-5.2, `mise_shims…` §2.5  
**Cost:** 100–200 ms (spawns Ruby VM + reads Homebrew state)  
**Status:** ✅ **ELIMINATED** — static Homebrew prefix in `02-brew.fish`

**Pattern to avoid:**
```fish
# ❌ Spawns Ruby VM on every non-interactive startup
eval (/opt/homebrew/bin/brew shellenv)
```

**Correct approach:**
```fish
# ✅ Static export in 02-brew.fish — measured once, never forked
set -gx HOMEBREW_PREFIX /opt/homebrew
```

---

## AP-4 — Mise shim trampoline ~55–111 ms penalty

**Documented in:** `darwin_kernel_shim_latency.md` §2, `architecture_decision_brewfile_vs_mise.md` §1, `mise_shims…` §2.3  
**Cost:** 55–111 ms per shim invocation (AMFI CDHash validation + dyld4)  
**Status:** ⚠️ **ACCEPTED** — shims only trigger on actual tool invocations, not on shell boot. Host primitives (git, curl, openssl) are served by Homebrew and bypass all shims.

**Mitigation:** Use `mise x --` only for project-specific tool calls. Keep host primitives outside mise.

---

## AP-5 — `$fish_user_paths` universal variable trap

**Documented in:** `sub_11ms…` §2A, `fish_theme_parser_bypass.md`  
**Cost:** ~323 µs per startup (triggers `__fish_reconstruct_path` observer on every boot)  
**Status:** ✅ **ELIMINATED** — no `fish_add_path` calls anywhere; PATH is set as a global array in `03-path.fish`

**Pattern to avoid:**
```fish
# ❌ Appends to universal (persistent) variable — triggers path rebuild observer
fish_add_path /usr/local/bin
```

**Correct approach:**
```fish
# ✅ Global variable — no observer, no rebuild
set -g fish_user_paths ""
```

---

## AP-6 — `umask` is a Fish function, not a builtin

**Documented in:** `sub_11ms…` §2B  
**Cost:** Triggers autoload of `__fish_umask.fish` on first invocation  
**Status:** ✅ Not used in hot path. Non-issue for SLA.

---

## AP-7 — `__fish_theme_migrate` autoload hook

**Documented in:** `sub_11ms…` §2C, `fish_theme_parser_bypass.md` §III.3  
**Cost:** ~200 µs (reads and parses `~/.config/fish/themes/*.theme` on startup)  
**Status:** ✅ **ELIMINATED** — stub function in `functions/__fish_theme_migrate.fish` bypasses all theme parsing

---

## AP-8 — `type -q` PATH scan in hot path

**Documented in:** `sub_11ms…` §2D, `ARCHITECTURE_AUDIT.md` §2.3  
**Cost:** Full PATH walk per `type -q` call (~50–100 µs each)  
**Status:** ✅ **ELIMINATED** — replaced with `test -x /path/to/binary` static checks where possible

---

## AP-9 — `starship module character` per-command fork

**Documented in:** `ARCHITECTURE_AUDIT.md` Task 2, `darwin_kernel_shim_latency.md` §5  
**Cost:** Depends on enabled modules. Avoided via `command_timeout = 100` and minimal module set.  
**Status:** ⚠️ **MITIGATED** — Starship config limits expensive modules. Pre-caching in `10-runtimes.fish` defers cold compilation.

---

## AP-10 — Stale init cache (no mtime invalidation)

**Documented in:** `ARCHITECTURE_AUDIT.md` Task 1  
**Status:** ✅ **OBSOLETE** — replaced by SWR cache engine in `10-runtimes.fish` with full mtime + hash invalidation

---

## AP-11 — AMFI CDHash validation cost (156 MB mise binary)

**Documented in:** `darwin_kernel_shim_latency.md` §2.1, `11-fish4-baremetal…` §6.1, `architecture_decision…` §1  
**Cost:** ~40–80 ms on first boot (kernel must verify code signature of 156 MB Mach-O)  
**Status:** ⚠️ **ACCEPTED** — unavoidable on macOS. Amortized by OS dyld shared cache after first run.

---

## AP-12 — `mise cache_duration` plaintext credential breach

**Documented in:** `zero_leakage_secrets…` §2.4  
**Risk:** Mise caches `MISE_ENV` plaintext to `~/.local/share/mise/cache/` with configurable TTL  
**Status:** ✅ **MITIGATED** — API keys not stored in `[env]` table. JIT Keychain injection via `functions/claude.fish` pattern.

---

## AP-13 — `KERN_PROCARGS2` env snooping

**Documented in:** `zero_leakage_secrets…` §2.5, `sensitive_data_storage_architecture.md`, `secure_enclave_automation_architecture.md`  
**Risk:** Any process can read env vars of any process via `sysctl KERN_PROCARGS2`  
**Mitigation:** Do not store secrets in environment variables at any point. Use JIT Keychain pattern exclusively.  
**Status:** ✅ **MITIGATED** by 3-tier secret model (SEP → Keychain JIT → SOPS+age)

---

## AP-14 — Conda / nvm / pyenv eager init bloat

**Documented in:** `anti_patterns_macOS.md` §5, `ARCHITECTURE_AUDIT.md` AP-5.1  
**Cost:** 100–300 ms per tool (Python VM boot + env activation)  
**Status:** ✅ **ELIMINATED** — replaced by lazy wrapper functions (`functions/micromamba.fish`, `functions/mamba.fish`). Mise handles project runtimes without eager activation.

---

## AP-15 — Double PTY tmux overhead

**Documented in:** `scratch_cli.md` §1 (archived), `tmux_tui_graphics_passthrough.md` §4  
**Cost:** 15–30 ms additional input latency per keystroke; PTY bridging overhead  
**Status:** ⚠️ **ACCEPTED** — tmux session stability outweighs latency cost for this workstation. Escape-time set to 0 in `tmux.conf`. Kitty-native multiplexer is an option for future evaluation.

---

## AP-16 — Monolith compilation approach

**Documented in:** `sub_10ms_monolith_architecture.md` (archived)  
**Status:** 🔴 **ABANDONED** — superseded by per-file AOT cache (SWR engine). Monolith `build_env.fish` and `src/conf.d/` architecture never shipped. Current design achieves equivalent VFS reduction through Fish's native bytecode cache + pre-forked daemon potential (see `11-fish4-baremetal…`).

---

## Remediation Status Summary

| ID | Anti-Pattern | Status |
|----|-------------|--------|
| AP-1 | fork() per subshell | ✅ ELIMINATED |
| AP-2 | eval dynamic hooks | ✅ ELIMINATED |
| AP-3 | eval brew shellenv | ✅ ELIMINATED |
| AP-4 | Mise shim trampoline | ⚠️ ACCEPTED |
| AP-5 | fish_user_paths uvar | ✅ ELIMINATED |
| AP-6 | umask autoload | ✅ NOT IN HOT PATH |
| AP-7 | theme migrate hook | ✅ ELIMINATED |
| AP-8 | type -q PATH scan | ✅ ELIMINATED |
| AP-9 | starship per-command | ⚠️ MITIGATED |
| AP-10 | stale init cache | ✅ OBSOLETE (SWR) |
| AP-11 | AMFI CDHash cost | ⚠️ ACCEPTED |
| AP-12 | mise plaintext cache | ✅ MITIGATED |
| AP-13 | KERN_PROCARGS2 snoop | ✅ MITIGATED |
| AP-14 | conda/nvm/pyenv eager | ✅ ELIMINATED |
| AP-15 | double PTY tmux | ⚠️ ACCEPTED |
| AP-16 | monolith compilation | 🔴 ABANDONED |
