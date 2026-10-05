---
title: "Research: Background AOT Compilation & SWR Cache Engine"
module: .meta/research/10-runtimes-swr-architecture.md
layer: Meta / Research
responsibility: Eventual consistency model and SWR caching architecture for shell language runtimes in conf.d/10-runtimes.fish.
dependencies: [conf.d/10-runtimes.fish]
backlinks: [MAP_OF_CONTENT.md, README.md]
created_at: 2026-09-27
updated_at: 2026-10-03
tags: [research, runtimes, swr, aot, cache, performance, zero-fork]
---

# Background AOT Compilation & SWR Cache Engine

**Target Module:** `conf.d/10-runtimes.fish`
**SLA Target:** < 10ms (Singularity)
**Results:** Latency reduced by ~95% (from >200ms to ~10ms). Zero blocking `fork/exec` calls.

## Paradigm
This module implements an eventual consistency model for shell language runtimes (NVM, Pyenv, SDKMAN, Cargo) using a **Stale-While-Revalidate (SWR)** caching layer. It fundamentally decouples the synchronous shell initialization loop from the unbounded I/O latency and process-spawning costs intrinsic to version managers.

## Objectives
1. **Singularity SLA (< 10ms):** Guarantee instant, zero-hesitation interactive shell startup.
2. **Complete Toolchain Support:** Provide full semantic richness, path exposure, and deep integration for all language runtimes without compromising the latency SLA.

## Mechanism

### 1. Fast Path (Synchronous)
During the critical startup sequence, the shell natively sources a pre-compiled, statically evaluated `frontend.fish` wrapper script. This directly populates the AST, entirely circumventing virtual machine boot times (Ruby/Python logic inside version managers) and raw `posix_spawn` overhead.

### 2. Invalidation (Asynchronous)
Once the prompt is available, the loaded frontend script performs an $O(1)$ staleness check against project configuration files (e.g., `package.json`, `.node-version`, `Cargo.toml`) in the current directory or by checking internal runtime states.

### 3. AOT Compilation (Detached Background)
If the cache is deemed stale, the frontend detaches a background worker (`x_runtimes_build`). This background worker performs the heavy lifting:
- Spawns the required language runtime evaluations.
- Re-compiles the environment paths, variables, and alias wrappers.
- Atomically overwrites the cache state (`mv tmp frontend.fish`).

The updated environment seamlessly becomes available on the next shell prompt redraw or reload, adhering precisely to the SWR paradigm.

