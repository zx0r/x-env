# Changelog Entry Template (Meta-Driven Design Schema)

This template defines the exact formatting that must be followed by any AI agent or developer when appending a new entry to [changelog.md](file:///Users/x0r/.config/fish/.meta/log/changelog.md).

---

```markdown
## Commit: <full_git_commit_hash>
**Author:** <author_name> <email>  
**Date:** <rfc_2822_or_iso_8601_date_string>  
**Subject:** <commit_subject_line>

### I. Modified Modules & Scope of Impact
*   [`<relative_file_path>`](file:///<absolute_file_path>) (<architectural_layer>) - <brief_responsibilty_of_change>

### II. Metadata Integration & State Transitions
*   **Front-matter Update:** Describe updates made to the front-matter YAML block (e.g., `updated_at`, `backlinks`, `history` entries).
*   **Dependency Changes:** Detail changes to dependency mappings and graph nodes.

### III. Architectural Changes & Systems Optimization
*   **Detailed technical breakdown:** Explain what systems-level adjustments were made (e.g., performance optimizations, path lookups, caching mechanics, socket redirections, or telemetry opt-outs).

### IV. Empirical Validation & Performance Metrics
*   **Objective:** Why was this change requested or technically necessary?
*   **Systemic Effect:** What is the result of this change?
*   **Verification Signals:** List the exact validation steps run (e.g., `fish -n`, startup latency benchmarks `time fish -i -c exit`, or testing tests) and their exact outputs.
```
