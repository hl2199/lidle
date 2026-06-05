# clamshell-keepawake

Give your MacBook a grace period before it sleeps, instead of sleeping the
instant you close the lid or unplug your external displays.

By default, macOS sleeps almost immediately when you close the lid with no
external display, or when you unplug the monitor you were using in clamshell
mode. `clamshell-keepawake` postpones that sleep by **3 hours**, then lets the
Mac sleep normally — and the timer resets the moment you start using it again.

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
common `caffeinate` trick can't stop lid-close sleep. A small root LaunchDaemon
runs every 60 seconds and:

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
sudo bash install.sh          # asks how many hours to stay awake (default 3)
# or set it directly:
sudo bash install.sh 2        # stay awake 2 hours before sleeping (1.5 etc. allowed)
```

> Run it in a real Terminal window so `sudo` can prompt for your password.

## Uninstall

```sh
sudo bash uninstall.sh
```

Removes the daemon and re-enables normal sleep. The `sleep` / `disksleep` /
`displaysleep` timers it set are left in place; change them with `pmset` if you
like.

## Configuration

- **Grace period (how long it stays awake)** — pass hours to the installer:
  `sudo bash install.sh 1.5`. Re-run with a new number anytime; it updates the
  daemon's config (`/usr/local/etc/clamshell-keepawake.conf`) and the matching
  `pmset` timers together.
- **Check interval** — `StartInterval` in `com.clamshellkeepawake.plist`.
  Default `60` (seconds); also the timing resolution. Edit, then re-run the
  installer.
- **Screen-off delay** — defaults to 10 min (or just under the grace period for
  very short durations). Change anytime with `sudo pmset -a displaysleep <min>`.

## Caveats

- **Manual sleep is blocked while a grace window is active.** Because
  `disablesleep` has to stay armed to catch a lid-close, the Apple menu's *Sleep*
  and the power button won't sleep the Mac during a window. Force it with:
  ```sh
  sudo pmset -a disablesleep 0 && pmset sleepnow
  ```
- All settings are system-wide and persist across reboots.
- The 60-second poll makes timing accurate to within about a minute.

## Files

| File | Installed to |
|---|---|
| `clamshell-awake.sh` | `/usr/local/bin/` |
| `com.clamshellkeepawake.plist` | `/Library/LaunchDaemons/` |
| `install.sh` / `uninstall.sh` | (run from the repo) |

Logs go to `/var/log/clamshell-awake.log`.

## License

[MIT](LICENSE)
