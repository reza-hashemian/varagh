#!/bin/sh
# Builds a .deb from the release bundle.
#   packaging/linux/build-deb.sh <version> [output-dir]
# Run after `flutter build linux --release`. Needs dpkg-deb.
set -eu

version=${1:?usage: build-deb.sh <version> [output-dir]}
here=$(cd "$(dirname "$0")" && pwd)
repo=$here/../..
out=$(mkdir -p "${2:-$repo/dist}" && cd "${2:-$repo/dist}" && pwd)
bundle=$repo/build/linux/x64/release/bundle
[ -x "$bundle/varagh" ] || { echo "Build the app first: flutter build linux --release" >&2; exit 1; }

# Assembled outside the repo: package files need Unix permissions, which a
# checkout on a Windows-formatted drive can't hold.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
root=$stage/varagh
mkdir -p "$root/DEBIAN" "$root/opt/varagh" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/512x512/apps"

cp -R "$bundle/." "$root/opt/varagh/"
ln -s /opt/varagh/varagh "$root/usr/bin/varagh"
cp "$repo/assets/icon/varagh.png" \
  "$root/usr/share/icons/hicolor/512x512/apps/app.varagh.varagh.png"

cat > "$root/usr/share/applications/app.varagh.varagh.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Varagh
Name[fa]=ورق
Comment=Read, annotate, take notes and manage tasks
Comment[fa]=کتاب‌خوان، یادداشت و مدیریت کارها
Exec=varagh %f
Icon=app.varagh.varagh
Terminal=false
Categories=Office;Viewer;Education;
MimeType=application/pdf;application/epub+zip;text/markdown;text/html;text/plain;
StartupWMClass=app.varagh.varagh
EOF

size=$(du -sk "$root/opt" "$root/usr" | awk '{s += $1} END {print s}')
cat > "$root/DEBIAN/control" <<EOF
Package: varagh
Version: $version
Section: text
Priority: optional
Architecture: amd64
Installed-Size: $size
Depends: libc6, libstdc++6, libgtk-3-0t64 | libgtk-3-0
Recommends: xdg-utils
Maintainer: reza-hashemian <reza-hashemian@users.noreply.github.com>
Homepage: https://github.com/reza-hashemian/varagh
Description: Reader for PDFs and books with notes, notebooks and tasks
 Varagh reads PDF, EPUB, Markdown, HTML and text, and reopens each book
 where it was left. Pages take highlights, pen and brush drawings, sticky
 notes and attached notebook pages. It also keeps Markdown notes and
 Trello-style task boards, and can sync through a shared folder, Google
 Drive or OneDrive.
EOF

find "$root" -type d -exec chmod 755 {} +
find "$root" -type f -exec chmod 644 {} +
chmod 755 "$root/opt/varagh/varagh"
find "$root/opt/varagh/lib" -name '*.so' -exec chmod 755 {} +

dpkg-deb --root-owner-group --build "$root" "$out/varagh_${version}_amd64.deb" >/dev/null
echo "$out/varagh_${version}_amd64.deb"
