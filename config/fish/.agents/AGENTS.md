# Agent Workspace Rules

This file governs agent behavior when inspecting, debugging, or modifying the workstation configuration.

## Agent System Entrypoint

To understand the system topology, dependencies, and metadata schema, agents MUST read the Map of Content (MoC) file first before performing modifications:
- [MAP_OF_CONTENT.md](file:///Users/x0r/.config/fish/.meta/MAP_OF_CONTENT.md)

## Rules of Engagement

1. **Meta-Driven Modification:** When editing any configuration file, you must update its YAML front-matter block (specifically the `updated_at` field and `backlinks` if dependency structures change).
2. **Zero-Fork SLA Enforcement:** Under no circumstances should process execution forks (e.g., executing external commands during non-interactive startups) be introduced. Any additions must respect the performance targets of cold start <25ms.
3. **English Code & Russian Communication:** All comments inside the configuration files must be written in English. Communication with the user must be conducted in Russian.
4. **Standardized Logging (Changelog):** Upon committing modifications, the agent must log the change in [changelog.md](file:///Users/x0r/.config/fish/.meta/log/changelog.md) strictly following the schema defined in [changelog_template.md](file:///Users/x0r/.config/fish/.meta/templates/changelog_template.md).

