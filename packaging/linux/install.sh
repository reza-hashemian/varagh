#!/bin/sh
# Installs Varagh for the current user: the app under ~/.local/opt, a
# launcher in the application menu, and "Open with" for books.
# Run from the unpacked bundle folder, or from the repo after
# `flutter build linux --release`.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
if [ -x "$here/varagh" ]; then
  bundle=$here
else
  bundle=$here/../../build/linux/x64/release/bundle
fi
[ -x "$bundle/varagh" ] || { echo "Build the app first: flutter build linux --release" >&2; exit 1; }

data=${XDG_DATA_HOME:-$HOME/.local/share}
target=$HOME/.local/opt/varagh
icon=$here/varagh.png
[ -f "$icon" ] || icon=$here/../../assets/icon/varagh.png

rm -rf "$target"
mkdir -p "$target" "$data/applications" "$data/icons/hicolor/512x512/apps"
cp -R "$bundle/." "$target/"
cp "$icon" "$data/icons/hicolor/512x512/apps/app.varagh.varagh.png"

cat > "$data/applications/app.varagh.varagh.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Varagh
Name[fa]=ورق
Comment=Read, annotate, take notes and manage tasks
Comment[fa]=کتاب‌خوان، یادداشت و مدیریت کارها
Exec="$target/varagh" %f
Icon=app.varagh.varagh
Terminal=false
Categories=Office;Viewer;Education;
MimeType=application/pdf;application/epub+zip;text/markdown;text/html;text/plain;
StartupWMClass=app.varagh.varagh
EOF

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q "$data/icons/hicolor" || true
echo "Installed to $target. Find Varagh in the application menu."
