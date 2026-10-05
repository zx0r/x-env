-- ============================================================================
-- plugins/infrastructure.lua — Infrastructure Tooling Domain
-- ============================================================================
--
-- Responsibility:
--   Infrastructure, containers, remote systems and operational tooling.
--
-- Intended plugins:
--   • Docker / container tooling
--   • Kubernetes
--   • Terraform / OpenTofu
--   • Ansible
--   • SSH / remote operations
--   • Cloud / infrastructure helpers
--
-- Boundary:
--   This module owns infrastructure-oriented editor integrations only.
--
-- Does NOT own:
--   • LSP configuration          → language.lua
--   • formatting / linting       → quality.lua
--   • test execution             → testing.lua
--   • Git / VCS                  → vcs.lua
-- ============================================================================

return {
  -- Native Neovim 0.12 handles terraform, hcl and helm natively via treesitter and LSP.
}
