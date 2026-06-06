# clamshell-keepawake: menu bar item (SwiftBar)

**Date:** 2026-06-06
**Status:** approved, ready for implementation plan

## Goal

A macOS menu bar item that lets a user (a) confirm at a glance the tool is
running as intended and (b) pause/resume and adjust the grace period without the
terminal. Reuses the existing `clamshell-keepawake` CLI as the single source of
truth.

## Decisions (locked)

- **Vehicle:** SwiftBar plugin. The plugin is a thin wrapper that calls a new
  `menu` subcommand; all logic lives in the CLI.
- **Privilege:** scoped, passwordless `sudoers` drop-in so menu actions are
  instant. Opt-in via `menu-setup`, never folded into base `install`.
- **Pause:** a single Pause ↔ Resume toggle, always indefinite (until toggled
  back). No durations in the menu. (The CLI keeps its timed `pause 30m` for
  terminal users; the menu just never uses it.)
- **No state descriptors:** header is `Active` / `Paused` / `Not installed` —
  no lid/display reporting.

## Architecture — four pieces

1. **`menu` subcommand** (new, in `clamshell-keepawake`) — read-only, no root.
   Emits SwiftBar-format output: a title line, `---`, then info + action lines.
   Reuses `hold_seconds`, `lid_state`, `remaining_seconds` (see below), and the
   pause-file read.
2. **SwiftBar plugin file** — `clamshell-keepawake.5s.sh`, a two-line wrapper
   (`exec /usr/local/bin/clamshell-keepawake menu`). Generated into SwiftBar's
   plugin folder by `menu-setup` (not shipped in the repo), mirroring how
   `install` generates the plist.
3. **sudoers drop-in** — `/etc/sudoers.d/clamshell-keepawake`, scoped to the
   invoking user and the three exact menu actions.
4. **`menu-setup` / `menu-remove`** (new, root) — opt-in install/uninstall of
   pieces 2 + 3. The base `uninstall` also runs this cleanup if present.

## Targeted refactor (within scope)

Factor a `remaining_seconds()` helper that returns the integer seconds until the
Mac may sleep, or empty when there's no active countdown. `awake_remaining`
(used by `status`) is rewritten to build its sentence from it; `menu` uses
`fmt_dur` on it for the compact title. This keeps `status`, the title, and the
menu body in agreement and removes duplicated countdown logic.

## `menu` output

### Title (menu-bar text)

| Condition | Title |
|---|---|
| Not installed (no plist) | `☀ –` |
| Paused (pause file present) | `⏸ paused` |
| Active, countdown running | `☀ 2h14m` (`fmt_dur` of `remaining_seconds`, compact) |
| Active, holding but no countdown (clamshell+monitor) | `☀ on` |
| Active, not currently holding (SleepDisabled=0) | `☀ off` |

### Dropdown — active (not paused)

```
☀ 2h14m
---
Active
Grace period: 3 h
Sleeps in ~2h 14m            (omitted when remaining_seconds is empty)
---
Pause                        -> sudo clamshell-keepawake pause
Set grace period
--1 hour                     -> sudo clamshell-keepawake set 1
--2 hours                    -> sudo clamshell-keepawake set 2
--3 hours                    -> sudo clamshell-keepawake set 3
--4 hours                    -> sudo clamshell-keepawake set 4
--Custom…                    -> clamshell-keepawake set-prompt
---
Open log                     -> open /var/log/clamshell-keepawake.log
Refresh                      -> SwiftBar refresh
```

### Dropdown — paused

Identical, except: title `⏸ paused`; header `Paused`; the countdown line is
omitted; the toggle slot shows **Resume** → `sudo clamshell-keepawake resume`.

### Dropdown — not installed

```
☀ –
---
Not installed
Run: sudo clamshell-keepawake install
```

### SwiftBar item encoding

Action items use SwiftBar params, e.g.:

```
Pause | bash=/usr/bin/sudo param1=/usr/local/bin/clamshell-keepawake param2=pause terminal=false refresh=true
```

