# clamshell-keepawake

Give your MacBook an awake window before it sleeps, instead of sleeping the
instant you close the lid or unplug your external displays.

By default, macOS sleeps almost immediately when you close the lid with no
external display, or when you unplug the monitor you were using in clamshell
mode. `clamshell-keepawake` postpones that sleep by **3 hours**, then lets the
Mac sleep normally — and the timer resets the moment you start using it again.

Everything is driven by one command:

```sh
sudo clamshell-keepawake install     # enable it
     clamshell-keepawake status      # see what it's doing
sudo clamshell-keepawake pause 30m   # opt out for a bit
sudo clamshell-keepawake uninstall   # remove it
```

## What it does

| Situation | Behavior |
|---|---|
| **Lid open, left idle** | Screen turns off after 10 min; the Mac stays awake **3 h**, then sleeps. Any input resets the 3 h. |
| **Lid shut, monitor connected** (clamshell work) | Stays awake, no timer. |
| **Lid shut, no monitor** (closed, or monitor unplugged) | Stays awake **3 h**, then sleeps. Opening the lid or reconnecting a monitor resets it. |

Sleep is always **allowed, never forced**. If something would normally keep
your Mac awake (media playback, a download, screen sharing), it still does — the
tool only delays the sleeps that would have happened anyway.

## How it works

A MacBook can only stay awake with the lid shut via `pmset disablesleep`; the
common `caffeinate` trick can't stop lid-close sleep. Installing registers a
root LaunchDaemon that runs `clamshell-keepawake _tick` every 60 seconds, which:

- holds `disablesleep` on while an awake window is active — and keeps it pre-armed
  so closing the lid or unplugging a monitor can't race to sleep before the next
  check;
- measures how long you've been idle (lid open) or unplugged (lid shut);
- at the 3-hour mark, sets `disablesleep 0` so macOS sleeps on its own.

Install also points `pmset sleep` and `disksleep` at the awake window and
`displaysleep` at 10 min (so `sleep 180 / disksleep 180 / displaysleep 10` for the
default 3 h). It snapshots your previous values first and restores them on
uninstall.

## Requirements

- macOS — developed and tested on macOS 15 (Sequoia); uses only `pmset`,
  `ioreg`, `system_profiler`, and `launchctl`. Works on Apple Silicon and Intel.
- A MacBook (it relies on the lid / clamshell sensor).
- Administrator (`sudo`) access — it installs a system-wide LaunchDaemon.

## Install

```sh
git clone https://github.com/<you>/clamshell-keepawake.git
cd clamshell-keepawake
sudo ./clamshell-keepawake install        # asks how many hours to stay awake (default 3)
# or set it directly:
sudo ./clamshell-keepawake install 2      # stay awake 2 hours before sleeping (1.5 etc. allowed)
```

`install` copies the script to `/usr/local/bin/`, so afterwards you can run
`clamshell-keepawake` from anywhere.

> Run it in a real Terminal window so `sudo` can prompt for your password.

## Usage

| Command | Needs sudo | What it does |
|---|---|---|
| `clamshell-keepawake install [hours]` | yes | Install/enable. Prompts for hours if omitted (default 3). |
| `clamshell-keepawake uninstall` | yes | Remove the daemon and re-enable normal sleep. |
| `clamshell-keepawake quit` | yes | Stop the daemon and restore normal sleep, but keep it installed (re-enable with `install`). |
| `clamshell-keepawake set <hours>` | yes | Change the awake window (e.g. `1.5`, or `indefinite`). Re-arms immediately; if paused, resumes with the new time. |
| `clamshell-keepawake pause [dur]` | yes | Opt out until `resume`, or for a while: `pause 30m`, `pause 2h`. |
| `clamshell-keepawake resume` | yes | Cancel a pause. |
| `clamshell-keepawake status` | no | Show daemon, awake window, lid, pause state, and time left. |
| `clamshell-keepawake logs` | no | Follow the daemon log (records each state change). |
| `clamshell-keepawake version` | no | Print the version. |

```text
$ clamshell-keepawake status
clamshell-keepawake: installed
  Awake window:  3 h
  Lid:           open
  Paused:        no
  Keeping awake: yes  (sleeps in ~2 h 14 m if left idle)
```

## Pause

`pause` is the clean way to let your Mac sleep normally for a while without
uninstalling — handy when you *want* it to sleep on lid-close:

```sh
sudo clamshell-keepawake pause       # until you run 'resume'
sudo clamshell-keepawake pause 45m   # auto-resumes after 45 minutes
sudo clamshell-keepawake resume      # cancel early
```

While paused, the daemon stops holding the Mac awake and macOS sleeps on its own
schedule.

## Menu bar (SwiftBar)

