# PasteStack error codes

Every error PasteStack shows has a code like `PS-103`. Find your code below to
see what happened and what to try.

**Getting help from an AI assistant:** in the error alert, click **Copy Error
Details**, then paste it into your assistant together with a link to this page
(or its plain-text version:
https://raw.githubusercontent.com/jonpikereally/PasteStack/main/ERRORS.md).
The details include the code, what went wrong, and your PasteStack and macOS
versions. They never include anything from your clipboard.

Where errors show up:

- **Alerts** show the code, plus **Copy Error Details** and **Open Error List**
  buttons. Hovering over the error text points you here.
- **Background problems** appear as a **⚠️ Problem PS-xxx** row in the
  PasteStack menu bar dropdown. Click it for the full alert.
- **The installer** (Install PasteStack.command) prints its code in the
  Terminal window.
- **Every error** is also written to
  `~/Library/Application Support/PasteStack/errors.log`, with codes and
  technical details only.

Codes are permanent: a code always means the same thing and is never reused.
Codes are grouped by area: 1xx updates, 2xx Open at Login, 3xx pasting and
the ⇧⌘V shortcut, 4xx screenshots, 5xx saved history and items, 6xx the
installer, 999 anything else.

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

Still stuck? Open an issue at
https://github.com/jonpikereally/PasteStack/issues and include the copied
error details.
