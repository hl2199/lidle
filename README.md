# lidle

I always find that I'm running things on my laptop and need to keep it running for a while (but not indefinitely!) even as I'm on the move, but Mac of course sleeps the system as soon as the lid closes. The native option 'caffeinate' needs to be triggered every time; `pmset` is persistent, but disables sleep indefinitely. `Amphetamine` can be conditionally triggered but cannot let the system sleep if your process cannot be reliably assigned to a non-persisting trigger. 

**`lidle` does a single thing-- it keeps your MacBook running for an additional awake window whenever it would otherwise sleep, and it is a persistent setting.** It enables:

- additional awake window on lid close
- additional awake window on idle trigger
- additional awake window on monitor disconnect in clamshell mode
- indefinite awake as long as monitor connected (native behavior)

`lidle` does not touch your display sleep options, letting the display sleep as normal to conserve battery. Your Mac's display sleep habits can be set as usual in system settings. 

## Install

`lidle` requires **administrator access** as it installs a small system-wide background service.

```sh
git clone https://github.com/hl2199/lidle.git
cd lidle
sudo ./lidle install          # enter number of hours to stay awake for (fractions allowed)
```

`lidle` will now run in the background and give your Mac an additional awake window. 

## Using lidle

`lidle` can be installed as a menu bar item or toggled from the command line.

### Menu bar

`lidle`'s menu bar option is implemented through [SwiftBar](https://swiftbar.app). It adds a narrowly-scoped, passwordless `sudo` rule that runs lidle's own pause / resume / set / quit / menu-remove.

SwiftBar can be installed by running

```sh
brew install swiftbar
```

or alternatively, when you run `sudo lidle install`, `lidle` will install it for you if you choose to go ahead with the menu bar option. You can always add the menu bar option later if you choose to skip it at install by running

```sh
sudo lidle menu-setup            # installs SwiftBar via Homebrew if it's missing
```

The menu item shows **☀** while lidle is holding your Mac awake and **☾** when it isn't (off or paused). Click it to
- set a new awake window (1h / 3h / 8h / indefinite, or a custom value)
- pause the tool for a while, or until you resume (lets the Mac sleep normally)
- open the log (to make sure the tool is running as expected)
- remove the menu bar item, or exit lidle entirely

Remove the menu bar item (leaving terminal-only control) using `sudo lidle menu-remove`. Add it back using `sudo lidle menu-setup`. 

### Command line

`lidle` can also be configured directly in the command line without needing to install the menu bar option. 

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
| `lidle version` | no | Print the version. |
| `lidle help` | no | Show usage. |

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
`/Library/LaunchDaemons/com.lidle.plist`, config `/usr/local/etc/lidle.conf`, the
saved sleep-timer snapshot `/usr/local/etc/lidle.saved-pmset`, log
`/var/log/lidle.log`, and runtime state under `/var/run/lidle.*`. The menu bar item
also adds a sudoers rule `/etc/sudoers.d/lidle`, a SwiftBar plugin, and a per-user
login agent `~/Library/LaunchAgents/com.lidle.menu.plist`.

## License

[MIT](LICENSE)
