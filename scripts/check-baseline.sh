#!/bin/bash
# SessionStart hook: on a Raspberry Pi that lacks the baseline, tell Claude to offer installing it.
grep -qs 'Raspberry Pi' /proc/device-tree/model || exit 0

missing=()
[ -e "/var/log/journal/$(cat /etc/machine-id)/system.journal" ] || missing+=("persistent journal")
systemctl is-active --quiet pi-health.service || missing+=("pi-health logger")
systemctl is-enabled --quiet pi-button.service 2>/dev/null || missing+=("pi-button logger")
[ ${#missing[@]} -eq 0 ] && exit 0

echo "This Raspberry Pi is missing the pi-baseline: ${missing[*]}. Before other setup work, offer to install it using the pi-baseline skill."
