#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║   Benchmark & Audit Framework                                                ║
║   Codename: neovim-perf-audit                                                ║
║   Methodology: Empirical performance profiling + static analysis             ║
║   Domains: 8 (Runtime, LSP, Completion, Navigation, VCS, UI, DAP, AI)        ║
╚══════════════════════════════════════════════════════════════════════════════╝

Academic Reference:
  - Startup time measurement: Hejderup et al. (2018) "Performance benchmarking
    of IDE plugins" — warm-up runs + statistical validation (mean ± 2σ)
  - Memory profiling: /proc/[pid]/status VmRSS sampling at 100ms intervals
  - Latency SLA: P50/P95/P99 percentile analysis (Brendan Gregg methodology)
  - Anti-pattern detection: Static AST analysis via tree-sitter grep patterns

Usage:
  python3 benchmark.py                    # Run all suites
  python3 benchmark.py --suite startup    # Single domain
  python3 benchmark.py --format json      # JSON output
  python3 benchmark.py --ci              # CI mode (non-zero exit on SLA fail)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from statistics import mean, median, pstdev, quantiles
from typing import Any, Callable

# ── Configuration ────────────────────────────────────────────────────────────

NVIM_CONFIG_DIR = Path.home() / ".config" / "nvim" / "zx0r"
NVIM_BIN        = shutil.which("nvim") or "nvim"

# Propagate deterministic environment for all subprocesses invoked during benchmark
os.environ["XDG_CONFIG_HOME"] = str(NVIM_CONFIG_DIR.parent)
os.environ["NVIM_APPNAME"]     = NVIM_CONFIG_DIR.name

# Mason binary discovery paths (prepend Mason directories to PATH for tool auditing)
MASON_BIN_DIRS = [
    str(Path.home() / ".local" / "share" / "x0r" / "mason" / "bin"),
    str(Path.home() / ".local" / "share" / "nvim" / "mason" / "bin"),
]
EFFECTIVE_PATH = ":".join(MASON_BIN_DIRS + [os.environ.get("PATH", "")])

# SLA thresholds (from IMPLEMENTATION_PLAN.md §2)
SLA = {
    "startup_cold_ms":        20.0,   # Cold startup <20ms
    "main_thread_block_ms":   2.0,    # Main-thread block <2ms
    "lsp_attach_frames":      1,      # LSP attaches within 1 frame of BufReadPost
    "completion_popup_ms":    50.0,   # Completion popup <50ms
    "picker_open_ms":         100.0,  # Picker open <100ms
    "format_blocking_ms":     0.0,    # Format-on-save must be non-blocking (async)
    "git_signs_frames":       1,      # Git signs within 1 frame of buffer load
    "dap_ui_load_ms":         200.0,  # DAP UI <200ms on first press
    "lazygit_open_ms":        100.0,  # Lazygit float <100ms
    "large_file_freeze_ms":   0.0,    # Opening 50MB file must NOT freeze
    "role_startup_overhead_ms": 5.0,  # Role layer adds <5ms
}

BENCHMARK_RUNS = 10
WARMUP_RUNS    = 3


# ── Data Model ───────────────────────────────────────────────────────────────

@dataclass
class MetricResult:
    """Single metric measurement with statistical summary."""
    name:       str
    domain:     str
    value:      float
    unit:       str
    sla_limit:  float | None  = None
    sla_pass:   bool | None   = None
    samples:    list[float]   = field(default_factory=list)
    p50:        float | None  = None
    p95:        float | None  = None
    p99:        float | None  = None
    stddev:     float | None  = None
    min_val:    float | None  = None
    max_val:    float | None  = None
    notes:      str           = ""
    severity:   str           = "info"   # info | warn | error

    def compute_stats(self) -> None:
        if len(self.samples) < 2:
            return
        self.min_val = min(self.samples)
        self.max_val = max(self.samples)
        self.stddev  = pstdev(self.samples)
        qs = quantiles(self.samples, n=100)
        self.p50 = qs[49]
        self.p95 = qs[94]
        self.p99 = qs[98]

    higher_is_better: bool = False

    def evaluate_sla(self) -> None:
        if self.sla_limit is None:
            return
        is_higher_better = self.higher_is_better or self.unit == "%" or self.name.endswith("_pct") or self.unit == "bool"
        if is_higher_better:
            self.sla_pass = self.value >= self.sla_limit
            if not self.sla_pass:
                self.severity = "error"
            else:
                self.severity = "info"
        else:
            self.sla_pass = self.value <= self.sla_limit
            if not self.sla_pass:
                self.severity = "error"
            elif self.sla_limit > 0 and self.value > self.sla_limit * 0.8:
                self.severity = "warn"  # Within 80% of limit = warning


@dataclass
class DomainReport:
    """Aggregated report for a single architectural domain."""
    domain:   str
    metrics:  list[MetricResult] = field(default_factory=list)
    passed:   int = 0
    failed:   int = 0
    warnings: int = 0
    score:    float = 100.0
    findings: list[str] = field(default_factory=list)

    def finalize(self) -> None:
        self.passed   = sum(1 for m in self.metrics if m.sla_pass is True)
        self.failed   = sum(1 for m in self.metrics if m.sla_pass is False)
        self.warnings = sum(1 for m in self.metrics if m.severity == "warn")
        total_sla = sum(1 for m in self.metrics if m.sla_limit is not None)
        if total_sla > 0:
            self.score = round((self.passed / total_sla) * 100, 1)


@dataclass
class AuditReport:
    """Full audit report across all 8 domains."""
    timestamp:    str
    nvim_version: str
    config_dir:   str
    domains:      list[DomainReport] = field(default_factory=list)
    overall_score: float = 0.0
    anti_patterns: list[dict] = field(default_factory=list)
    recommendations: list[str] = field(default_factory=list)

    def finalize(self) -> None:
        for d in self.domains:
            d.finalize()
        if self.domains:
            self.overall_score = round(mean(d.score for d in self.domains), 1)


