#!/usr/bin/env python3

import os
import sys
import subprocess

# author: https://github.com/olimorris/dotfiles/blob/main/commands/color_mode.py

kitty_path = "~/.config/kitty"
# starship_path = "~/.config/starship"
tmux_path = "$HONE/.config/tmux"
nvim_path = "~/.config/nvim-profiles/nvim"

# If we toggle dark mode via Alfred, we end up in a infinite loop. The dark-mode
# binary changes the MacOS mode which in turn causes color-mode-notify to run
# this script. This script then calls dark-mode (via the app_macos method)
# which kick starts this loop all over again. We use this boolean var
# to detect when we've run the command via the cmdline or alfred.
ran_from_cmd_line = False

# The order in which apps are changed
apps = [
    "kitty",
    # "starship",
    "neovim",
    # tmux must come after neovim.
    "tmux",
    # "fish",
]


def app_macos(mode):
    """
    Change the macOS environment
    """
    path_to_file = "~/.color_mode"

    # Open the color_mode file
    with open(os.path.expanduser(path_to_file), "r") as config_file:
        contents = config_file.read()

    # Change the mode to ensure on a fresh startup, the color is remembered
    if mode == "dark":
        contents = contents.replace("light", "dark")
        if ran_from_cmd_line:
            subprocess.run(["dark-mode", "on"])

    if mode == "light":
        contents = contents.replace("dark", "light")
        if ran_from_cmd_line:
            subprocess.run(["dark-mode", "off"])

    with open(os.path.expanduser(path_to_file), "w") as config_file:
        config_file.write(contents)


def app_kitty(mode):
    """
    Change the Kitty terminal
    """
    kitty_file = kitty_path + "/theme_env.conf"

    # Begin changing the modes
    if mode == "dark":
        contents = "include ./Gruvbox Material Dark Soft.conf"

    if mode == "light":
        contents = "include ./gruvbox/gruvbox_light_soft.conf"

    with open(os.path.expanduser(kitty_file), "w") as config_file:
        config_file.write(contents)

    # Reload the Kitty config
    # Note: For Kitty 0.23.1, this breaks it
    try:
        pids = subprocess.run(["pgrep", "kitty"], stdout=subprocess.PIPE)
        pids = pids.stdout.splitlines()
        for pid in pids:
            try:
                subprocess.run(["kill", "-SIGUSR1", pid])
            except:
                continue
    except IndexError:
        pass


def app_starship(mode):
    """
    Change the prompt in the terminal
    """
    if mode == "dark":
        return subprocess.run(
            [
                "cp",
                os.path.expanduser(starship_path + "/starship_dark.toml"),
                os.path.expanduser(starship_path + "/starship.toml"),
            ]
        )

    if mode == "light":
        return subprocess.run(
            [
                "cp",
                os.path.expanduser(starship_path + "/starship_light.toml"),
                os.path.expanduser(starship_path + "/starship.toml"),
            ]
        )


def app_tmux(mode):
    subprocess.run(
        [
            "/usr/local/bin/tmux",
            "source-file",
            os.path.expanduser(tmux_path + "$HONE/.config/tmux/tmux.conf"),
        ]
    )
    # return os.system("exec zsh")


def app_neovim(mode):
    """
    Change the Neovim color scheme
    """
    print("start process")
    from pynvim import attach
    import signal

    # sucks https://github.com/neovim/pynvim/issues/231
    def handler(signum, frame):
        raise Exception("end of time")

    signal.signal(signal.SIGALRM, handler)

    nvim_config = nvim_path + "settings_env.lua"
    # in your neovim config, require the settings_env.lua file by pcall.
    # you can add settings_env.lua to gitignore.

    if not os.path.isfile(os.path.expanduser(nvim_config)):
        with open(os.path.expanduser(nvim_config), "w") as fp:
            pass

    nvim_contents = 'vim.opt.background = "{mode}"'.format(mode=mode)
    nvim_contents = nvim_contents.strip()

    with open(os.path.expanduser(nvim_config), "w") as config_file:
        config_file.write(nvim_contents)

    # Now begin changing our open Neovim instances

    # Get the neovim servers using neovim-remote
    print("start nvr call")
    servers = subprocess.run(["nvr", "--serverlist"], stdout=subprocess.PIPE)
    servers = servers.stdout.splitlines()

    # must exit after 2s
    signal.alarm(2)
    # Loop through them and change the theme by calling our custom Lua code
    for server in servers:
        try:
            print("attaching to nvim")
            nvim = attach("socket", path=server)
            print("calling command")
            nvim.command("call v:lua.tw.ToggleTheme('" + mode + "')")
            print("finish call")
        except Exception as e:
            print(e)
            continue
    return


def app_fish(mode):
    return subprocess.run(["/usr/local/bin/fish"])


def run_apps(mode=None):
    """
    Based on the apps in our list, sequentially run and trigger them
    """
    if mode == None:
        mode = get_mode()

    for app in apps:
        getattr(sys.modules[__name__], "app_%s" % app)(mode)

    return


def get_mode():
    """
    Determine what mode macOS is currently in
    """
    mode = os.environ.get("DARKMODE", 1)
    if mode == 1 or mode == "1":
        return "dark"
    else:
        return "light"


if __name__ == "__main__":
    # If we've passed a specific mode then activate it
    try:
        print("start py1")
        if sys.argv[1]:
            ran_from_cmd_line = True
        run_apps(sys.argv[1])
    except IndexError:
        print("start py2")
        try:
            run_apps()
        except Exception as e:
            print(e)

