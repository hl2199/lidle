# lidle

**Give your MacBook an awake window before it sleeps** — so closing the lid or
unplugging your external display doesn't put it to sleep the *instant* you do it.

By default, macOS sleeps almost immediately when you close the lid with no
external display, or when you unplug the monitor you were using in clamshell
mode. `lidle` holds that sleep off for a window you choose, then lets the Mac
sleep normally. Start using it again and the timer resets.

Sleep is always **delayed, never forced.** If something would normally keep your
Mac awake (media playback, a download, screen sharing), it still does — lidle
only postpones the sleeps that were going to happen anyway.

## Requirements

- A **MacBook** running macOS (developed and tested on macOS 15 Sequoia; works on
  Apple Silicon and Intel). It relies on the lid / clamshell sensor.
- **Administrator access** — it installs a small system-wide background service.

## Install

```sh
git clone https://github.com/<you>/lidle.git
cd lidle
sudo ./lidle install          # asks how many hours to stay awake (or "indefinite")
```

This copies `lidle` to `/usr/local/bin/` (so you can run it from anywhere) and
starts a background service that does the work. Run it in a real Terminal window
so `sudo` can prompt for your password.

> To set the window up front instead of being prompted: `sudo ./lidle install 2`
> (`1.5` and other fractions are allowed).

## Using lidle

### Menu bar (recommended)

The easiest way to use lidle day to day is a menu bar item, via
[SwiftBar](https://swiftbar.app). When you run `sudo lidle install` in a terminal it
offers to set this up for you — and if SwiftBar isn't installed, it offers to install
it via [Homebrew](https://brew.sh). So there's usually nothing else to do.

To add the menu item on its own (or after declining it at install):

```sh
sudo lidle menu-setup            # installs SwiftBar via Homebrew if it's missing
```

Without Homebrew, install SwiftBar from https://swiftbar.app first, then run `menu-setup`.

The icon is **☀** when lidle is holding your Mac awake and **☾** when it isn't
(off or paused). Click it for:

- **Pause for** ▸ 1h / 3h / 8h / Indefinite / Custom… — let the Mac sleep normally for a while
- **Set awake window** ▸ 1h / 3h / 8h / Indefinite / Custom… — change how long it stays awake
- **Open log**, **Remove menu bar** (drop just the menu, keep lidle running), and
  **Exit** (stop lidle and restore normal sleep)

`menu-setup` keeps the item across reboots and adds a narrowly-scoped,
passwordless `sudo` rule so the buttons act instantly — it can run **only**
lidle's own pause / resume / set / quit, nothing else. Remove just the menu with
`sudo lidle menu-remove`.

### Command line

Everything the menu does is also a command:

| Command | sudo | What it does |
|---|---|---|
| `lidle install [hours]` | yes | Install and enable (prompts for hours if omitted). |
| `lidle set <hours\|indefinite>` | yes | Change the awake window. |
| `lidle pause [duration]` | yes | Let it sleep normally for a while (`pause 30m`) or until `resume`. |
| `lidle resume` | yes | Cancel a pause. |
| `lidle status` | no | Show current state and time left. |
| `lidle logs` | no | Follow the log (one line per state change). |
| `lidle quit` | yes | Stop lidle but keep it installed. |
| `lidle uninstall` | yes | Remove everything and restore normal sleep. |

```text
$ lidle status
lidle: installed
  Awake window:  3 h
  Lid:           open
  Paused:        no
  Keeping awake: yes  (sleeps in ~2 h 14 m if left idle)
```

## What to expect

The rule is simple: **whenever your Mac would normally sleep, lidle delays that
sleep by your awake window, then lets it sleep.** Using the Mac again resets the
timer. In each situation:

| Situation | Behavior |
|---|---|
| Lid open, left idle | Screen off per your macOS display settings; sleeps after the window. Any input resets it. |
| Lid shut, monitor connected (clamshell) | Stays awake, no timer. |
| Lid shut, no monitor (closed, or unplugged) | Stays awake for the window, then sleeps. Opening the lid or reconnecting a monitor resets it. |

Set the window to **`indefinite`** to keep the Mac awake with no time limit.

## Heads-up

- **Heat** — while a window is active, a closed MacBook with no external display
  stays fully awake (and warm). Keep an eye on it, especially with an
  `indefinite` window, which never ends on its own.
- **Manual sleep** — while a window is active, the Apple menu's *Sleep* won't
  sleep the Mac (lidle has to stay armed to catch a lid-close). To sleep on
  demand, `pause` first: `sudo lidle pause && pmset sleepnow`.
- Settings are system-wide and persist across reboots; the 60-second check makes
  timing accurate to about a minute.

## Uninstall

```sh
sudo lidle uninstall
```

A full wipe: it removes the service, binary, config, log, and menu item, restores
the `sleep` / `disksleep` timers it changed at install, and verifies nothing is
left behind. Use `lidle quit` instead to stop lidle but keep it installed with
your settings intact.

## How it works

A MacBook can only stay awake with the lid shut via `pmset disablesleep` — the
common `caffeinate` trick can't stop lid-close sleep. Installing registers a root
**LaunchDaemon** that runs `lidle _tick` every 60 seconds. Each tick:

- holds `disablesleep` on while your window is active, and keeps it pre-armed so
  closing the lid or unplugging a monitor can't race to sleep before the next check;
- measures how long you've been idle (lid open) or unplugged (lid shut);
- at the end of the window, sets `disablesleep 0` and lets macOS sleep on its own.

Install also points `pmset sleep`/`disksleep` at your window, snapshotting your
previous values first and restoring them on uninstall. Your display-off (screen)
timer is left untouched, so the screen keeps following your macOS display settings.
The menu bar item is a thin SwiftBar plugin that calls `lidle menu`; a per-user
LaunchAgent starts SwiftBar at login so the item is there after reboots.

Files it manages: `/usr/local/bin/lidle`,
`/Library/LaunchDaemons/com.lidle.plist`, config `/usr/local/etc/lidle.conf`, and
log `/var/log/lidle.log`.

## License

[MIT](LICENSE)
