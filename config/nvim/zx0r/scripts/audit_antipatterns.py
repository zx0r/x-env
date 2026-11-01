#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║   x0r/nvim — Canonical Anti-Pattern & Bottleneck Forensic Scanner            ║
║   Derived from: research/*.md (2026-09-30 through 2026-10-11)                ║
║   Architecture: Capability-Oriented Domain Architecture (CODA / DDD)         ║
╚══════════════════════════════════════════════════════════════════════════════╝

Exhaustively audits the Neovim configuration against all 20 empirically proven
anti-patterns cataloged across the historical research corpus:
  - STARTUP_BASELINE_AUDIT.md
  - PERFORMANCE_AUDIT_2026-10-01.md
  - SYSTEM_ARCHITECTURE_AUDIT.md
  - BUFFER_OPEN_LATENCY_RESEARCH.md
  - DEEP_RESEARCH_NVIM_2026.md
  - AUDIT_PLAN.md & PRINCIPAL_AUDIT_PLAN_2026-10-11.md

Usage:
  python3 zx0r/scripts/audit_antipatterns.py
  python3 zx0r/scripts/audit_antipatterns.py --verbose
  python3 zx0r/scripts/audit_antipatterns.py --json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import List, Optional

# ── Resolution of Repository Paths ───────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_ROOT = SCRIPT_DIR.parent
LUA_DIR = CONFIG_ROOT / "lua"
CORE_DIR = LUA_DIR / "core"
PLUGINS_DIR = LUA_DIR / "plugins"
LSP_DIR = CONFIG_ROOT / "lsp"
INIT_LUA = CONFIG_ROOT / "init.lua"

@dataclass
class Finding:
    code: str
    severity: str  # CRITICAL, HIGH, MEDIUM, LOW
    title: str
    file: str
    line: int
    snippet: str
    impact: str
    remediation: str

@dataclass
class AuditSummary:
    total_checks: int = 0
    passed_checks: int = 0
    failed_checks: int = 0
    critical_count: int = 0
    high_count: int = 0
    medium_count: int = 0
    low_count: int = 0
    findings: List[Finding] = field(default_factory=list)

class AntiPatternAuditor:
    def __init__(self, root: Path, verbose: bool = False):
        self.root = root
        self.verbose = verbose
        self.summary = AuditSummary()

    def add_finding(self, finding: Finding):
        self.summary.findings.append(finding)
        self.summary.failed_checks += 1
        if finding.severity == "CRITICAL":
            self.summary.critical_count += 1
        elif finding.severity == "HIGH":
            self.summary.high_count += 1
        elif finding.severity == "MEDIUM":
            self.summary.medium_count += 1
        else:
            self.summary.low_count += 1

    def record_pass(self):
        self.summary.passed_checks += 1

    def audit_all(self):
        print(f"\nScanning {self.root} against research/ anti-pattern catalog...")

        # ── Group 1: Core Boot & Ring 0 Invariants ───────────────────────────
        self.check_ap01_loader_position()
        self.check_ap02_builtin_suppression()
        self.check_ap03_sync_shell_io()
        self.check_ap04_idle_polling_timers()
        self.check_ap05_global_pollution()
        self.check_ap06_headless_theme_rendering()
        self.check_ap07_syntax_reset_double_render()

        # ── Group 2: Lazy.nvim & Spec Optimization ───────────────────────────
        self.check_ap08_lazy_missing_flag()
        self.check_ap09_eager_lazy_flags()
        self.check_ap10_init_hook_leaks()
        self.check_ap11_eager_dependencies()
        self.check_ap12_module_scope_execution()
        self.check_ap13_snacks_satellite_hooks()

        # ── Group 3: Buffer Attachment & LSP Engine ──────────────────────────
        self.check_ap14_blink_capability_trap()
        self.check_ap15_schemastore_top_level_require()
        self.check_ap16_sync_executable_scan()
        self.check_ap17_blocking_format_on_save()
        self.check_ap18_filetype_sourcing_leak()
        self.check_ap19_buffer_attach_transitive_pulls()
        self.check_ap20_large_file_guard_integrity()

        self.summary.total_checks = self.summary.passed_checks + self.summary.failed_checks

    # ── Check AP-01: vim.loader.enable() Position ─────────────────────────────
    def check_ap01_loader_position(self):
        if not INIT_LUA.exists():
            return
        lines = INIT_LUA.read_text(encoding="utf-8").splitlines()
        found_loader = False
        non_comment_idx = 0
        for idx, line in enumerate(lines, 1):
            stripped = line.strip()
            if not stripped or stripped.startswith("--"):
                continue
            non_comment_idx += 1
            if "vim.loader.enable()" in stripped:
                found_loader = True
                if non_comment_idx == 1:
                    self.record_pass()
                else:
                    self.add_finding(Finding(
                        code="AP-01",
                        severity="HIGH",
                        title="vim.loader.enable() delayed behind user Lua instructions",
                        file=str(INIT_LUA.relative_to(CONFIG_ROOT.parent)),
                        line=idx,
                        snippet=line,
                        impact="+1.5–3.0ms cold start latency due to un-cached early module loading.",
                        remediation="Move vim.loader.enable() to absolute first non-comment instruction."
                    ))
                break
        if not found_loader:
            self.add_finding(Finding(
                code="AP-01",
                severity="CRITICAL",
                title="vim.loader.enable() missing from init.lua",
                file=str(INIT_LUA.relative_to(CONFIG_ROOT.parent)),
                line=1,
                snippet="<missing>",
                impact="Loss of LuaJIT bytecode caching; +15–20ms startup penalty.",
                remediation="Add vim.loader.enable() as the very first executable instruction in init.lua."
            ))

    # ── Check AP-02: Built-in Runtime Plugin Suppression ──────────────────────
    def check_ap02_builtin_suppression(self):
        perf_lua = CORE_DIR / "perf.lua"
        if not perf_lua.exists():
            return
        content = perf_lua.read_text(encoding="utf-8")
        essential_suppressions = [
            "loaded_python3_provider", "loaded_ruby_provider",
            "loaded_node_provider", "loaded_perl_provider"
        ]
        missing = [prov for prov in essential_suppressions if prov not in content]
        if missing:
            self.add_finding(Finding(
                code="AP-02",
                severity="HIGH",
                title=f"Remote providers not suppressed: {', '.join(missing)}",
                file=str(perf_lua.relative_to(CONFIG_ROOT.parent)),
                line=1,
                snippet="<missing>",
                impact="+5–15ms searching for non-existent python/node remote hosts.",
                remediation="Explicitly set vim.g[provider] = 0 in core/perf.lua."
            ))
        else:
            self.record_pass()

    # ── Check AP-03: Synchronous Shell I/O in Hot Paths ───────────────────────
    def check_ap03_sync_shell_io(self):
        patterns = [
            (r'vim\.fn\.system\s*\(', "vim.fn.system() synchronous shell call"),
            (r'vim\.fn\.systemlist\s*\(', "vim.fn.systemlist() synchronous shell call"),
            (r'io\.popen\s*\(', "io.popen() blocking pipe call"),
            (r'os\.execute\s*\(', "os.execute() blocking process spawn"),
        ]
        violations = []
        for lua_file in self.root.rglob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            # Exclude audit scripts or build hooks
            if "scripts" in rel or "build" in rel or "audit" in rel:
                continue
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("--"):
                    continue
                for pat, desc in patterns:
                    if re.search(pat, clean):
                        # Exempt lazy.nvim bootstrap wait (runs before UI)
                        if "is_bootstrap" in clean or "lazypath" in clean:
                            continue
                        violations.append((rel, idx, clean, desc))

        if violations:
            for rel, idx, clean, desc in violations:
                self.add_finding(Finding(
                    code="AP-03",
                    severity="CRITICAL",
                    title=f"Synchronous shell I/O detected: {desc}",
                    file=rel,
                    line=idx,
                    snippet=clean,
                    impact="Blocks Neovim single-threaded main loop; causes visible frame stutter.",
                    remediation="Replace with non-blocking vim.system({ ... }, { text = true }, callback) or vim.uv."
                ))
        else:
            self.record_pass()

    # ── Check AP-04: Libuv Idle Polling Timers ─────────────────────────────────
    def check_ap04_idle_polling_timers(self):
        timer_pat = r'vim\.uv\.new_timer\(\)\s*:\s*start\s*\(\s*\d+\s*,\s*([1-9]\d*)'
        violations = []
        for lua_file in self.root.rglob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            if "audit" in rel or "scripts" in rel:
                continue
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                if line.strip().startswith("--"):
                    continue
                if re.search(timer_pat, line):
                    violations.append((rel, idx, line.strip()))

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-04",
                    severity="CRITICAL",
                    title="Active repeating libuv timer detected",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Prevents event-loop idling, drains laptop battery, causes frame jitters.",
                    remediation="Replace timer polling with event-driven autocommands (BufWrite, LspProgress)."
                ))
        else:
            self.record_pass()

    # ── Check AP-05: Global `_G` Symbol Pollution ─────────────────────────────
    def check_ap05_global_pollution(self):
        g_assign_pat = r'_G\.([a-zA-Z0-9_]+)\s*='
        violations = []
        for lua_file in self.root.rglob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            if "audit" in rel or "scripts" in rel:
                continue
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                if line.strip().startswith("--"):
                    continue
                m = re.search(g_assign_pat, line)
                if m:
                    var = m.group(1)
                    # Allow recognized system bridges if strictly necessary
                    if var in {"Snacks"}:
                        continue
                    violations.append((rel, idx, line.strip(), var))

        if violations:
            for rel, idx, snippet, var in violations:
                self.add_finding(Finding(
                    code="AP-05",
                    severity="HIGH",
                    title=f"Global namespace leak: _G.{var}",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Breaks domain isolation; leaks mutable state across independent subsystems.",
                    remediation="Scope symbols inside local module tables (local M = {})."
                ))
        else:
            self.record_pass()

    # ── Check AP-06: Headless Theme / Colorscheme Rendering ───────────────────
    def check_ap06_headless_theme_rendering(self):
        if not INIT_LUA.exists():
            return
        content = INIT_LUA.read_text(encoding="utf-8")
        # Check if colorscheme is called unconditionally in Ring 0
        if "vim.cmd.colorscheme" in content:
            # Check if wrapped in #vim.api.nvim_list_uis() > 0
            if "nvim_list_uis" not in content:
                self.add_finding(Finding(
                    code="AP-06",
                    severity="MEDIUM",
                    title="Colorscheme loaded unconditionally during headless execution",
                    file=str(INIT_LUA.relative_to(CONFIG_ROOT.parent)),
                    line=1,
                    snippet="vim.cmd.colorscheme('x')",
                    impact="+1.5–2.5ms wasted compiling syntax highlight groups in headless benchmarks.",
                    remediation="Wrap theme/colorscheme activation in: if #vim.api.nvim_list_uis() > 0 then ... end"
                ))
                return
        self.record_pass()

    # ── Check AP-07: Legacy :syntax reset or Un-isolated ColorScheme ───────────
    def check_ap07_syntax_reset_double_render(self):
        violations = []
        for lua_file in self.root.rglob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            if "scripts" in rel:
                continue
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("--"):
                    continue
                if "syntax reset" in clean or "vim.cmd('syntax reset')" in clean:
                    violations.append((rel, idx, clean))

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-07",
                    severity="HIGH",
                    title="Legacy :syntax reset call detected",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="+5–8ms penalty reloading syncolor.vim defaults before custom theme.",
                    remediation="Remove :syntax reset; define colors purely via vim.api.nvim_set_hl()."
                ))
        else:
            self.record_pass()

    # ── Check AP-08: install.missing Flag in lazy.lua ─────────────────────────
    def check_ap08_lazy_missing_flag(self):
        lazy_lua = CORE_DIR / "lazy.lua"
        if not lazy_lua.exists():
            return
        content = lazy_lua.read_text(encoding="utf-8")
        if re.search(r'install\s*=\s*\{[^}]*missing\s*=\s*true', content, re.DOTALL):
            self.add_finding(Finding(
                code="AP-08",
                severity="HIGH",
                title="install.missing = true in lazy.nvim configuration",
                file=str(lazy_lua.relative_to(CONFIG_ROOT.parent)),
                line=64,
                snippet="missing = true,",
                impact="+8–10ms overhead loading lazy.view, lazy.manage, and lazy.health UI modules on startup.",
                remediation="Set install = { missing = false } for deterministic zero-overhead cold start."
            ))
        else:
            self.record_pass()

    # ── Check AP-09: Unwarranted lazy = false or priority = 1000 ──────────────
    def check_ap09_eager_lazy_flags(self):
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("--"):
                    continue
                if re.search(r'lazy\s*=\s*false', clean):
                    # Check if allowed UI core
                    if "folke/snacks.nvim" in clean or "ui.lua" in rel:
                        continue
                    violations.append((rel, idx, clean, "lazy = false"))
                if re.search(r'priority\s*=\s*1000', clean):
                    if "ui.lua" in rel or "folke/snacks.nvim" in clean:
                        continue
                    violations.append((rel, idx, clean, "priority = 1000"))

        if violations:
            for rel, idx, snippet, kind in violations:
                self.add_finding(Finding(
                    code="AP-09",
                    severity="HIGH",
                    title=f"Unwarranted eager startup flag: {kind}",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Forces plugin instantiation into Ring 1 cold startup hot path.",
                    remediation="Remove eager flags; bind plugins to event, ft, cmd, or keys."
                ))
        else:
            self.record_pass()

    # ── Check AP-10: Synchronous init = function() Hooks ──────────────────────
    def check_ap10_init_hook_leaks(self):
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("--"):
                    continue
                if re.search(r'init\s*=\s*function', clean):
                    # Mini.icons devicons mock is an accepted single-line preloader
                    if "ui.lua" in rel:
                        continue
                    violations.append((rel, idx, clean))

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-10",
                    severity="HIGH",
                    title="Synchronous init = function() hook in plugin spec",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Lazy.nvim runs init hooks synchronously on EVERY boot, even when lazy=true.",
                    remediation="Move configuration into config = function() or after/ftplugin/<filetype>.lua."
                ))
        else:
            self.record_pass()

    # ── Check AP-11: Eager Dependencies (Missing lazy = true) ─────────────────
    def check_ap11_eager_dependencies(self):
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            content = lua_file.read_text(encoding="utf-8", errors="ignore")
            # Find dependencies blocks
            for m in re.finditer(r'dependencies\s*=\s*\{([^}]+)\}', content):
                block = m.group(1)
                # Check for raw string dependencies like "repo/name" instead of { "repo/name", lazy = true }
                # Except in coding/language where plenary or known lazy triggers exist
                for line in block.splitlines():
                    clean = line.strip()
                    if clean.startswith("--") or not clean:
                        continue
                    if re.match(r'^"[^"]+/[^"]+",?$', clean) or re.match(r"^'[^']+/[^']+',?$", clean):
                        dep_name = clean.strip('",\'')
                        # Exclude plenary/nvim-nio in plugins that are already lazy (e.g. cmd, ft)
                        if "plenary" in dep_name or "nvim-nio" in dep_name:
                            continue
                        violations.append((rel, clean, dep_name))

        if violations:
            for rel, snippet, dep in violations[:5]: # Report top 5
                self.add_finding(Finding(
                    code="AP-11",
                    severity="MEDIUM",
                    title=f"Plugin dependency declared without explicit lazy = true: {dep}",
                    file=rel,
                    line=1,
                    snippet=snippet,
                    impact="Lazy.nvim may load dependencies eagerly if parent plugin options merge.",
                    remediation=f'Declare dependencies as table: {{ "{dep}", lazy = true }}'
                ))
        else:
            self.record_pass()

    # ── Check AP-12: Module-Scope Execution in lua/plugins/*.lua ──────────────
    def check_ap12_module_scope_execution(self):
        # Checks if any file in lua/plugins/ executes mutating API calls outside return { ... }
        mutating_calls = [
            r'vim\.keymap\.set\s*\(',
            r'vim\.api\.nvim_create_autocmd\s*\(',
            r'vim\.cmd\s*\(',
        ]
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            in_return = False
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("return {") or clean == "return":
                    in_return = True
                if not in_return and not clean.startswith("--"):
                    for call in mutating_calls:
                        if re.search(call, clean):
                            violations.append((rel, idx, clean))

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-12",
                    severity="HIGH",
                    title="Mutating API call executed at module scope during { import = 'plugins' }",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Executes immediately on Ring 1 during lazy.nvim discovery; adds synchronous startup overhead.",
                    remediation="Move mutation inside plugin config callback or core/autocmds.lua."
                ))
        else:
            self.record_pass()

    # ── Check AP-13: Satellite Snacks.nvim Lifecycle Collisions ───────────────
    def check_ap13_snacks_satellite_hooks(self):
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            if "ui.lua" in rel or "ui-messages.lua" in rel:
                continue
            content = lua_file.read_text(encoding="utf-8", errors="ignore")
            if "folke/snacks.nvim" not in content:
                continue
            lines = content.splitlines()
            in_snacks_spec = False
            brace_depth = 0
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("--"):
                    continue
                if '"folke/snacks.nvim"' in clean or "'folke/snacks.nvim'" in clean:
                    in_snacks_spec = True
                    brace_depth = line.count("{") - line.count("}")
                    continue
                if in_snacks_spec:
                    brace_depth += line.count("{") - line.count("}")
                    if re.search(r'\binit\s*=\s*function', clean) or re.search(r'\bconfig\s*=\s*function', clean):
                        violations.append((rel, idx, clean))
                    if brace_depth <= 0:
                        in_snacks_spec = False

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-13",
                    severity="HIGH",
                    title="Satellite snacks.nvim spec defines lifecycle hook (init/config)",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Violates AGENTS.md §5 and causes silent lifecycle overrides in lazy.nvim.",
                    remediation="Satellite specs must supply ONLY declarative opts and keys."
                ))
        else:
            self.record_pass()

    # ── Check AP-14: Eager blink.cmp LSP Capability Trap ──────────────────────
    def check_ap14_blink_capability_trap(self):
        lang_lua = PLUGINS_DIR / "language.lua"
        if not lang_lua.exists():
            return
        content = lang_lua.read_text(encoding="utf-8")
        if "require('blink.cmp').get_lsp_capabilities()" in content and "package.loaded" not in content:
            self.add_finding(Finding(
                code="AP-14",
                severity="CRITICAL",
                title="Eager blink.cmp capability resolution on BufReadPre",
                file=str(lang_lua.relative_to(CONFIG_ROOT.parent)),
                line=1,
                snippet="require('blink.cmp').get_lsp_capabilities()",
                impact="+24.43ms synchronous stall on first buffer attachment.",
                remediation="Use Static Capability Injection Pattern with package.loaded['blink.cmp'] fallback."
            ))
        else:
            self.record_pass()

    # ── Check AP-15: Top-Level require('schemastore') in LSP Configs ──────────
    def check_ap15_schemastore_top_level_require(self):
        violations = []
        if LSP_DIR.exists():
            for lua_file in LSP_DIR.glob("*.lua"):
                rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
                content = lua_file.read_text(encoding="utf-8", errors="ignore")
                # If properly deferred inside before_init or on_new_config, it is not top-level
                if "before_init" in content or "on_new_config" in content:
                    continue
                lines = content.splitlines()
                for idx, line in enumerate(lines, 1):
                    clean = line.strip()
                    if clean.startswith("--"):
                        continue
                    if 'require("schemastore")' in clean or "require('schemastore')" in clean:
                        violations.append((rel, idx, clean))

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-15",
                    severity="MEDIUM",
                    title="Top-level require('schemastore') inside LSP config file",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="+4.34ms synchronous parsing of JSON schema catalogs during server probe.",
                    remediation="Defer schemastore resolution inside before_init or on_new_config."
                ))
        else:
            self.record_pass()

    # ── Check AP-16: Synchronous vim.fn.executable() Loop at Boot ─────────────
    def check_ap16_sync_executable_scan(self):
        lang_lua = PLUGINS_DIR / "language.lua"
        if not lang_lua.exists():
            return
        content = lang_lua.read_text(encoding="utf-8")
        # Check if executable loop runs unconditionally inside config without guard
        if "vim.fn.executable" in content and "for server, bins in pairs(servers) do" in content:
            # Check if nvim-lspconfig is deferred to BufReadPre/BufNewFile
            lines = content.splitlines()
            for idx, line in enumerate(lines, 1):
                if "for server, bins in pairs(servers) do" in line:
                    self.add_finding(Finding(
                        code="AP-16",
                        severity="MEDIUM",
                        title="Synchronous executable loop scanning 29+ LSP binaries",
                        file=str(lang_lua.relative_to(CONFIG_ROOT.parent)),
                        line=idx,
                        snippet=line.strip(),
                        impact="+3.5ms disk I/O searching $PATH during LSP initialization.",
                        remediation="Rely on native Neovim 0.12 vim.lsp.enable(servers) with on-demand spawn."
                    ))
                    return
        self.record_pass()

    # ── Check AP-17: Blocking format_on_save ──────────────────────────────────
    def check_ap17_blocking_format_on_save(self):
        coding_lua = PLUGINS_DIR / "coding.lua"
        quality_lua = PLUGINS_DIR / "quality.lua"
        for target in [coding_lua, quality_lua]:
            if target.exists():
                content = target.read_text(encoding="utf-8")
                if "format_on_save" in content and "format_after_save" not in content:
                    self.add_finding(Finding(
                        code="AP-17",
                        severity="HIGH",
                        title="Synchronous format_on_save configured in conform.nvim",
                        file=str(target.relative_to(CONFIG_ROOT.parent)),
                        line=1,
                        snippet="format_on_save = { ... }",
                        impact="Blocks main UI thread up to 3000ms while waiting for external formatters.",
                        remediation="Replace with non-blocking async format_after_save = { lsp_format = 'fallback' }."
                    ))
                    return
        self.record_pass()

    # ── Check AP-18: Eager vim.filetype.add in Plugin Spec ────────────────────
    def check_ap18_filetype_sourcing_leak(self):
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            lines = lua_file.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines, 1):
                clean = line.strip()
                if clean.startswith("--"):
                    continue
                if "vim.filetype.add" in clean:
                    violations.append((rel, idx, clean))

        if violations:
            for rel, idx, snippet in violations:
                self.add_finding(Finding(
                    code="AP-18",
                    severity="HIGH",
                    title="vim.filetype.add() called eagerly within plugin manifest",
                    file=rel,
                    line=idx,
                    snippet=snippet,
                    impact="Forces double-sourcing of filetype.lua, adding ~1.4ms to cold startup clock.",
                    remediation="Move custom filetypes to ftdetect/*.lua or core/autocmds.lua on BufReadPre."
                ))
        else:
            self.record_pass()

    # ── Check AP-19: Heavy Buffer-Attach Triggers on BufReadPost ──────────────
    def check_ap19_buffer_attach_transitive_pulls(self):
        heavy_plugins_on_bufread = [
            "highlight-undo", "nvim_context_vt", "todo-comments"
        ]
        violations = []
        for lua_file in PLUGINS_DIR.glob("*.lua"):
            rel = str(lua_file.relative_to(CONFIG_ROOT.parent))
            content = lua_file.read_text(encoding="utf-8", errors="ignore")
            lines = content.splitlines()
            for heavy in heavy_plugins_on_bufread:
                if heavy in content:
                    in_spec = False
                    brace_depth = 0
                    for idx, line in enumerate(lines, 1):
                        if heavy in line:
                            in_spec = True
                            brace_depth = line.count("{") - line.count("}")
                            continue
                        if in_spec:
                            brace_depth += line.count("{") - line.count("}")
                            if "BufReadPost" in line and "event" in line:
                                violations.append((rel, heavy))
                                break
                            if brace_depth <= 0:
                                in_spec = False

        if violations:
            for rel, plug in violations:
                self.add_finding(Finding(
                    code="AP-19",
                    severity="MEDIUM",
                    title=f"Micro-plugin '{plug}' bound to BufReadPost instead of VeryLazy",
                    file=rel,
                    line=1,
                    snippet=f'event = "BufReadPost" on {plug}',
                    impact="+1.0–3.0ms added to interactive buffer opening latency.",
                    remediation=f"Change event = 'VeryLazy' for {plug}."
                ))
        else:
            self.record_pass()

    # ── Check AP-20: Large File Guard Integrity ───────────────────────────────
    def check_ap20_large_file_guard_integrity(self):
        autocmds_lua = CORE_DIR / "autocmds.lua"
        guard_lua = CORE_DIR / "guard.lua"
        if not autocmds_lua.exists() or not guard_lua.exists():
            self.add_finding(Finding(
                code="AP-20",
                severity="CRITICAL",
                title="Large-file guard architecture missing",
                file="zx0r/lua/core/",
                line=1,
                snippet="<missing>",
                impact="Catastrophic freeze on files >1MB without AST/LSP protection.",
                remediation="Ensure core/guard.lua exists and is triggered on BufReadPre in core/autocmds.lua."
            ))
            return

        auto_content = autocmds_lua.read_text(encoding="utf-8")
        if "core.guard" not in auto_content and "guard.check" not in auto_content:
            self.add_finding(Finding(
                code="AP-20",
                severity="CRITICAL",
                title="Large-file guard trigger missing from BufReadPre",
                file=str(autocmds_lua.relative_to(CONFIG_ROOT.parent)),
                line=1,
                snippet="<missing guard trigger>",
                impact="Large files bypass protection, causing tree-sitter hang on 1MB+ buffers.",
                remediation="Hook require('core.guard').check(event.buf) into BufReadPre autocmd."
            ))
        else:
            self.record_pass()


def render_report(auditor: AntiPatternAuditor, as_json: bool = False):
    s = auditor.summary
    if as_json:
        data = {
            "summary": asdict(s),
            "score_pct": round((s.passed_checks / max(1, s.total_checks)) * 100, 2)
        }
        print(json.dumps(data, indent=2))
        return

    print("╔══════════════════════════════════════════════════════════════════════════════╗")
    print("║   x0r/nvim — Anti-Pattern & Bottleneck Forensic Audit Report                 ║")
    print("╚══════════════════════════════════════════════════════════════════════════════╝")
    score_pct = (s.passed_checks / max(1, s.total_checks)) * 100.0
    print(f"  Total Invariants Tested: {s.total_checks}")
    print(f"  Passed Checks:           {s.passed_checks}  ({score_pct:.1f}%)")
    print(f"  Detected Deficiencies:   {s.failed_checks}")
    print(f"    • CRITICAL:            {s.critical_count}")
    print(f"    • HIGH:                {s.high_count}")
    print(f"    • MEDIUM:              {s.medium_count}")
    print(f"    • LOW:                 {s.low_count}")
    print("────────────────────────────────────────────────────────────────────────────────")

    if not s.findings:
        print("  ✅ ZERO ANTI-PATTERNS DETECTED! Configuration adheres 100% to research corpus.")
        print("────────────────────────────────────────────────────────────────────────────────\n")
        return

    print("  ACTIVE DEFICIENCIES & REMEDIATION PLAN:")
    print("────────────────────────────────────────────────────────────────────────────────")
    for f in s.findings:
        color_tag = f"[{f.severity}]"
        print(f"  {color_tag:10} {f.code}: {f.title}")
        print(f"             Location:    {f.file}:{f.line}")
        print(f"             Code:        {f.snippet}")
        print(f"             Impact:      {f.impact}")
        print(f"             Remedy:      {f.remediation}")
        print("  " + "─" * 78)


def main():
    parser = argparse.ArgumentParser(description="x0r/nvim Anti-Pattern Forensic Scanner")
    parser.add_argument("--json", action="store_true", help="Output findings as JSON")
    parser.add_argument("--verbose", action="store_true", help="Verbose debug logging")
    args = parser.parse_args()

    auditor = AntiPatternAuditor(CONFIG_ROOT, verbose=args.verbose)
    auditor.audit_all()
    render_report(auditor, as_json=args.json)

    if auditor.summary.critical_count > 0:
        sys.exit(2)
    elif auditor.summary.failed_checks > 0:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