Prefer a menu bar item over the terminal? `clamshell-keepawake` ships a
[SwiftBar](https://swiftbar.app) menu that shows the current state and gives you
one-click pause/resume and awake-window controls.

1. Install SwiftBar (`brew install --cask swiftbar`) and, on first launch, pick a
   Plugin Folder.
2. Add the menu item:
   ```sh
   sudo clamshell-keepawake menu-setup
   ```

This drops a tiny SwiftBar plugin (calling `clamshell-keepawake menu`) into your
plugin folder, and installs a **scoped, passwordless `sudo` rule** so the menu's
actions act instantly. The rule (`/etc/sudoers.d/clamshell-keepawake`) lets your
user run **only** four `clamshell-keepawake` subcommands without a password —
`pause [duration]`, `resume`, `set <hours>`, and `quit` (the menu's own buttons) —
and nothing else. `pause` and `set` each carry a wildcard for their one numeric
argument (the timed-pause and awake-window presets); `resume` and `quit` are
exact. It's written to a temp file and checked with `visudo` before being
installed `0440 root:wheel`, so a malformed rule can't break `sudo`.

It also installs a per-user **LaunchAgent**
(`~/Library/LaunchAgents/com.clamshellkeepawake.menu.plist`) that starts SwiftBar
at login, so the menu is present after every reboot — no need to toggle SwiftBar's
own "Launch at Login." (The keep-awake daemon runs as a root *LaunchDaemon* and
can't launch GUI apps into your session; the menu autostart has to be a
*LaunchAgent* in your login session, which is what this sets up.)

The menu-bar icon is **☀** (holding the Mac awake) or **🌙** (not holding —
off, idle, or paused). The dropdown shows:

```
☀
──────────────────────────────
Active
Awake window: 3 h
sleeps in ~2 h 14 m    (the live countdown, when one is running)
──────────────────────────────
Set awake window ▸ 1h / 3h / 8h / Indefinite / Custom…
Pause for ▸ 1h / 3h / 8h / Indefinite / Custom…   (a single Resume when paused)
──────────────────────────────
Open log
Refresh
──────────────────────────────
Quit                  (stop everything, restore normal sleep)
```

**Quit** stops the daemon (so it won't restart on reboot), restores normal sleep —
including the `sleep`/`displaysleep` timers from before install — and removes the
menu item, but keeps the `clamshell-keepawake` command so you can switch it back on
with `install`.

Remove just the menu (leaving the core tool installed):

```sh
sudo clamshell-keepawake menu-remove
```

`uninstall` (and `quit`) also remove the menu plugin, sudo rule, and login agent
automatically.

## Uninstall

```sh
sudo clamshell-keepawake uninstall
```

Removes the daemon, re-enables normal sleep, and restores the `sleep` /
`disksleep` / `displaysleep` timers to the values you had before installing
(snapshotted at install time).

## Configuration

- **Awake window (how long it stays awake)** — `sudo clamshell-keepawake set 1.5`.
  Updates the daemon's config (`/usr/local/etc/clamshell-keepawake.conf`) and the
  matching `pmset` timers together, and re-arms right away. Use
  `sudo clamshell-keepawake set indefinite` to keep the Mac awake with no time
  limit — it never sleeps on idle or lid-close until you change the window or pause.
- **Check interval** — `StartInterval` (default `60` seconds) in the generated
  `/Library/LaunchDaemons/com.clamshellkeepawake.plist`; this is also the timing
  resolution. Edit it and re-run `sudo clamshell-keepawake install` to regenerate.
- **Screen-off delay** — defaults to 10 min (or just under the awake window for
  very short durations). Change anytime with `sudo pmset -a displaysleep <min>`.

## Caveats

- **⚠️ Don't seal a closed MacBook in a bag mid-window.** While an awake window is
  active, closing the lid with no external display keeps the Mac fully awake (and
  warm) for the awake window instead of sleeping — so a closed laptop in a bag can
  build up heat. Run `sudo clamshell-keepawake pause` before you pack it away (or
  `pause 8h` for a trip), then `resume` later. With an **indefinite** window this
  never ends, so always pause (or switch back to a finite window) before transport.
- **Manual sleep is blocked while an awake window is active.** Because
  `disablesleep` has to stay armed to catch a lid-close, the Apple menu's *Sleep*
  and the power button won't sleep the Mac during a window. The simplest fix is
  to `pause` first:
  ```sh
  sudo clamshell-keepawake pause && pmset sleepnow
  ```
- All settings are system-wide and persist across reboots.
- The 60-second poll makes timing accurate to within about a minute.

## Files

| File | Installed to |
|---|---|
| `clamshell-keepawake` | `/usr/local/bin/` |
| `com.clamshellkeepawake.plist` (generated by `install`) | `/Library/LaunchDaemons/` |
| config | `/usr/local/etc/clamshell-keepawake.conf` |
| sleep-timer snapshot (restored on uninstall) | `/usr/local/etc/clamshell-keepawake.saved-pmset` |

Logs go to `/var/log/clamshell-keepawake.log`.

## License

[MIT](LICENSE)