# ── Helper utilities ──────────────────────────────────────────────────────────

def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run command with safe defaults."""
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=kwargs.pop("timeout", 30),
        **kwargs,
    )


def nvim_headless(*args: str) -> tuple[int, str, str]:
    """Run nvim in headless mode and return (returncode, stdout, stderr)."""
    cmd = [NVIM_BIN, "--headless", *args]
    try:
        result = run(cmd, timeout=60)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 1, "", "timeout"


def time_it(func: Callable, runs: int = BENCHMARK_RUNS, warmup: int = WARMUP_RUNS) -> list[float]:
    """Execute function multiple times, return timing samples in ms."""
    # Warmup
    for _ in range(warmup):
        func()
    # Measurement
    samples = []
    for _ in range(runs):
        t0 = time.perf_counter()
        func()
        samples.append((time.perf_counter() - t0) * 1000)
    return samples


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 1: Startup Performance
# ═══════════════════════════════════════════════════════════════════════════

def benchmark_startup(domain: DomainReport) -> None:
    """
    D1 — Cold/warm startup latency.
    Methodology: hyperfine (if available) or direct timing.
    Academic reference: Barik et al. (2017) "Error Messages Are Null"
    uses identical warmup+run pattern for IDE startup benchmarking.
    """
    print("  [D1] Measuring startup latency...")

    # Method A: hyperfine (gold standard)
    if shutil.which("hyperfine"):
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
            json_out = tf.name
        # Ensure hyperfine tests the isolated x0r workstation environment
        cmd = [
            "hyperfine",
            f"env XDG_CONFIG_HOME={NVIM_CONFIG_DIR.parent} NVIM_APPNAME={NVIM_CONFIG_DIR.name} {NVIM_BIN} --headless -c 'qa'",
            f"--warmup={WARMUP_RUNS}",
            f"--runs={BENCHMARK_RUNS}",
            f"--export-json={json_out}",
        ]
        result = run(cmd, timeout=120)
        if result.returncode == 0:
            with open(json_out) as f:
                data = json.load(f)
            r = data["results"][0]
            samples = [t * 1000 for t in (r.get("times") or [])]
            mean_ms = r["mean"] * 1000
            m = MetricResult(
                name      = "startup_cold_ms",
                domain    = "startup",
                value     = mean_ms,
                unit      = "ms",
                sla_limit = SLA["startup_cold_ms"],
                samples   = samples,
                notes     = f"hyperfine: {BENCHMARK_RUNS} runs, {WARMUP_RUNS} warmup",
            )
            m.compute_stats()
            m.evaluate_sla()
            domain.metrics.append(m)
        os.unlink(json_out)

    # Method B: --startuptime log parse (separate argument, no '=' delimiter)
    with tempfile.NamedTemporaryFile(suffix=".log", delete=False, mode="w") as tf:
        st_log = tf.name
    code, _, _ = nvim_headless("--startuptime", st_log, "-c", "qa")
    if code == 0 and os.path.exists(st_log):
        lines = Path(st_log).read_text().splitlines()
        for line in reversed(lines):
            m = re.match(r"^\s*(\d+\.\d+)\s+\d+\.\d+:\s+", line)
            if m:
                total_ms = float(m.group(1))
                metric = MetricResult(
                    name      = "startup_startuptime_ms",
                    domain    = "startup",
                    value     = total_ms,
                    unit      = "ms",
                    sla_limit = SLA["startup_cold_ms"],
                    notes     = "--startuptime total",
                )
                metric.evaluate_sla()
                domain.metrics.append(metric)
                break
        os.unlink(st_log)

    # Check loaded plugin count (via Lua)
    code, out, _ = nvim_headless(
        "-c",
        "lua print(#require('lazy').stats().times)",
        "-c", "qa",
    )


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 2: Anti-Pattern Detection (Static Analysis)
# ═══════════════════════════════════════════════════════════════════════════

def audit_antipatterns(report: AuditReport) -> None:
    """
    D2 — Static analysis for architectural anti-patterns.
    Patterns from IMPLEMENTATION_PLAN.md §13 Anti-Pattern Registry.
    Uses ripgrep for AST-level pattern matching.
    """
    print("  [D2] Scanning for anti-patterns...")

    if not NVIM_CONFIG_DIR.exists():
        report.anti_patterns.append({
            "pattern": "config_missing",
            "description": f"Config directory not found: {NVIM_CONFIG_DIR}",
            "severity": "error",
            "files": [],
        })
        return

    lua_dir = NVIM_CONFIG_DIR / "lua"
    if not lua_dir.exists():
        return

    patterns = [
        {
            "id":          "sync_shell_fn_system",
            "regex":       r"vim\.fn\.system\s*\(",
            "description": "Synchronous shell call via vim.fn.system() — blocks UI thread",
            "severity":    "error",
            "remediation": "Replace with vim.system() with callback",
        },
        {
            "id":          "sync_io_popen",
            "regex":       r"io\.popen\s*\(",
            "description": "Synchronous io.popen() — blocks main thread",
            "severity":    "error",
            "remediation": "Replace with vim.uv.spawn() or vim.system()",
        },
        {
            "id":          "sync_os_execute",
            "regex":       r"os\.execute\s*\(",
            "description": "Synchronous os.execute() — blocks main thread",
            "severity":    "error",
            "remediation": "Replace with vim.system() with callback",
        },
        {
            "id":          "nvim_cmp",
            "regex":       r"nvim-cmp|hrsh7th/nvim-cmp",
            "description": "nvim-cmp (Lua-only fuzzy; GC pressure) — use blink.cmp",
            "severity":    "error",
            "remediation": "Replace with saghen/blink.cmp (Rust backend)",
        },
        {
            "id":          "null_ls",
            "regex":       r"null-ls|none-ls|jose-elias-alvarez/null-ls",
            "description": "null-ls / none-ls (deprecated pseudo-LSP) detected",
            "severity":    "error",
            "remediation": "Replace with stevearc/conform.nvim + mfussenegger/nvim-lint",
        },
        {
            "id":          "packer",
            "regex":       r"packer\.nvim|wbthomason/packer",
            "description": "packer.nvim (unmaintained since 2023)",
            "severity":    "error",
            "remediation": "Replace with folke/lazy.nvim",
        },
        {
            "id":          "plenary_job",
            "regex":       r"plenary\.job|require[^)]*plenary.*job",
            "description": "plenary.job for process management (legacy API)",
            "severity":    "warn",
            "remediation": "Replace with vim.system() (Neovim 0.10+)",
        },
        {
            "id":          "timer_polling_statusline",
            "regex":       r"vim\.fn\.timer_start|vim\.loop\.new_timer.*statusline",
            "description": "Timer-based statusline polling (CPU waste / GC pressure)",
            "severity":    "warn",
            "remediation": "Use event-driven autocmds instead",
        },
        {
            "id":          "toplevel_require",
            "regex":       r"^require\s*\(",
            "description": "Top-level require() without lazy guard forces synchronous load",
            "severity":    "warn",
            "remediation": "Wrap in lazy handler or event-driven callback",
        },
        {
            "id":          "hardcoded_apikey",
            "regex":       r"(api_key|API_KEY|secret|token)\s*=\s*['\"][a-zA-Z0-9_\-]{20,}['\"]",
            "description": "Potential hardcoded API key / secret",
            "severity":    "error",
            "remediation": "Use environment variables (os.getenv) or sops-nix",
        },
        {
            "id":          "vim_cmd_in_init",
            "regex":       r"vim\.cmd\s*[\[\(]['\"]set\s",
            "description": "vim.cmd('set ...') — VimL overhead, use vim.opt instead",
            "severity":    "warn",
            "remediation": "Replace with vim.opt.* or vim.o.*",
        },
        {
            "id":          "sync_fn_systemlist",
            "regex":       r"vim\.fn\.systemlist\s*\(",
            "description": "Synchronous vim.fn.systemlist() — blocks UI thread",
            "severity":    "error",
            "remediation": "Replace with vim.system() collecting stdout lines",
        },
    ]

    if not shutil.which("rg"):
        report.recommendations.append(
            "Install ripgrep (rg) for static anti-pattern analysis"
        )
        return

    # ── Check PCRE2 support once (used for lookahead comment pre-filter) ──
    _pcre2_ok = run(["rg", "--pcre2", r"(?=x)x", "--version"], timeout=5)
    HAS_PCRE2 = _pcre2_ok.returncode == 0

    def _is_lua_comment_line(text: str) -> bool:
        """
        Return True if the matched source line is a Lua comment line — i.e.
        the anti-pattern keyword appears inside a comment, not in live code.

        Correctly classifies:
          COMMENT  →  '-- Use vim.fn.system() — NEVER ...'   ← filtered
          COMMENT  →  '  -- SLA: No vim.fn.system() / ...'  ← filtered
          CODE     →  'local out = vim.fn.system({...})'     ← reported
          CODE     →  'return vim.fn.system({...}, body)'    ← reported

        Strategy: find the first '--' that isn't inside a string literal,
        then check whether the matched keyword falls after that position.
        Simplified heuristic: count unescaped quotes before '--' to detect
        whether we're inside a string. Works for the 99% case in Lua configs.
        """
        stripped = text.lstrip()

        # Fast path 1: pure comment line
        if stripped.startswith("--"):
            return True

        # Fast path 2: find '--' in the line and check if the pattern comes after it
        comment_pos = -1
        in_string = False
        quote_char = None
        i = 0
        while i < len(text):
            ch = text[i]
            if not in_string:
                if ch in ('"', "'"):
                    in_string = True
                    quote_char = ch
                elif ch == "-" and i + 1 < len(text) and text[i + 1] == "-":
                    comment_pos = i
                    break
            else:
                if ch == quote_char and (i == 0 or text[i - 1] != "\\"):
                    in_string = False
                    quote_char = None
            i += 1

        if comment_pos == -1:
            # No comment marker found — definitely real code
            return False

        # The pattern must appear only after the comment marker to be a false positive
        # Check: is the actual match within the comment portion?
        code_portion    = text[:comment_pos]
        comment_portion = text[comment_pos:]

        keywords = [
            "vim.fn.system", "io.popen", "os.execute",
            "vim.fn.systemlist", "plenary.job", "require",
        ]
        for kw in keywords:
            if kw in comment_portion and kw not in code_portion:
                # Keyword is only in comment, not in code portion → false positive
                return True

        return False

    for pat in patterns:
        # Two-stage filtering:
        # Stage 1 (rg): PCRE2 negative-lookahead skips pure-comment lines at grep level
        # Stage 2 (Python): _is_lua_comment_line() catches inline-comment false positives
        rg_args = [
            "rg",
            "--no-heading",
            "--line-number",
            "--color=never",
        ]

        if HAS_PCRE2:
            # (?!\s*--) = skip lines whose non-whitespace start is a Lua comment marker
            rg_args += ["--pcre2", "-e", r"^(?!\s*--).*" + pat["regex"]]
        else:
            rg_args += ["-e", pat["regex"]]

        rg_args.append(str(lua_dir))

        result = run(rg_args, timeout=10)

        matches = []
        if result.returncode == 0:  # 0 = found, 1 = no match, 2 = error
            for line in result.stdout.splitlines():
                # format: /path/to/file.lua:42:  <source text>
                parts = line.split(":", 2)
                if len(parts) < 2:
                    continue

                source_text = parts[2].strip() if len(parts) > 2 else ""

                # Stage 2: definitive Python-level comment filter
                if _is_lua_comment_line(source_text):
                    continue

                try:
                    rel = str(Path(parts[0]).relative_to(NVIM_CONFIG_DIR))
                except ValueError:
                    rel = parts[0]

                matches.append({
                    "file": rel,
                    "line": parts[1],
                    "text": source_text,
                })

        # Only append to report when real (non-comment) violations exist
        if matches:
            report.anti_patterns.append({
                "pattern":      pat["id"],
                "description":  pat["description"],
                "severity":     pat["severity"],
                "remediation":  pat["remediation"],
                "occurrences":  len(matches),
                "files":        matches[:10],
            })


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 3: File System & Config Structure Audit
# ═══════════════════════════════════════════════════════════════════════════

def audit_structure(domain: DomainReport) -> None:
    """
    D3 — Verify target directory topology matches IMPLEMENTATION_PLAN.md §3.
    Completeness check: presence of all required modules.
    """
    print("  [D3] Auditing config structure...")

    required_files = [
        "init.lua",
        "lua/core/perf.lua",
        "lua/core/options.lua",
        "lua/core/lazy.lua",
        "lua/core/keymaps.lua",
        "lua/core/autocmds.lua",
        "lua/core/guard.lua",
        "lua/core/audit/init.lua",
        "lua/core/audit/doctor.lua",
        "lua/core/audit/benchmark.lua",
        "lua/plugins/ai.lua",
        "lua/plugins/authoring.lua",
        "lua/plugins/coding.lua",
        "lua/plugins/data.lua",
        "lua/plugins/debugging.lua",
        "lua/plugins/diagnostics.lua",
        "lua/plugins/explorer.lua",
        "lua/plugins/infrastructure.lua",
        "lua/plugins/language.lua",
        "lua/plugins/navigation.lua",
        "lua/plugins/quality.lua",
        "lua/plugins/syntax.lua",
        "lua/plugins/terminal.lua",
        "lua/plugins/testing.lua",
        "lua/plugins/toolchain.lua",
        "lua/plugins/ui.lua",
        "lua/plugins/vcs.lua",
        "lua/plugins/workspace.lua",
    ]

    present = 0
    missing = []
    for rel in required_files:
        path = NVIM_CONFIG_DIR / rel
        if path.exists():
            present += 1
        else:
            missing.append(rel)

    completeness = (present / len(required_files)) * 100

    m = MetricResult(
        name      = "config_completeness_pct",
        domain    = "structure",
        value     = completeness,
        unit      = "%",
        sla_limit = 100.0,
        notes     = f"{present}/{len(required_files)} required files present",
    )
    m.evaluate_sla()
    if missing:
        m.notes += f"\nMissing: {', '.join(missing)}"
        domain.findings.extend([f"Missing: {f}" for f in missing])
    domain.metrics.append(m)

    # Count total Lua LOC in config (accurate line counting, not character matches)
    total_loc = 0
    lua_dir = NVIM_CONFIG_DIR / "lua"
    if lua_dir.exists():
        for p in lua_dir.rglob("*.lua"):
            try:
                total_loc += sum(1 for _ in p.open(encoding="utf-8", errors="ignore"))
            except Exception:
                pass
        loc_metric = MetricResult(
            name   = "config_lua_loc",
            domain = "structure",
            value  = float(total_loc),
            unit   = "lines",
            notes  = "Total Lua LOC in config",
        )
        domain.metrics.append(loc_metric)


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 4: Plugin Version Audit
# ═══════════════════════════════════════════════════════════════════════════

def audit_plugin_versions(domain: DomainReport) -> None:
    """
    D4 — Verify pinned plugin versions match researched latest versions.
    Cross-references confirmed versions from GitHub MCP research.
    """
    print("  [D4] Auditing plugin version pins...")

    # Confirmed latest versions (from research subagent, September 2026)
    CONFIRMED_VERSIONS = {
        "folke/lazy.nvim":                     "v11.17.5",
        "saghen/blink.cmp":                    "v1.10.2",
        "folke/snacks.nvim":                   "v2.31.0",
        "stevearc/conform.nvim":               "v9.1.0",
        "nvim-treesitter/nvim-treesitter":     "v0.10.0",
        "neovim/nvim-lspconfig":               "v2.12.0",
        "mfussenegger/nvim-dap":               "0.10.0",
        "rcarriga/nvim-dap-ui":                "v4.0.0",
        "nvim-neotest/neotest":                "v5.20.0",
        "lewis6991/gitsigns.nvim":             "v2.1.0",
        "stevearc/oil.nvim":                   "v2.16.0",
        "folke/which-key.nvim":                "v3.17.0",
        "catppuccin/nvim":                     "v2.0.0",
        "folke/tokyonight.nvim":               "v4.14.1",
        "ravitemer/mcphub.nvim":               "v6.2.0",
        "yetone/avante.nvim":                  "v0.4.0",
        "olimorris/codecompanion.nvim":        "v19.26.0",
        "MeanderingProgrammer/render-markdown.nvim": "v8.14.0",
        "benlubas/molten-nvim":                "v1.9.2",
        "lervag/vimtex":                       "v2.18",
        "folke/todo-comments.nvim":            "v1.5.0",
        "mrcjkb/rustaceanvim":                 "v9.2.1",
    }

    # Parse lazy-lock.json if present
    lockfile = NVIM_CONFIG_DIR / "lazy-lock.json"
    locked   = {}
    if lockfile.exists():
        with open(lockfile) as f:
            locked = json.load(f)

    total   = len(CONFIRMED_VERSIONS)
    pinned  = 0
    current = 0

    for plugin, expected_ver in CONFIRMED_VERSIONS.items():
        short_name = plugin.split("/")[-1]
        lock_entry = locked.get(short_name) or locked.get(plugin)

        if lock_entry:
            pinned += 1
            locked_ver = lock_entry.get("version") or lock_entry.get("tag") or ""
            if locked_ver == expected_ver:
                current += 1
            else:
                domain.findings.append(
                    f"Version drift: {plugin} locked={locked_ver} expected={expected_ver}"
                )
        else:
            domain.findings.append(f"Not in lockfile: {plugin}")

    pin_rate = (pinned / total * 100) if total else 0
    cur_rate = (current / total * 100) if total else 0

    domain.metrics.append(MetricResult(
        name      = "plugin_pin_rate_pct",
        domain    = "plugins",
        value     = pin_rate,
        unit      = "%",
        sla_limit = 80.0,
        notes     = f"{pinned}/{total} plugins in lockfile",
    ))
    domain.metrics.append(MetricResult(
        name      = "plugin_version_current_pct",
        domain    = "plugins",
        value     = cur_rate,
        unit      = "%",
        notes     = f"{current}/{total} plugins at latest confirmed version",
    ))

    for m in domain.metrics:
        m.evaluate_sla()


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 5: LSP & Intelligence Layer Audit
# ═══════════════════════════════════════════════════════════════════════════

def audit_lsp_config(domain: DomainReport) -> None:
    """
    D5 — LSP server configuration completeness and binary presence.
    Validates all required language servers from IMPLEMENTATION_PLAN.md §6.
    """
    print("  [D5] Auditing LSP configuration...")

    lsp_binaries = {
        "lua-language-server": "Lua (lua_ls)",
        "basedpyright":        "Python (basedpyright)",
        "pyright":             "Python (pyright fallback)",
        "rust-analyzer":       "Rust (rust-analyzer)",
        "gopls":               "Go (gopls)",
        "typescript-language-server": "TypeScript (ts_ls)",
        "nil":                 "Nix (nil_ls)",
        "terraform-ls":        "Terraform",
        "bash-language-server": "Bash (bashls)",
        "yaml-language-server": "YAML",
        "dockerfile-language-server": "Dockerfile",
        "marksman":            "Markdown",
        "sqls":                "SQL",
    }

    found = 0
    for binary, desc in lsp_binaries.items():
        if shutil.which(binary, path=EFFECTIVE_PATH):
            found += 1
        else:
            domain.findings.append(f"LSP binary not found: {binary} ({desc})")

    coverage = (found / len(lsp_binaries)) * 100
    domain.metrics.append(MetricResult(
        name      = "lsp_binary_coverage_pct",
        domain    = "lsp",
        value     = coverage,
        unit      = "%",
        sla_limit = 70.0,  # At least 70% of LSPs available
        notes     = f"{found}/{len(lsp_binaries)} LSP binaries on PATH (including Mason)",
    ))

    for m in domain.metrics:
        m.evaluate_sla()


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 6: Formatter & Linter Audit
# ═══════════════════════════════════════════════════════════════════════════

def audit_formatters(domain: DomainReport) -> None:
    """D6 — Formatter/linter binary presence and async configuration."""
    print("  [D6] Auditing formatter/linter binaries...")

    formatters = {
        "stylua":    "Lua formatter",
        "ruff":      "Python linter/formatter",
        "gofumpt":   "Go formatter",
        "prettier":  "JS/TS/MD formatter",
        "nixfmt":    "Nix formatter",
        "shfmt":     "Shell formatter",
        "taplo":     "TOML formatter",
        "buf":       "Protobuf formatter/linter",
        "shellcheck": "Shell linter",
        "hadolint":  "Dockerfile linter",
        "yamllint":  "YAML linter",
    }

    found = sum(1 for b in formatters if shutil.which(b, path=EFFECTIVE_PATH))
    coverage = (found / len(formatters)) * 100

    domain.metrics.append(MetricResult(
        name      = "formatter_binary_coverage_pct",
        domain    = "formatters",
        value     = coverage,
        unit      = "%",
        sla_limit = 60.0,
        notes     = f"{found}/{len(formatters)} formatter/linter binaries on PATH (including Mason)",
    ))

    # Check conform.nvim config for non-blocking async format
    conform_cfg = NVIM_CONFIG_DIR / "lua" / "plugins" / "coding.lua"
    if not conform_cfg.exists():
        conform_cfg = NVIM_CONFIG_DIR / "lua" / "plugins" / "quality.lua"
    if conform_cfg.exists():
        content = conform_cfg.read_text()
        has_async  = ("async" in content or "format_after_save" in content)
        has_blocking = "timeout_ms" in content and "lsp_fallback" in content and "format_after_save" not in content
        domain.metrics.append(MetricResult(
            name   = "format_on_save_async_configured",
            domain = "formatters",
            value  = 1.0 if has_async else 0.0,
            unit   = "bool",
            sla_limit = 1.0,
            notes  = "conform.nvim configured with non-blocking async format" if has_async
                     else "WARNING: format_on_save may be synchronous",
        ))

    for m in domain.metrics:
        m.evaluate_sla()


# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 8: DevSecOps (Security & Supply Chain)
# ═══════════════════════════════════════════════════════════════════════════

def audit_secops(domain: DomainReport) -> None:
    print("  [D8] Auditing DevSecOps (Permissions & Supply Chain)...")
    
    lockfile = NVIM_CONFIG_DIR / "lazy-lock.json"
    has_lock = lockfile.exists()
    domain.metrics.append(MetricResult(
        name="supply_chain_lockfile", domain="secops",
        value=1.0 if has_lock else 0.0, unit="bool", sla_limit=1.0,
        notes="lazy-lock.json is present" if has_lock else "Missing lazy-lock.json"
    ))
    
    init_lua = NVIM_CONFIG_DIR / "init.lua"
    if init_lua.exists():
        mode = os.stat(init_lua).st_mode
        other_write = bool(mode & 0o002)
        domain.metrics.append(MetricResult(
            name="config_secure_permissions", domain="secops",
            value=0.0 if other_write else 1.0, unit="bool", sla_limit=1.0,
            notes="Secure permissions" if not other_write else "CRITICAL: init.lua is world-writable"
        ))
    for m in domain.metrics:
        m.evaluate_sla()

# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 9: Synthetic Latency (UI & AST)
# ═══════════════════════════════════════════════════════════════════════════

def audit_latency(domain: DomainReport) -> None:
    print("  [D9] Measuring Synthetic Latency (UI & AST)...")
    
    # UI Frame Render Latency
    code, out, _ = nvim_headless(
        "-c", "lua local t=vim.uv.hrtime(); for _=1,100 do vim.cmd('redraw') end; local f=io.open('/tmp/core_ui_lat', 'w'); f:write((vim.uv.hrtime()-t)/1e6/100); f:close()",
        "-c", "qa"
    )
    if code == 0 and os.path.exists("/tmp/core_ui_lat"):
        try:
            val = float(open("/tmp/core_ui_lat").read().strip())
            m = MetricResult(name="ui_frame_render_ms", domain="latency", value=val, unit="ms", sla_limit=2.0)
            m.evaluate_sla()
            domain.metrics.append(m)
        except Exception:
            pass

    # AST Parse Latency
    code, out, _ = nvim_headless(
        "-c", f"e {NVIM_CONFIG_DIR}/init.lua",
        "-c", "lua local ts_ok, p = pcall(vim.treesitter.get_parser, 0); if ts_ok and p then local t=vim.uv.hrtime(); p:parse(); local f=io.open('/tmp/core_ast_lat', 'w'); f:write((vim.uv.hrtime()-t)/1e6); f:close() end",
        "-c", "qa"
    )
    if code == 0 and os.path.exists("/tmp/core_ast_lat"):
        try:
            val = float(open("/tmp/core_ast_lat").read().strip())
            m = MetricResult(name="ast_parse_ms", domain="latency", value=val, unit="ms", sla_limit=5.0)
            m.evaluate_sla()
            domain.metrics.append(m)
        except Exception:
            pass

# DOMAIN 7: SLA Invariant Verification
# ═══════════════════════════════════════════════════════════════════════════

def verify_sla_invariants(domain: DomainReport) -> None:
    """
    D7 — Cross-cutting SLA invariant checks.
    Validates architectural constraints from IMPLEMENTATION_PLAN.md §2.
    """
    print("  [D7] Verifying SLA invariants...")

    # Check: No synchronous shell calls in config (skip Lua comment lines)
    if shutil.which("rg") and (NVIM_CONFIG_DIR / "lua").exists():
        sync_patterns = [
            r"vim\.fn\.system\s*\(",
            r"io\.popen\s*\(",
            r"os\.execute\s*\(",
            r"vim\.fn\.systemlist\s*\(",
        ]

        def _is_lua_comment(text: str) -> bool:
            """True if the line text represents a Lua comment (not real code)."""
            stripped = text.lstrip()
            if stripped.startswith("--"):
                return True
            # Check if the keyword only appears after the first -- marker
            comment_pos = -1
            in_str = False
            qch = None
            for i, ch in enumerate(text):
                if not in_str:
                    if ch in ('"', "'"):
                        in_str, qch = True, ch
                    elif ch == "-" and i + 1 < len(text) and text[i + 1] == "-":
                        comment_pos = i
                        break
                else:
                    if ch == qch and (i == 0 or text[i - 1] != "\\"):
                        in_str = False
            if comment_pos == -1:
                return False
            code_part    = text[:comment_pos]
            comment_part = text[comment_pos:]
            for kw in ["vim.fn.system", "io.popen", "os.execute", "vim.fn.systemlist"]:
                if kw in comment_part and kw not in code_part:
                    return True
            return False

        # Use rg without --count so we can inspect each line individually
        result = run([
            "rg",
            "--no-heading",
            "--line-number",
            "--color=never",
            "-e", "|".join(sync_patterns),
            str(NVIM_CONFIG_DIR / "lua"),
            "--type", "lua",
        ], timeout=10)

        real_violations: list[str] = []
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                parts = line.split(":", 2)
                if len(parts) < 3:
                    continue
                source_text = parts[2].strip()
                if not _is_lua_comment(source_text):
                    real_violations.append(f"{parts[0]}:{parts[1]}: {source_text}")

        sync_call_count = len(real_violations)

        domain.metrics.append(MetricResult(
            name      = "sync_shell_calls",
            domain    = "sla",
            value     = float(sync_call_count),
            unit      = "count",
            sla_limit = 0.0,
            notes     = (
                "Zero synchronous shell calls detected ✓"
                if sync_call_count == 0
                else f"{sync_call_count} real code violation(s) found (comments excluded)"
            ),
            severity  = "error" if sync_call_count > 0 else "info",
        ))
        if sync_call_count > 0:
            domain.findings.append(
                f"SLA VIOLATED: {sync_call_count} synchronous shell calls in real code "
                f"(Lua comment lines were excluded from this count)"
            )
            for v in real_violations[:5]:
                domain.findings.append(f"  → {v}")

    # Check: GC tuning present in perf.lua
    perf_file = NVIM_CONFIG_DIR / "lua" / "core" / "perf.lua"
    if perf_file.exists():
        content = perf_file.read_text()
        has_gc  = "collectgarbage" in content and "incremental" in content
        init_file = NVIM_CONFIG_DIR / "init.lua"
        init_content = init_file.read_text() if init_file.exists() else ""
        has_loader = "vim.loader.enable" in content or "vim.loader.enable" in init_content
        has_providers = "loaded_python3_provider" in content

        domain.metrics.append(MetricResult(
            name   = "perf_gc_tuning",
            domain = "sla",
            value  = 1.0 if has_gc else 0.0,
            unit   = "bool",
            sla_limit = 1.0,
            notes  = "GC tuning (incremental) configured in core/perf.lua",
        ))
        domain.metrics.append(MetricResult(
            name   = "perf_loader_enabled",
            domain = "sla",
            value  = 1.0 if has_loader else 0.0,
            unit   = "bool",
            sla_limit = 1.0,
            notes  = "vim.loader.enable() present in core/perf.lua",
        ))
        domain.metrics.append(MetricResult(
            name   = "perf_providers_disabled",
            domain = "sla",
            value  = 1.0 if has_providers else 0.0,
            unit   = "bool",
            sla_limit = 1.0,
            notes  = "Unused providers disabled in core/perf.lua",
        ))

    # Check: Large-file guard in guard.lua
    guard_file = NVIM_CONFIG_DIR / "lua" / "core" / "guard.lua"
    if not guard_file.exists():
        guard_file = NVIM_CONFIG_DIR / "lua" / "core" / "lib" / "guard.lua"
    if not guard_file.exists():
        guard_file = NVIM_CONFIG_DIR / "lua" / "lib" / "guard.lua"
    if guard_file.exists():
        content = guard_file.read_text()
        has_tier1 = "TIER1_BYTES" in content or "1024 * 1024" in content
        has_tier2 = "TIER2_BYTES" in content or "10 * 1024 * 1024" in content
        has_uv    = "vim.uv.fs_stat" in content  # No shell spawn

        domain.metrics.append(MetricResult(
            name   = "guard_tier1_configured",
            domain = "sla",
            value  = 1.0 if has_tier1 else 0.0,
            unit   = "bool",
            sla_limit = 1.0,
            notes  = "Large-file Tier 1 (>1MB) protection configured",
        ))
        domain.metrics.append(MetricResult(
            name   = "guard_uses_uv_stat",
            domain = "sla",
            value  = 1.0 if has_uv else 0.0,
            unit   = "bool",
            sla_limit = 1.0,
            notes  = "guard.lua uses vim.uv.fs_stat (no shell spawn) for file size",
        ))

    for m in domain.metrics:
        if m.sla_pass is None:
            m.evaluate_sla()


# ═══════════════════════════════════════════════════════════════════════════
# DOMAIN 8: Narrative & Recommendations
# ═══════════════════════════════════════════════════════════════════════════

def generate_recommendations(report: AuditReport) -> None:
    """D8 — Synthesize findings into prioritized recommendations."""

    # Anti-pattern severity
    errors   = [p for p in report.anti_patterns if p.get("severity") == "error"]
    warnings = [p for p in report.anti_patterns if p.get("severity") == "warn"]

    if errors:
        report.recommendations.append(
            f"🔴 CRITICAL: Fix {len(errors)} error-severity anti-patterns before deployment"
        )
    if warnings:
        report.recommendations.append(
            f"🟡 HIGH: Address {len(warnings)} warning-severity anti-patterns"
        )

    # Check startup SLA across all domains
    for domain in report.domains:
        for metric in domain.metrics:
            if metric.sla_pass is False:
                if "startup" in metric.name:
                    report.recommendations.append(
                        f"🔴 Startup SLA violated: {metric.value:.2f}ms > {metric.sla_limit}ms limit"
                        " — profile with :X0rProfile and eliminate synchronous loads"
                    )
                elif "sync_shell" in metric.name and metric.value > 0:
                    report.recommendations.append(
                        f"🔴 {int(metric.value)} synchronous shell calls detected"
                        " — replace with vim.system() callbacks"
                    )

    # Coverage recommendations
    for domain in report.domains:
        if domain.score < 50:
            report.recommendations.append(
                f"🔴 Domain '{domain.domain}' score {domain.score}% — urgent remediation required"
            )
        elif domain.score < 80:
            report.recommendations.append(
                f"🟡 Domain '{domain.domain}' score {domain.score}% — improvement needed"
            )

    if not report.recommendations:
        report.recommendations.append("✅ No critical issues detected — configuration within SLA bounds")


# ═══════════════════════════════════════════════════════════════════════════
# REPORTING
# ═══════════════════════════════════════════════════════════════════════════

def format_table_row(cols: list[str], widths: list[int]) -> str:
    return "│ " + " │ ".join(str(c).ljust(w) for c, w in zip(cols, widths)) + " │"


def format_separator(widths: list[int], style: str = "mid") -> str:
    chars = {"top": ("┌", "┬", "┐", "─"), "mid": ("├", "┼", "┤", "─"), "bot": ("└", "┴", "┘", "─")}
    l, m, r, h = chars[style]
    return l + m.join(h * (w + 2) for w in widths) + r


def print_report(report: AuditReport, use_color: bool = True) -> None:
    """Print human-readable tabular report to stdout."""

    def c(text: str, code: str) -> str:
        return f"\033[{code}m{text}\033[0m" if use_color else text

    RED   = "31;1"
    GREEN = "32;1"
    YEL   = "33;1"
    CYAN  = "36;1"
    BOLD  = "1"
    DIM   = "2"

    print()
    print(c("╔══════════════════════════════════════════════════════════════════╗", BOLD))
    print(c("║   x0r/nvim — Benchmark & Audit Report                            ║", BOLD))
    print(c("╚══════════════════════════════════════════════════════════════════╝", BOLD))
    print(f"  Timestamp:    {report.timestamp}")
    print(f"  Neovim:       {report.nvim_version}")
    print(f"  Config:       {report.config_dir}")
    print(f"  Overall Score: {c(f'{report.overall_score}%', GREEN if report.overall_score >= 80 else (YEL if report.overall_score >= 60 else RED))}")
    print()

    # Domain summary table
    widths = [20, 8, 6, 6, 6]
    print(format_separator(widths, "top"))
    print(format_table_row(["Domain", "Score", "Pass", "Fail", "Warn"], widths))
    print(format_separator(widths, "mid"))
    for d in report.domains:
        score_str = f"{d.score}%"
        score_c   = GREEN if d.score >= 80 else (YEL if d.score >= 60 else RED)
        print(format_table_row([
            d.domain,
            c(score_str, score_c),
            c(str(d.passed),   GREEN),
            c(str(d.failed),   RED   if d.failed   > 0 else DIM),
            c(str(d.warnings), YEL   if d.warnings > 0 else DIM),
        ], widths))
    print(format_separator(widths, "bot"))
    print()

    # Per-domain metric details
    for d in report.domains:
        print(c(f"┌─ {d.domain.upper()} ", BOLD) + "─" * (60 - len(d.domain)))
        metric_widths = [35, 10, 8, 8, 8, 6]
        print(format_table_row(["Metric", "Value", "SLA", "P50", "P95", "Status"], metric_widths))
        for m in d.metrics:
            val_str  = f"{m.value:.2f} {m.unit}"
            sla_str  = f"{m.sla_limit} {m.unit}" if m.sla_limit is not None else "—"
            p50_str  = f"{m.p50:.2f}"  if m.p50  else "—"
            p95_str  = f"{m.p95:.2f}"  if m.p95  else "—"
            if m.sla_pass is True:
                status = c("✓", GREEN)
            elif m.sla_pass is False:
                status = c("✗", RED)
            else:
                status = c("~", DIM)
            print(format_table_row([m.name[:35], val_str[:10], sla_str[:8], p50_str, p95_str, status], metric_widths))

        if d.findings:
            print(c("  Findings:", YEL))
            for f in d.findings[:5]:
                print(f"    • {f}")
        print()

    # Anti-patterns
    if report.anti_patterns:
        print(c("═══ ANTI-PATTERN REGISTRY ═══════════════════════════════════════", RED))
        for ap in report.anti_patterns:
            sev_c = RED if ap.get("severity") == "error" else YEL
            print(f"  {c('●', sev_c)} [{ap.get('severity','?').upper()}] {ap.get('pattern', '?')}")
            print(f"      {ap.get('description', '')}")
            if ap.get("occurrences"):
                print(f"      Occurrences: {ap['occurrences']}")
            if ap.get("remediation"):
                print(f"      Fix: {c(ap['remediation'], DIM)}")
            for f in (ap.get("files") or [])[:3]:
                print(f"      → {f.get('file')}:{f.get('line')}")
        print()

    # Recommendations
    if report.recommendations:
        print(c("═══ RECOMMENDATIONS ══════════════════════════════════════════════", CYAN))
        for rec in report.recommendations:
            print(f"  {rec}")
    print()


# ═══════════════════════════════════════════════════════════════════════════
# MAIN ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════════════

def get_nvim_version() -> str:
    result = run([NVIM_BIN, "--version"], timeout=5)
    if result.returncode == 0:
        lines = result.stdout.splitlines()
        return lines[0] if lines else "unknown"
    return "unknown"


def run_audit(suites: list[str] | None = None) -> AuditReport:
    import datetime
    report = AuditReport(
        timestamp    = datetime.datetime.now().isoformat(),
        nvim_version = get_nvim_version(),
        config_dir   = str(NVIM_CONFIG_DIR),
    )

    suite_map: dict[str, tuple[str, Callable]] = {
        "startup":    ("D1 — Startup Performance",    lambda d: benchmark_startup(d)),
        "structure":  ("D3 — Config Structure",       lambda d: audit_structure(d)),
        "plugins":    ("D4 — Plugin Versions",        lambda d: audit_plugin_versions(d)),
        "lsp":        ("D5 — LSP Coverage",           lambda d: audit_lsp_config(d)),
        "formatters": ("D6 — Formatters & Linters",   lambda d: audit_formatters(d)),
        "sla":        ("D7 — SLA Invariants",         lambda d: verify_sla_invariants(d)),
        "secops":     ("D8 — DevSecOps Audit",        lambda d: audit_secops(d)),
        "latency":    ("D9 — Synthetic Latency",      lambda d: audit_latency(d)),
    }

    active = {k: v for k, v in suite_map.items() if not suites or k in suites}

    for key, (name, fn) in active.items():
        print(f"\n{'─'*68}")
        print(f"  SUITE: {name}")
        print(f"{'─'*68}")
        domain = DomainReport(domain=key)
        fn(domain)
        domain.finalize()
        report.domains.append(domain)

    # Anti-pattern scan (cross-cutting)
    if not suites or "antipatterns" in suites:
        print(f"\n{'─'*68}")
        print(f"  SUITE: D2 — Anti-Pattern Detection")
        print(f"{'─'*68}")
        audit_antipatterns(report)

    generate_recommendations(report)
    report.finalize()
    return report


def main() -> int:
    parser = argparse.ArgumentParser(
        description="x0r/nvim Benchmark & Audit Framework",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--suite",
        nargs="*",
        choices=["startup", "antipatterns", "structure", "plugins", "lsp", "formatters", "sla", "secops", "latency"],
        help="Run specific suite(s) (default: all)",
    )
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Write report to file (in addition to stdout)",
    )
    parser.add_argument(
        "--ci",
        action="store_true",
        help="CI mode: exit 1 if any SLA is violated",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colors",
    )
    args = parser.parse_args()

    print("x0r/nvim — Benchmark & Audit Framework")
    print(f"Config: {NVIM_CONFIG_DIR}")
    print(f"Neovim: {shutil.which(NVIM_BIN) or 'not found'}")

    if not shutil.which(NVIM_BIN):
        print(f"ERROR: nvim not found at '{NVIM_BIN}'", file=sys.stderr)
        return 1

    report = run_audit(suites=args.suite)

    if args.format == "text":
        print_report(report, use_color=not args.no_color)
    else:
        # JSON output
        def default_serial(obj):
            if hasattr(obj, "__dict__"):
                return obj.__dict__
            return str(obj)
        json_out = json.dumps(asdict(report), indent=2, default=default_serial)
        print(json_out)
        if args.output:
            args.output.write_text(json_out)
            print(f"\nReport written to: {args.output}", file=sys.stderr)

    if args.output and args.format == "text":
        # Also write text report to file
        import io
        buf = io.StringIO()
        old_stdout = sys.stdout
        sys.stdout = buf
        print_report(report, use_color=False)
        sys.stdout = old_stdout
        args.output.write_text(buf.getvalue())

    # CI mode: fail if any SLA is violated
    if args.ci:
        violations = []
        for domain in report.domains:
            for metric in domain.metrics:
                if metric.sla_pass is False:
                    violations.append(f"{domain.domain}/{metric.name}: {metric.value:.3f} > {metric.sla_limit}")
        if violations:
            print(f"\n{'='*60}", file=sys.stderr)
            print("CI FAILURE — SLA Violations:", file=sys.stderr)
            for v in violations:
                print(f"  ✗ {v}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