Submenu items are prefixed with `--`. Info lines (`Active`, `Grace period: …`)
are plain text with no `bash=`, so they're non-clickable.

### `set-prompt` helper (for Custom…)

A small subcommand run as the user (no sudo): pops an AppleScript dialog
(`osascript … display dialog "Hours to stay awake:" default answer "3"`),
then runs `sudo clamshell-keepawake set <input>`. Folding the prompt into a
subcommand avoids fragile osascript quoting inside SwiftBar params. Invalid/empty
input: do nothing (the dialog Cancel path) or let `set` reject it.

## Privilege & security

`menu-setup` writes `/etc/sudoers.d/clamshell-keepawake`:

```
<SUDO_USER> ALL=(root) NOPASSWD: /usr/local/bin/clamshell-keepawake pause, \
                                 /usr/local/bin/clamshell-keepawake resume, \
                                 /usr/local/bin/clamshell-keepawake set *
```

- Written to a temp file, validated with `visudo -cf <tmp>` **before** moving
  into place (a malformed sudoers file can break `sudo` system-wide); mode
  `0440`, owner `root:wheel`.
- Scoped to the invoking user via `$SUDO_USER`. If `menu-setup` runs as bare
  root with no `$SUDO_USER`, it skips the sudoers file and instructs the user to
  run it via `sudo` from their own account.
- Only `set` carries a wildcard (its numeric arg); `pause`/`resume` are exact.
  Blast radius: this user can pause/resume and change the grace period without a
  password — exactly the menu's function.
- Removed by `menu-remove` and by `uninstall`.

## `menu-setup` / `menu-remove`

`menu-setup` (root):
1. `need_root`; require `$SUDO_USER` (else skip sudoers with guidance).
2. Write + validate the sudoers drop-in.
3. Find SwiftBar's plugin dir as the user:
   `sudo -u "$SUDO_USER" defaults read com.ameba.SwiftBar PluginDirectory`.
   If found: write `clamshell-keepawake.5s.sh` there, `chmod +x`,
   `chown "$SUDO_USER"`, and refresh
   (`sudo -u "$SUDO_USER" open -g "swiftbar://refreshallplugins"`).
   If not found: report that SwiftBar isn't installed/configured and how to set
   a plugin folder, then re-run. (The sudoers grant is already in place.)

`menu-remove` (root): delete the sudoers drop-in and the plugin file.

`uninstall`: after its existing steps, remove the same two artifacts if present
so a full uninstall leaves nothing behind.

## Refresh cadence & cost

Filename interval `5s` keeps the title countdown lively. `menu` runs the only
expensive call (`system_profiler SPDisplaysDataType`) **only when the lid is
shut**; in the common lid-open case it touches just `ioreg`/`pmset`/state files,
so 5s polling is cheap. Rename the plugin to change the interval.

## Repo changes

- `clamshell-keepawake`: add `menu`, `menu-setup`, `menu-remove`, `set-prompt`
  subcommands and the `remaining_seconds` helper refactor; extend the dispatch
  `case` and `uninstall` cleanup. No separate plugin file committed (generated).
- `README.md`: a "Menu bar (SwiftBar)" section — install SwiftBar, run
  `sudo clamshell-keepawake menu-setup`, what the menu shows, and `menu-remove`.

## Testing — honest limits

- `clamshell-keepawake menu` is read-only: run it and eyeball the SwiftBar text
  across states by toggling the pause/state files — no root needed.
- `bash -n` clean.
- `menu-setup`/`menu-remove` need root + a live SwiftBar install: verified by
  inspection + an on-device check (run setup → item appears → Pause flips title
  to `⏸` → Resume → Set 2 → title shows the new countdown → `menu-remove`).
- `visudo -cf` on the generated sudoers content can be checked in isolation.
- No automated coverage of the SwiftBar runtime.

## Optional / easy to flip

- Toggle presentation: flipping `Pause`/`Resume` label (chosen) vs a checkbox
  `✓ Keep awake`. One-line change.
- `Custom…` could be dropped for presets-only.
