#!/bin/bash
# clamshell-awake.sh
#
# Delay any natural system sleep by 3 hours, then ALLOW (not force) it, and
# reset the delay whenever the computer is used again.
#
#   * Lid open ............... sleeps after 3h of no use (HID idle OR time since
#                              the lid was opened -- whichever is smaller, so a
#                              stale idle counter can't sleep us right after a
#                              wake/open). Any input resets it.
#   * Lid shut + monitor ..... stays awake, no countdown (clamshell work)
#   * Lid shut, no monitor ... sleeps 3h after entering this state (covers
#                              "unplug after clamshell" and "close with no
#                              monitor"); reset by opening the lid or
#                              reconnecting a monitor.
#
# `disablesleep` is held on so nothing sleeps early and a lid-close can't race
# us to sleep; at the 3h mark we set `disablesleep 0` and let macOS sleep on its
# own. Because we only *allow* sleep, anything macOS would normally keep awake
# for (playback, a download, screen sharing -- i.e. a power assertion) still
# keeps it awake past the 3h mark, which is correct: that sleep wasn't going to
# happen "normally" either.
#
# Run as root every 60s by com.clamshellkeepawake (LaunchDaemon).

# Grace period in seconds before the Mac may sleep. Default 3h; install.sh
# writes the user's chosen value to CONF, which overrides this default.
CONF="/usr/local/etc/clamshell-keepawake.conf"
HOLD=10800
[ -r "$CONF" ] && . "$CONF"

CLOSED_SINCE="/var/run/clamshell-awake.closed-since"
OPEN_SINCE="/var/run/clamshell-awake.open-since"
DONE="/var/run/clamshell-awake.done"
PREV_LID="/var/run/clamshell-awake.prev-lid"
now=$(date +%s)

if ioreg -r -k AppleClamshellState -d 4 | grep -q '"AppleClamshellState" = Yes'; then
    lid=closed
else
    lid=open
fi
prev=$(cat "$PREV_LID" 2>/dev/null || true)
echo "$lid" > "$PREV_LID"

if [ "$lid" = open ]; then
    # ---- Lid OPEN ----
    rm -f "$CLOSED_SINCE" "$DONE"
    if [ "$prev" != open ]; then
        echo "$now" > "$OPEN_SINCE"          # just opened/woke/first run = in use
    fi
    [ -f "$OPEN_SINCE" ] || echo "$now" > "$OPEN_SINCE"
    idle_ns=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF; exit}')
    idle=$(( ${idle_ns:-0} / 1000000000 ))
    since_open=$(( now - $(cat "$OPEN_SINCE") ))
    [ "$since_open" -lt "$idle" ] && idle=$since_open   # idle = min(HID idle, time open)
    if [ "$idle" -ge "$HOLD" ]; then
        pmset -a disablesleep 0
    else
        pmset -a disablesleep 1
    fi
else
    # ---- Lid SHUT (built-in panel off -> this counts external monitors) ----
    rm -f "$OPEN_SINCE"
    ext=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution:")
    if [ "$ext" -gt 0 ]; then
        rm -f "$CLOSED_SINCE" "$DONE"        # clamshell work: stay awake, no countdown
        pmset -a disablesleep 1
    elif [ -f "$DONE" ]; then
        :                                    # already released this session; hands off
    elif [ ! -f "$CLOSED_SINCE" ]; then
        echo "$now" > "$CLOSED_SINCE"        # just unplugged / closed with no monitor
        pmset -a disablesleep 1
    elif [ $(( now - $(cat "$CLOSED_SINCE") )) -ge "$HOLD" ]; then
        rm -f "$CLOSED_SINCE"
        touch "$DONE"
        pmset -a disablesleep 0              # 3h up: lid shut -> macOS sleeps now
    else
        pmset -a disablesleep 1
    fi
fi
