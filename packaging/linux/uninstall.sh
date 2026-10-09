#!/bin/sh
# Removes what install.sh put in place. Your library (books, notes, tasks)
# under ~/.local/share/app.varagh.varagh is left alone.
set -eu
data=${XDG_DATA_HOME:-$HOME/.local/share}
rm -rf "$HOME/.local/opt/varagh"
rm -f "$data/applications/app.varagh.varagh.desktop" "$data/icons/hicolor/512x512/apps/app.varagh.varagh.png"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data/applications" || true
# A cache that still lists the removed icon hides the one a .deb installs
# system-wide.
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -q "$data/icons/hicolor" || true
echo "Varagh removed. Your library is still in $data/app.varagh.varagh."
