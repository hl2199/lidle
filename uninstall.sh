#!/bin/bash
# Remove the clamshell-keepawake LaunchDaemon and re-enable normal sleep.
# Run with sudo:
#   sudo bash uninstall.sh
set -euo pipefail

LABEL="com.clamshellkeepawake"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"

launchctl bootout system "${PLIST}" 2>/dev/null || true
rm -f "${PLIST}" /usr/local/bin/clamshell-awake.sh
rm -f /var/run/clamshell-awake.closed-since \
      /var/run/clamshell-awake.open-since \
      /var/run/clamshell-awake.prev-lid \
      /var/run/clamshell-awake.done

# Re-enable normal sleep (otherwise the Mac could stay awake until reboot).
pmset -a disablesleep 0

echo "Removed ${LABEL} and re-enabled normal sleep."
echo "Note: the sleep / disksleep / displaysleep timers set during install were"
echo "left as-is. Adjust them with pmset if you want, e.g. 'sudo pmset -a displaysleep 2'."
