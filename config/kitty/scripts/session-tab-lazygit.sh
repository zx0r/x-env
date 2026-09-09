#!/usr/bin/env bash

# chmod +x ~/.config/kitty/scripts/find-and-lazygit.sh

# Find the first Git repository in the home directory
REPO=$(find ~ -type d -name .git -print -quit 2>/dev/null | xargs dirname)

# Check if a repository was found
if [[ -n "$REPO" ]]; then
  echo "Found Git repository: $REPO"
  cd "$REPO" || exit 1 # Navigate to the repository
  lazygit              # Start lazygit
else
  echo "No Git repository found."
  echo "Press Enter to exit..."
  read -r # Wait for user input before closing the tab
fi
