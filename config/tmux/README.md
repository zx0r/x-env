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
│   ├── theme.conf
├── README.md
├── scripts
│   ├── ai
│   │   ├── ai-cli.sh
│   │   ├── ai-dashboard.sh
│   │   └── ai-prompt-edit.sh
│   ├── cpu.sh
│   ├── fzf-panes.sh
│   ├── git.sh
│   ├── mem.sh
│   ├── network.sh
│   ├── panes-fzf.sh
│   ├── smart-name.sh
│   ├── ssd.sh
│   ├── switch-pane.sh
│   └── uptime.sh
├── theme
│   ├── dark.tmux
│   └── light.tmux
└── tmux.conf
```


## Main Configuration File (tmux.conf):

Your main tmux.conf should act as the orchestrator, sourcing configuration files from different directories. Here's a sample tmux.conf file that sources these configuration files in an organized manner:

##  Best Practices for Maintainability:

Use Descriptive Filenames: Ensure all filenames are descriptive and convey what they do (e.g., pane_navigation.conf, copy_mode.conf, session_hooks.conf). This makes it easier to find and edit specific configurations later.

Modular Configurations: Keep each file small and focused on one task (e.g., a file for pane keybindings, another for hook configurations). This modular approach avoids the complexity of having a massive, hard-to-navigate configuration file.

Version Control: Use Git or another version control system to track changes to your Tmux configuration. This allows you to experiment with different setups, revert to working configurations, and share your setup with others.

Comments: Include comments in your configuration files to explain what certain settings or scripts do. This is especially useful when coming back to the configuration after a long time or for sharing with others.

## Conclusion:

This structure emphasizes modularity, ease of maintenance, and clarity. With the directory structure outlined above, each component of your Tmux configuration is organized logically, making it easier to update and manage your setup over time.
