# Varagh · ورق

A reader for PDFs and books that also holds your notes, notebooks and
tasks. Close a book on one device and continue from the same spot on
another.

Built with Flutter for Linux, Windows, macOS, Android and iOS. Linux is the
platform it has been built and run on so far; the others are untested.

کتاب‌خوانی برای PDF و کتاب که یادداشت‌ها، دفترها و کارهایت را هم نگه
می‌دارد. رابط فارسی و انگلیسی دارد، با تقویم شمسی و چیدمان راست‌به‌چپ.

## Download · دانلود

| | |
|---|---|
| Windows | [varagh-windows-x64.zip](https://github.com/reza-hashemian/varagh/releases/latest/download/varagh-windows-x64.zip) |
| Linux | [varagh-linux-x64.tar.gz](https://github.com/reza-hashemian/varagh/releases/latest/download/varagh-linux-x64.tar.gz) |
| Android | [varagh-android.apk](https://github.com/reza-hashemian/varagh/releases/latest/download/varagh-android.apk) |

These links always point at the newest release. Every version is on the
[releases page](https://github.com/reza-hashemian/varagh/releases).

- **Windows:** unzip anywhere and run `varagh.exe`. It has not been run on
  Windows yet; reports are welcome.
- **Linux:** unpack, then run `sh install.sh` inside the folder to add
  Varagh to the application menu, or run `./varagh` directly.
- **Android:** open the APK on the phone and allow installing from that
  source. It is signed with a test key and has not been tried on a device
  yet.

## What it does

**Reading**

- PDF, EPUB, Markdown, HTML and plain text
- Reopens every book at the page, zoom and scroll position you left it
- Page tinting for PDFs: paper, sepia, green, gray, dark and black, with
  strength, contrast and text weight controls, saved per book
- Find in book, table of contents, focus mode

**On the page**

- Highlights in five colors, each with an optional note
- Drawing tools: pen, fountain pen, brush, pencil, highlighter, eraser,
  shapes and typed text, in eight colors and three widths
- Sticky notes that sit on the page and can be dragged around
- Notebook pages attached to a spot in a book

**Notebooks**

- Blank, lined, grid or dotted pages to write, type and draw on with the
  same tools

**Notes and tasks**

- Markdown notes with a formatting toolbar and preview
- Tasks with due dates (Solar Hijri calendar in Persian), repeats,
  priorities and subtasks
- Trello-style boards per project: your own columns, drag cards between
  them, color labels
- Turn a highlight or a note into a task that links back to its source
- Search across book titles, highlights, notes and tasks

**Sync**

- Through a shared folder, Google Drive or OneDrive
- Reading positions, highlights, drawings, notes, notebooks, tasks and,
  optionally, the book files
- Everything is stored on the device first; sync is optional and there is
  no server in between

## Cloud sync uses your own keys

Varagh ships without API keys. To sync through Google Drive or OneDrive you
register an app with the provider once, for free, and paste its client ID
into Settings → Sync. The app then has access only to its own folder in
your account. Step-by-step instructions are inside the app, under "How to
get the keys".

Cloud sync has been tested against local stand-in servers, not yet against
the real Google and Microsoft services.

## Building

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel; developed with 3.47).

```sh
flutter pub get
flutter test
```

**Linux**

```sh
sudo apt install clang ninja-build libgtk-3-dev
flutter build linux --release
sh packaging/linux/install.sh    # adds Varagh to the application menu
```

`packaging/linux/uninstall.sh` removes it again and leaves your library
alone.

**Windows** (on Windows, with Visual Studio's "Desktop development with
C++" workload)

```sh
flutter build windows --release
```

The workflow in `.github/workflows/build.yml` builds both on GitHub Actions
when run by hand or when a `v*` tag is pushed.

## Where your data lives

On Linux, under `~/.local/share/app.varagh.varagh`: a SQLite database, the
book files and their covers.

## Fonts

The interface uses [Vazirmatn](https://github.com/rastikerdar/vazirmatn),
licensed under the SIL Open Font License 1.1 (see
`assets/fonts/Vazirmatn-OFL.txt`).
