#!/bin/bash
# Install the clamshell-keepawake LaunchDaemon and supporting pmset settings.
#
# Usage (run with sudo from the repo directory):
#   sudo bash install.sh [HOURS]
#
# HOURS = how long the Mac stays awake before it's allowed to sleep (decimals
# allowed, e.g. 1.5). If omitted you'll be prompted; the default is 3.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.clamshellkeepawake"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
CONF="/usr/local/etc/clamshell-keepawake.conf"

# --- Pick the duration -----------------------------------------------------
HOURS="${1:-}"
if [ -z "$HOURS" ]; then
    if [ -e /dev/tty ]; then
        printf 'Hours to stay awake before sleeping [3]: ' > /dev/tty
        read -r HOURS < /dev/tty || true
    fi
    HOURS="${HOURS:-3}"
fi
if ! awk -v h="$HOURS" 'BEGIN{exit !(h+0>0)}'; then
    echo "error: HOURS must be a positive number (got '${HOURS}')" >&2
    exit 1
fi

HOLD_SECONDS=$(awk -v h="$HOURS" 'BEGIN{printf "%d", (h*3600)+0.5}')
SLEEP_MIN=$(awk -v s="$HOLD_SECONDS" 'BEGIN{m=int((s/60)+0.5); if(m<1)m=1; print m}')
DISP_MIN=$(awk -v m="$SLEEP_MIN" 'BEGIN{ if(m>10) print 10; else {d=m-1; if(d<1)d=1; print d} }')

# --- Install files ---------------------------------------------------------
install -d -m 755 /usr/local/bin
install -m 755 -o root -g wheel "${SRC_DIR}/clamshell-awake.sh" /usr/local/bin/clamshell-awake.sh
install -m 644 -o root -g wheel "${SRC_DIR}/${LABEL}.plist" "${PLIST}"

# Write the chosen grace period where the daemon reads it.
install -d -m 755 /usr/local/etc
printf 'HOLD=%s\n' "$HOLD_SECONDS" > "${CONF}"
chmod 644 "${CONF}"

# --- pmset -----------------------------------------------------------------
# Idle sleep timer == grace period, so the lid-open case sleeps when the daemon
# releases `disablesleep`. disksleep matched (keeps the config consistent and
# silences pmset's "disk sleep" advisory).
pmset -a sleep "${SLEEP_MIN}"
pmset -a disksleep "${SLEEP_MIN}"
# Screen off after DISP_MIN min idle while the system stays awake.
pmset -a displaysleep "${DISP_MIN}"

# --- Clear stale state & (re)load ------------------------------------------
rm -f /var/run/clamshell-awake.closed-since \
      /var/run/clamshell-awake.open-since \
      /var/run/clamshell-awake.prev-lid \
      /var/run/clamshell-awake.done

launchctl bootout system "${PLIST}" 2>/dev/null || true
launchctl bootstrap system "${PLIST}"

# --- Summary ---------------------------------------------------------------
echo "Installed and loaded ${LABEL}."
awake=$(pmset -g | awk '/SleepDisabled/{print $2; exit}')
if [ "$awake" = 1 ]; then
    awake_human="yes -- a keep-awake window is active right now"
else
    awake_human="no -- normal sleep is in effect right now"
fi

echo
echo "What's now in effect:"
echo "  - Grace period: stays awake ${HOURS} hour(s) before it's allowed to sleep."
echo "  - Lid open, left alone: screen off after ${DISP_MIN} min; sleeps after the"
echo "    grace period. Using it again resets the timer."
echo "  - Lid shut WITH a monitor (clamshell): stays awake, no timer."
echo "  - Lid shut with NO monitor (closed, or monitor unplugged): stays awake the"
echo "    grace period, then sleeps. Opening the lid or reconnecting a monitor resets it."
echo "  - Keeping the Mac awake right now? ${awake_human}"
echo "  - A background helper re-checks every 60 seconds."
echo
echo "Change the duration later by re-running: sudo bash install.sh <hours>"
