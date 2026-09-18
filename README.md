# PasteStack

A local, native macOS clipboard manager —
menu-bar app, card-wall picker, pinboards. No accounts, no sync: your history
lives in `~/Library/Application Support/PasteStack/` and never leaves your Mac.
The only network request is the update check (a small version file from this
repo).

## Install

**Ready-made app:** download [`updates/PasteStack.zip`](updates/PasteStack.zip),
unzip it, and double-click **Install PasteStack.command** (if macOS blocks it:
right-click → Open). Works on Apple Silicon and Intel, macOS 13+.

**Build it yourself** (needs Xcode Command Line Tools: `xcode-select --install`):

```
git clone https://github.com/jonpikereally/PasteStack.git
cd PasteStack
./build.sh
ditto --norsrc PasteStack.app ~/Applications/PasteStack.app
```

Then open PasteStack from Spotlight. Using Claude Code? Clone the repo, open
it in Claude Code, and say "install this"; `CLAUDE.md` covers the steps and
the known traps.

## Use

- **⇧⌘V** — open the card wall (bottom of screen), or click the 📋 menu-bar icon
- Type to **search** — matches content, **text inside images** (on-device OCR),
  source app, kind ("image", "link", "pdf", "screenshot"…), and day
  ("yesterday", "monday", "august 24"…). Multiple words narrow the match:
  `invoice yesterday pdf`
- Cards are **grouped by day** (Today, Yesterday, weekday…) as you scroll back
- **← →** to navigate, **↩** to paste into the app you were in, **esc** to close
- **Double-click a card** to paste it (**⇧**-double-click or **⇧↩** for plain text)
- **Right-click a card** — paste as plain text or as an image, pin to a pinboard, copy without pasting, delete
- **Pinboards** — tabs along the top; pinned items survive "Clear History" and never age out
- Menu-bar icon → pause capturing, catch-all capture, copy new screenshots to
  the clipboard, open at login, check for updates, clear history

## Catch-all capture (Logic Pro & other app-private data)

Menu-bar icon → **Catch-All Capture**. When on, every copy is archived with
*all* its pasteboard types byte-for-byte (up to 10 MB per item), so app-private
clipboard data — e.g. Logic Pro regions/MIDI — can be restored and pasted back
later with full fidelity. Cards without a previewable form show as indigo
**APP DATA** cards listing their type identifiers; text/image cards captured in
this mode carry a small 📦 marker and also paste back verbatim (formatting,
rich text, everything).

Caveat: this only works for apps that put real content on the system
clipboard. **Ableton Live uses an internal clipboard for clips/devices — no
clipboard manager can capture those.** Use Live's User Library for reusable
elements. Logic Pro does use the system pasteboard; whether old archives paste
back after a project closes depends on whether Logic's data is self-contained —
test with your workflow.

## What it captures

Text, URLs, images, and copied files — with source-app icon and timestamp.
History is capped at 1000 unpinned items. Copies flagged as concealed
(password managers like 1Password use the `org.nspasteboard.ConcealedType`
marker) are never recorded.

## Setup

1. Open PasteStack from `~/Applications` (not from a Dropbox/iCloud folder;
   macOS often refuses to launch apps from those).
2. Grant **Accessibility** permission when prompted
   (System Settings → Privacy & Security → Accessibility). This is what lets
   PasteStack press ⌘V for you after you pick a card. Without it, picking a
   card still copies the item; you just press ⌘V yourself. The menu shows
   whether it's working ("Auto-paste: ✓ enabled").
3. Optional: menu-bar icon → **Open at Login**.

## Updates

Menu-bar icon → **Check for Updates…**. PasteStack also checks by itself at
launch and every 6 hours. When a newer version exists, the menu-bar icon
changes to a download arrow and the menu item reads **Install Update to vX…**.
Installing quits the app, swaps in the new version (putting the old one back
if anything fails), and relaunches it. History and pinboards are kept.

After each update macOS asks for the Accessibility permission again. That's
expected for an ad-hoc-signed app; the updater clears the old entry so the
prompt comes up cleanly.

## Development

Sources are in `Sources/PasteStack/`: plain Swift + AppKit + SwiftUI, compiled
with `swiftc` directly (no Xcode project, no dependencies).

- `./build.sh` builds `PasteStack.app` for this Mac, for trying changes locally.
- To ship a release: bump `VERSION`, then run
  `UPDATE_NOTES="What changed" ./release.sh` and commit + push. That writes a
  universal build to `updates/PasteStack.zip` and the version file
  `updates/latest.json`, which every installed copy checks.

The update source can be changed per install (menu → **Update Source…**) or
per build (`UPDATE_FEED=https://…/latest.json ./build.sh`). Feed format:

    {"version": "1.16", "url": "PasteStack.zip", "notes": "What changed"}

`url` may be absolute or relative to `latest.json`.

Troubleshooting: a click log can be turned on with
`defaults write com.jonpike.pastestack debugLogging -bool true`
(written to `~/Library/Application Support/PasteStack/debug.log`; entries
include the first 30 characters of clicked items).
