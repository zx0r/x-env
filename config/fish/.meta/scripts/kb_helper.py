#!/usr/bin/env python3
import os
import sys
import argparse
import datetime
from pathlib import Path

META_DIR = Path(os.path.expanduser("~/.config/fish/.meta"))
MOC_FILE = META_DIR / "MAP_OF_CONTENT.md"
CHANGELOG_FILE = META_DIR / "log" / "changelog.md"
TEMPLATES_DIR = META_DIR / "templates"

def init_node(args):
    filepath = Path(args.file)
    is_fish = filepath.suffix == '.fish'
    
    title = args.title or "New Node"
    layer = args.layer or "Uncategorized"
    resp = args.responsibility or "TBD"
    
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    
    lines = []
    prefix = "# " if is_fish else ""
    
    lines.append(f"{prefix}---")
    lines.append(f"{prefix}title: \"{title}\"")
    lines.append(f"{prefix}module: {filepath.relative_to(META_DIR.parent)}")
    lines.append(f"{prefix}layer: {layer}")
    lines.append(f"{prefix}responsibility: {resp}")
    lines.append(f"{prefix}dependencies: []")
    lines.append(f"{prefix}backlinks: []")
    lines.append(f"{prefix}created_at: {today}")
    lines.append(f"{prefix}updated_at: {today}")
    lines.append(f"{prefix}tags: []")
    lines.append(f"{prefix}---")
    lines.append("")
    
    if is_fish:
        lines.append("# Implementation starts here")
    else:
        lines.append(f"# {title}")
        
    os.makedirs(filepath.parent, exist_ok=True)
    with open(filepath, 'w') as f:
        f.write("\n".join(lines) + "\n")
    
    print(f"Created node with frontmatter at {filepath}")

def update_moc(args):
    filepath = Path(args.file)
    rel_path = filepath.relative_to(META_DIR.parent)
    
    title = args.title or "New Node"
    layer = args.layer or "Uncategorized"
    
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    
    row = f"| [`{rel_path}`](file://{filepath.absolute()}) | {title} | {layer} | None | None | {today} | {today} | `tbd` |"
    
    # Very naive append to the end of the tables in MoC
    with open(MOC_FILE, 'r') as f:
        content = f.read()
    
    # Find the last table row
    lines = content.split('\n')
    for i in range(len(lines)-1, -1, -1):
        if lines[i].strip().startswith('|'):
            lines.insert(i+1, row)
            break
            
    with open(MOC_FILE, 'w') as f:
        f.write("\n".join(lines))
        
    print(f"Appended {rel_path} to MAP_OF_CONTENT.md")

def add_changelog(args):
    msg = args.message
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    
    entry = f"\n### {today} - {args.type}\n* {msg}\n"
    
    with open(CHANGELOG_FILE, 'a') as f:
        f.write(entry)
        
    print(f"Added changelog entry.")

def main():
    parser = argparse.ArgumentParser(description="Knowledge Base Helper")
    subparsers = parser.add_subparsers(dest="command")
    
    p_init = subparsers.add_parser("init", help="Init a new file with frontmatter")
    p_init.add_argument("file", help="Path to file")
    p_init.add_argument("--title", help="Title of node")
    p_init.add_argument("--layer", help="Layer classification")
    p_init.add_argument("--responsibility", help="Responsibility description")
    
    p_moc = subparsers.add_parser("moc", help="Add file to MAP_OF_CONTENT.md")
    p_moc.add_argument("file", help="Path to file")
    p_moc.add_argument("--title", help="Title of node")
    p_moc.add_argument("--layer", help="Layer classification")
    
    p_cl = subparsers.add_parser("changelog", help="Add a changelog entry")
    p_cl.add_argument("type", choices=["feature", "fix", "chore", "research"], help="Type of change")
    p_cl.add_argument("message", help="Changelog message")
    
    args = parser.parse_args()
    
    if args.command == "init":
        init_node(args)
    elif args.command == "moc":
        update_moc(args)
    elif args.command == "changelog":
        add_changelog(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
