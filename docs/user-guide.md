# Daylight user guide

Independent countdown widgets for your Mac, with a quiet menu-bar app and automatic restoration after login. SwiftUI + AppKit, no dependencies, accounts, tracking or network requests.

## Your countdowns

Open **Daylight** from your Applications folder, or click its ring icon in the menu bar and choose **Manage countdowns…**.

Use **New countdown** (⌘N) to add a countdown. Choose a title, target date, style and one of ten color presets. Each countdown has its own desktop window and settings. Switch directly between the visible countdown tabs above the editor; scroll the tab strip if you have more countdowns than fit. **Delete** removes the selected countdown immediately.

Each widget can use **Number**, **Ring**, **Flip clock** or **Day grid** independently. Its date, appearance, size, screen position, always-on-top setting and Spaces setting are saved separately. Editing one never changes the others. The app migrates a version 1 countdown automatically and makes a backup before replacing the old file.

The occasion is the widget's heading, with the target date at the bottom. Style cards and size controls are clickable across their full area.

Ten coordinated color presets are available in the editor and timer creation: **Ember**, **Moonlight**, **Porcelain**, **Dune**, **Grove**, **Blossom**, **Aurora**, **Canopy**, **Tide** and **Clay**. Each applies a matching background and accent together. Existing saved colors remain intact until you choose a preset.

## Focus timers

Click **New timer** (⌘T) in the editor or menu bar. Choose **15**, **25**, **45** or **60 minutes**, enter a custom duration from 1 to 1,440 minutes, or choose **Finish at** to set an exact clock time today. Times that have already passed are rejected. Give the session a name and press **Start timer**.

A temporary ring widget shows minutes and seconds remaining (including hours for longer sessions). The ring drains to zero. Its title, colors, size and display work like the other widgets; focus timers always use Ring. Timers are independent and can run together.

When a timer finishes, its window comes forward, including when it was hidden, and an original three-note chime repeats gently every seven seconds. Click **Acknowledge** in its widget or preview, or use its menu-bar acknowledgment action. This stops the chime for that timer and removes it. Other finished timers keep ringing until acknowledged. Closing a finished tile hides it; the chime continues until you acknowledge it from the editor or menu bar. **Cancel timer** or Delete removes a running timer early.

Timers retain their absolute finish time through sleep, quit/relaunch and login. If a deadline passes while Daylight is not running or the Mac is asleep, the completion alert appears when the app runs or wakes again. The app must be running and the Mac awake to play audio; playback follows the Mac's output volume. This is a single-session timer, without automatic break cycles.

## Desktop windows

Use **Show all** or **Hide all** above the preview to control desktop visibility. Drag a tile by its background using macOS’s native window dragging, or resize it from an edge. When the main window is open, **single-click a tile** to select its occasion. **Double-click a tile** to open the main window when it is closed. Tiles reveal their close control only while the pointer is over the tile; there are no minimize/maximize controls or hover toolbar.

Choose **X-small** (260×240), **Small** (360×320), **Medium** (560×460) or **Large** (900×650) in the main window. The preview renders that size without resizing the editor; larger previews scale down with a scale label. Drag a tile to another display to move it there. Use the View menu or ⌃⌘F for full screen; Escape returns to the window.

**Auto arrange** shows all tiles and lays them out left to right, top to bottom, nearest deadline first (including timers). Each tile stays on its current display. Each display is arranged independently, reducing tile sizes as needed while keeping at least X-small bounds. Tiles never spill to another display. Positions and fitted dimensions are saved. Preset choices stay unchanged, so selecting a size restores that preset’s dimensions. Exit full screen before arranging. If a display cannot fit all of its tiles at minimum size, a message identifies the remaining count; those tiles retain their prior positions.

Closing a widget hides it without deleting its countdown. Hidden widgets stay hidden after restart; reopen them from the menu bar or editor. Closing the editor leaves the menu-bar app and widgets running.

This app uses freely resizable desktop windows; it does not add a WidgetKit extension to macOS’s Edit Widgets gallery.

## Menu bar, Dock, login and restart

While the main window is open, Daylight appears in the Dock and has the normal application menu at the top of the screen. Closing the main window removes that Dock/menu presence and leaves tiles, timers and the menu-bar icon running. Double-click a tile or choose **Manage countdowns…** from the menu-bar icon to reopen it. The menu-bar icon shows an active timer when present, or the next upcoming date countdown.

**Launch at login** uses Apple’s `SMAppService` API. The installed copy enables it on its first version 2 launch; you can turn it off in the editor. If macOS needs approval, choose **Finish setup…** and allow Daylight in **System Settings → General → Login Items & Extensions**.

Keep the app in **~/Applications/Daylight.app** or **/Applications/Daylight.app**, so its login-item registration points to a stable location. Development and isolated test copies do not automatically register login items.

After restarting and signing in, visible widgets reopen with their own style, size and position. The editor stays closed after the first launch. A disconnected monitor causes affected widgets to appear on an available display. Full-screen sessions restore as normal resizable windows. No app can display these windows before you sign in to macOS.

**Quit Daylight** closes the app now but remembers which widgets should reopen next time. To keep a widget from reopening, close that widget or choose Hide all before quitting. To stop automatic startup, turn off Launch at login.

## Dates and styles

**Number** and **Ring** show calendar days until the date. The ring drains from the **Progress timeline → Counting from** date to the target. **Flip clock** shows remaining calendar days, hours and minutes to midnight at the beginning of the selected date and updates each minute.

**Day grid** uses small rounded squares to show time passing. One square represents one calendar day from **Progress timeline → Counting from** to the target date (the target itself is the finish line). Passed days fill with your accent, future days stay dim, and today is outlined. On the target date the whole grid is filled. Very long ranges group days to keep at most 600 squares; a label explains the maximum days per square, and partially completed groups have intermediate intensity. All four tile sizes, presets and the live preview work with this style. Use ⌘4 to select it.

For example, tomorrow displays 1 in Number and Ring, without a days-to-go caption. At 10 am, Flip clock shows 00 days, 14 hours, 00 minutes. Today and past dates stop at zero. Civil dates remain the selected day when you travel; calculations use the Mac’s current calendar and time zone.

Ten paired color presets, long-title wrapping, accessible countdown summaries and Reduce Motion support are included.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N | New countdown |
| ⌘T | New focus timer |
| ⌘E | Edit the active widget, or selected countdown |
| ⌘D | Show the selected widget |
| ⌘1 / ⌘2 / ⌘3 / ⌘4 | Number / Ring / Flip clock / Day grid for the active widget |
| ⌃⌘F | Toggle full screen for the active widget |
| ⇧⌘P | Toggle always on top for the active widget |
| Escape | Leave full screen |
| ⌘Q | Quit |

## Local data and recovery

Countdowns, active timers and window placements are stored in `~/Library/Application Support/Daylight/countdown.json`. Writes are atomic, save after edits and flush on quit/logout. Stable display UUIDs and relative screen positions allow monitor layouts to change safely. Version 2.2 upgrades this file to schema 3 and backs up the prior collection before writing it; all countdown entries are preserved.

Failed saves show Retry. Unreadable files pause automatic saves and offer **Back up & start fresh**, which copies the original first. Migration from version 1 likewise creates a uniquely named `countdown-backup-….json` beside the original.
