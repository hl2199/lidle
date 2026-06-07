# clamshell-keepawake

Give your MacBook a grace period before it sleeps, instead of sleeping the
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

- holds `disablesleep` on while a grace period is active — and keeps it pre-armed
  so closing the lid or unplugging a monitor can't race to sleep before the next
  check;
- measures how long you've been idle (lid open) or unplugged (lid shut);
- at the 3-hour mark, sets `disablesleep 0` so macOS sleeps on its own.

Install also sets `pmset sleep 180`, `disksleep 180`, and `displaysleep 10`.

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
| `clamshell-keepawake set <hours>` | yes | Change the grace period (e.g. `1.5`). Re-arms immediately; if paused, resumes with the new time. |
| `clamshell-keepawake pause [dur]` | yes | Opt out until `resume`, or for a while: `pause 30m`, `pause 2h`. |
| `clamshell-keepawake resume` | yes | Cancel a pause. |
| `clamshell-keepawake status` | no | Show daemon, grace period, lid, pause state, and time left. |
| `clamshell-keepawake logs` | no | Follow the daemon log. |

```text
$ clamshell-keepawake status
clamshell-keepawake: installed
  Grace period:  3 h
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
one-click pause/resume and grace-period controls.

1. Install SwiftBar (`brew install --cask swiftbar`) and, on first launch, pick a
   Plugin Folder.
2. Add the menu item:
   ```sh
   sudo clamshell-keepawake menu-setup
   ```

This drops a tiny SwiftBar plugin (calling `clamshell-keepawake menu`) into your
plugin folder, and installs a **scoped, passwordless `sudo` rule** so the
Pause / Resume / Set actions act instantly. The rule
(`/etc/sudoers.d/clamshell-keepawake`) lets your user run **only**
`clamshell-keepawake pause`, `resume`, and `set <hours>` without a password —
nothing else.

The menu-bar icon is **☀** (holding the Mac awake) or **🌙** (not holding —
off, idle, or paused). The dropdown shows:

```
☀
──────────────────────────────
Active
Grace period: 3 h
──────────────────────────────
Pause                 (toggles to Resume when paused)
Set grace period ▸ 1h / 2h / 3h / 4h / Custom…
──────────────────────────────
Open log
Refresh
──────────────────────────────
Quit                  (stop everything, restore normal sleep)
```

**Quit** stops the daemon (so it won't restart on reboot), sets
`disablesleep 0`, and removes the menu item — but keeps the `clamshell-keepawake`
command, so you can switch it back on with `install`. It does *not* restore the
`sleep`/`displaysleep` timers install set; adjust display-off in System
Settings → Lock Screen if you want.

Remove just the menu (leaving the core tool installed):

```sh
sudo clamshell-keepawake menu-remove
```

`uninstall` also removes the menu plugin and sudo rule automatically.

## Uninstall

```sh
sudo clamshell-keepawake uninstall
```

Removes the daemon and re-enables normal sleep. The `sleep` / `disksleep` /
`displaysleep` timers it set are left in place; change them with `pmset` if you
like.

## Configuration

- **Grace period (how long it stays awake)** — `sudo clamshell-keepawake set 1.5`.
  Updates the daemon's config (`/usr/local/etc/clamshell-keepawake.conf`) and the
  matching `pmset` timers together, and re-arms right away.
- **Check interval** — `StartInterval` (default `60` seconds) in the generated
  `/Library/LaunchDaemons/com.clamshellkeepawake.plist`; this is also the timing
  resolution. Edit it and re-run `sudo clamshell-keepawake install` to regenerate.
- **Screen-off delay** — defaults to 10 min (or just under the grace period for
  very short durations). Change anytime with `sudo pmset -a displaysleep <min>`.

## Caveats

- **Manual sleep is blocked while a grace window is active.** Because
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

Logs go to `/var/log/clamshell-keepawake.log`.

## License

[MIT](LICENSE)
