# Tmux Configuration Guide

To achieve a clean, maintainable, and modular structure for your Tmux configuration, it's important to organize your files in a logical way, separating concerns while allowing for easy updates and readability. Here are some best practices and guidelines you can follow when organizing configuration files (themes, plugins, keybindings, hooks) and custom scripts in the /tmux directory.

## ⚠️ Status

**This project is in active development**

> The current version should be considered a reference implementation rather than a complete system.Planned features, including AI-assisted tooling, are not yet finalized and will be integrated in future revisions.

## Directory Structure

A good directory structure helps maintain a separation of concerns and modularity.
Here's an ideal structure for organizing your Tmux configuration:

```plaintext
 ~/.config/tmux/ 🥷
├── config
│   ├── binds.conf
│   ├── core.conf
│   ├── hooks.conf
│   ├── plugins.conf
│   └── theme.conf
├── modes
│   ├── agent.tmux
│   └── human.tmux
├── README.md
├── scripts
│   ├── ai
│   │   └── ai-prompt-edit.sh
│   └── fzf-panes.sh
├── stages
│   ├── dev.tmux
│   ├── prod.tmux
│   └── staging.tmux
├── theme
│   ├── dark.tmux
│   └── light.tmux
└── tmux.conf
```


## Main Configuration File (tmux.conf):

Your main tmux.conf acts as the orchestrator, loading configuration files through a multi-layered initialization process:

- **Layer I (Bootstrap):** Resolves paths relative to XDG specifications and sets format-expanded path variables.
- **Layer II (Module Router):** Sequentially sources configuration subsystems from the `config/` directory.
- **Layer III (Environment Sync):** Synchronizes critical environment variables with the active terminal state.
- **Layer IV (Operational Stage Router):** Loads deployment-specific configuration overrides (e.g., dev, prod) from the `stages/` directory based on the current `X_STAGE`.

### Contextual Routing: Stages & Modes

The configuration dynamically adapts to external context via targeted environment injection:

- **Stages (`stages/`):** Controls environmental behavior. Loading `stages/prod.tmux` versus `stages/dev.tmux` enforces strict visual or functional overrides (e.g., changing border colors to signal danger in production environments).
- **Modes (`modes/`):** Defines interaction schemas. `modes/human.tmux` provides standard interactive keybindings, while `modes/agent.tmux` adjusts the interface for programmatic and AI-assisted manipulation.

## Workspace Paradigm: Cognitive Load Minimization

Recent software engineering research highlights that unplanned context switching and workspace clutter significantly degrade developer throughput by introducing "attention residue"—a state where cognitive capacity remains anchored to previous tasks (Leroy, 2009). 

To systematically mitigate this, the configuration enforces a strict 3-window multiplexing paradigm per session. These windows are mapped to specific operational domains using traditional Chinese numerals as visual anchors, ensuring topological isolation of workflows:

- **Window 一 (Dev): Active Development**
  Dedicated exclusively to code synthesis. This environment remains a distraction-free interface restricted to the primary editor (e.g., Neovim).
  
- **Window 二 (Ops): Operations & Meta-management**
  The control zone. Responsible for version control operations (Git), system monitoring, ad-hoc shell execution, deployment pipelines, and structural file management.
  
- **Window 三 (Run): Runtime Environment**
  The execution zone. Hosts the active application infrastructure, including Next.js servers, backend APIs, frontend compilation processes, Docker containers, and database connections.

This topological isolation guarantees that domain-specific mental models remain intact, ensuring zero collision between development context, operational control, and runtime monitoring.

## Implementation Guidelines:

**Descriptive Filenames**: Filenames must explicitly indicate their operational domain (e.g., `binds.conf`, `hooks.conf`) to facilitate efficient navigation and targeted modifications.

**Component Isolation**: Configuration logic must be strictly separated. Each file is restricted to a single functional scope (e.g., rendering logic is isolated from keybindings). This prevents the operational complexity typical of monolithic configuration architectures.

**Version Control**: Track state changes and configuration revisions via Git. This ensures reproducibility, deployment safety, and reliable rollback capabilities.

**Documentation**: Inline comments must be maintained for all routing logic, hook executions, and variable definitions.

## Conclusion:

The implemented architecture relies on deterministic routing and strict separation of concerns, ensuring predictable execution and simplified debugging across different operational environments.
