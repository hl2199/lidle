# clamshell-keepawake: unified CLI (Option A)

**Date:** 2026-06-06
**Status:** approved, implementing

## Goal

Replace the scattered `install.sh` / `uninstall.sh` / `clamshell-awake.sh` /
`com.clamshellkeepawake.plist` set with a single `clamshell-keepawake` command,
and add a real *usage* interface — `status` and `pause` — so a user can see and
control the tool after install instead of reading the log.

## Shape

One bash file, `clamshell-keepawake`, installed to `/usr/local/bin/`. A
`case "$1"` dispatcher routes to functions:

| Command | Root? | Purpose |
|---|---|---|
| `install [hours]` | yes | Copy self to PATH, write conf, generate plist (→ `clamshell-keepawake _tick`), set `pmset` timers, clear state, load daemon. Prompts for hours if omitted (default 3). |
| `uninstall` | yes | Boot out daemon, remove plist + installed binary + state files, re-enable sleep. |
| `set <hours>` | yes | Rewrite conf + `pmset` timers, clear state, re-arm. (install minus the file copy) |
| `pause [dur]` | yes | Write pause-state; `pause` = until `resume`, `pause 30m` = auto-expire. Lets macOS sleep normally meanwhile. |
| `resume` | yes | Clear pause-state, re-arm. |
| `status` | no | Daemon installed?, grace period, lid, paused?, keeping-awake-now? + best-effort time left. |
| `logs` | no | `tail -f /var/log/clamshell-keepawake.log` |
| `_tick` | (root, via launchd) | Hidden per-60s worker: the existing logic verbatim + a pause guard at the top. |
| `help` / none | no | Usage. |

## Repo after

Single binary story. Delete `clamshell-awake.sh`, `install.sh`, `uninstall.sh`,
`com.clamshellkeepawake.plist`; their logic moves into `clamshell-keepawake`
(the plist is generated inline by `install`). Repo ends as:
`clamshell-keepawake`, `README.md` (rewritten), `LICENSE`, `.gitignore`,
this `docs/` tree. State/log files rename `clamshell-awake.*` →
`clamshell-keepawake.*` (no installed base to migrate — initial commit).

## Pause mechanics

New state file `/var/run/clamshell-keepawake.paused`, holding either
`indefinite` or an epoch expiry. `_tick` guard, before any lid logic:

```
if paused file exists:
    if it holds a number and now >= it:  rm it        # expired → fall through
    else:                                pmset -a disablesleep 0; exit 0
```

`pause` / `resume` / `set` each run `_tick` once inline so the effect is
instant instead of waiting up to 60s. The existing tick state machine is
otherwise untouched. `pause` is also the clean escape hatch for the old
"manual sleep is blocked" caveat: pause, then sleep.

## Root & errors

`need_root` guards the mutating commands and prints the exact fix
(`sudo clamshell-keepawake <cmd>`); no silent re-exec. `status`/`logs` stay
read-only (the `/var/run` state files and `pmset -g` are world-readable).
`install` skips the self-copy when already running from `/usr/local/bin`
(avoids `cp`-onto-itself).

## Shell-safety note

Top-level `set -uo pipefail` (no `-e`): the tick logic has several
`cond && action` lines and a `grep -c` that exits non-zero on a 0 count, all of
which are correct without `-e` but would abort under it. Explicit `|| die`
guards the install/uninstall/set steps that must succeed.

## Testing — honest limits

`_tick` depends on root, `pmset`, and live lid/display hardware, so it is not
unit-testable in CI. Verification:

- `bash -n` clean (syntax).
- `help` and `status` (read-only) run correctly with no root on this Mac.
- `pause` with no root prints the `need_root` hint.
- Root paths (`install` / `_tick` / `uninstall`) verified by inspection + an
  on-device checklist: install → `status` → `pause 1m` → watch status flip →
  auto-resume → `set 2` → `uninstall`.

No automated coverage of the hardware path is claimed.
