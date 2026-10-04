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
- Copied email links paste as just the address (no `mailto:` in front), in
  any app, not only from PasteStack. Turn it off from the menu bar.
- Menu-bar icon → pause capturing, catch-all capture, copy new screenshots to
  the clipboard, remove "mailto:" from copied emails, open at login, check for
  updates, clear history

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

## Error codes

Every error PasteStack shows has a code like `PS-103`. Alerts have a **Copy
Error Details** button that copies the code, details, app version and macOS
version, ready to paste into an LLM or a bug report. Problems that happen in
the background show up as a **⚠️ Problem PS-xxx** row in the menu bar
dropdown. Every error is also written to
`~/Library/Application Support/PasteStack/errors.log` (codes and technical
details only, never clipboard contents).

| Code | What happened | What to try |
|---|---|---|
| PS-101 | No update source is set. | Set one with “Update Source…” in the menu, or leave it empty to use the built-in source. |
| PS-102 | The update source isn't a web link or a file path. | Set one with “Update Source…” in the menu, or leave it empty to use the built-in source. |
| PS-103 | Couldn't reach the update source. | Check your internet connection and try again. |
| PS-104 | The update server returned an error. | Try again in a few minutes. If it keeps happening, download the latest version from GitHub. |
| PS-105 | The update information is damaged or in the wrong format. | The published update is broken. Download the latest version from GitHub instead. |
| PS-106 | Couldn't download the update. | Try again in a few minutes. If it keeps happening, download the latest version from GitHub. |
| PS-107 | Couldn't unpack the downloaded update. | The published update is broken. Download the latest version from GitHub instead. |
| PS-108 | The downloaded update doesn't contain PasteStack. | The published update is broken. Download the latest version from GitHub instead. |
| PS-109 | The downloaded update is a different app. | The published update is broken. Download the latest version from GitHub instead. |
| PS-110 | The downloaded update is damaged. | The published update is broken. Download the latest version from GitHub instead. |
| PS-111 | Couldn't start installing the update. | Make sure PasteStack is in ~/Applications and that the folder isn't locked, then try again. |
| PS-112 | Installing the update failed, so the previous version was kept. | Make sure PasteStack is in ~/Applications and that the folder isn't locked, then try again. |
| PS-201 | Couldn't change Open at Login. | You can add PasteStack yourself in System Settings → General → Login Items. |
| PS-301 | PasteStack doesn't have Accessibility permission, so it can copy items but can't paste them for you. | Turn PasteStack on in System Settings → Privacy & Security → Accessibility. If it's already on, remove it with “−”, add it again, and relaunch. |
| PS-302 | Couldn't send the ⌘V keystroke to paste. | Press ⌘V yourself; the item is already on the clipboard. |
| PS-303 | Couldn't set up the ⇧⌘V shortcut. | Another app is probably using ⇧⌘V. Quit it, or open PasteStack from the menu bar icon. |
| PS-401 | Couldn't watch the screenshot folder, so new screenshots aren't being copied. | Allow PasteStack to access your Desktop (or your screenshot folder) in System Settings → Privacy & Security → Files and Folders. |
| PS-501 | Couldn't create PasteStack's data folder, so history can't be saved. | Check that your disk isn't full and that ~/Library/Application Support/PasteStack is writable. |
| PS-502 | Your saved history or pinboards couldn't be read. | PasteStack started with that part empty. The unreadable file was kept next to it, renamed with “damaged” in the name. |
| PS-503 | Couldn't save your history and pinboards. | Check that your disk isn't full and that ~/Library/Application Support/PasteStack is writable. |
| PS-504 | Couldn't save an item's image or app data. | Check that your disk isn't full and that ~/Library/Application Support/PasteStack is writable. |
| PS-505 | Couldn't read an item's saved image or app data, so a simpler version was pasted. | The saved copy is missing or damaged. Copy the original again to get the full version back. |
| PS-601 | The installer couldn't copy PasteStack into ~/Applications. | Make sure ~/Applications exists and isn't locked, then run the installer again. |
| PS-602 | The installer couldn't sign PasteStack for this Mac. | Install Xcode Command Line Tools (`xcode-select --install`) and run the installer again. |
| PS-603 | PasteStack was installed but the installer couldn't open it. | Open PasteStack from ~/Applications yourself. |
| PS-999 | Something unexpected went wrong. | Try again. If it keeps happening, copy the details and ask for help. |

## Development

Sources are in `Sources/PasteStack/`: plain Swift + AppKit + SwiftUI, compiled
with `swiftc` directly (no Xcode project, no dependencies).

- `./build.sh` builds `PasteStack.app` for this Mac, for trying changes locally.
- To ship a release: bump `VERSION`, write what changed in
  `RELEASE_NOTES.txt`, and merge to `main`. The **Release** workflow
  (`.github/workflows/release.yml`) builds every push to `main` on a GitHub
  Mac runner, and when `VERSION` is newer than `updates/latest.json` it commits
  the universal `updates/PasteStack.zip` and `updates/latest.json` back to
  `main`, which every installed copy checks. Pushes that don't bump the
  version ship nothing.
- To ship from your own Mac instead: `UPDATE_NOTES="What changed" ./release.sh`
  (or omit `UPDATE_NOTES` to use `RELEASE_NOTES.txt`), then commit + push.

The update source can be changed per install (menu → **Update Source…**) or
per build (`UPDATE_FEED=https://…/latest.json ./build.sh`). Feed format:

    {"version": "1.16", "url": "PasteStack.zip", "notes": "What changed"}

`url` may be absolute or relative to `latest.json`.

Troubleshooting: a click log can be turned on with
`defaults write com.jonpike.pastestack debugLogging -bool true`
(written to `~/Library/Application Support/PasteStack/debug.log`; entries
include the first 30 characters of clicked items).
