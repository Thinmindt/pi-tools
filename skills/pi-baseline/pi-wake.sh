#!/bin/bash
# Keeps an RTC wake alarm armed so a Raspberry Pi 5 that the power chip has switched off powers itself
# back on. Disarms on a clean stop, so a deliberate halt stays halted.
set -u

INTERVAL=${PI_WAKE_INTERVAL:-300}
HORIZON=${PI_WAKE_HORIZON:-600}
RTC=${PI_WAKE_RTC:-/sys/class/rtc/rtc0}
STATE=${STATE_DIRECTORY:-/var/lib/pi-baseline}/wakealarm

log() {
    local level=$1
    shift
    if [ -t 1 ]; then echo "$*"; else echo "<$level>$*"; fi
}

rtc_now() {
    cat "$RTC/since_epoch"
}

arm() {
    if ! { echo 0 >"$RTC/wakealarm" && echo "+$HORIZON" >"$RTC/wakealarm"; } 2>/dev/null; then
        log 4 "could not arm the RTC wake alarm"
        return 1
    fi
    echo $(( $(rtc_now) + HORIZON )) >"$STATE"
}

disarm() {
    echo 0 >"$RTC/wakealarm" 2>/dev/null
    rm -f "$STATE"
}

# The state file survives only an unclean end: a clean stop removes it in disarm().
boot_report() {
    [ -e "$STATE" ] || return 0
    local armed_for booted_at
    armed_for=$(cat "$STATE")
    booted_at=$(( $(rtc_now) - $(cut -d. -f1 /proc/uptime) ))
    if [ "$booted_at" -ge $((armed_for - 5)) ] && [ "$booted_at" -le $((armed_for + 120)) ]; then
        log 5 "boot: the previous boot ended without a clean shutdown; the RTC wake alarm powered this Pi back on"
    else
        log 5 "boot: the previous boot ended without a clean shutdown; the RTC wake alarm set for $(date -d "@$armed_for" '+%F %T') did not power it on (booted $(date -d "@$booted_at" '+%F %T'))"
    fi
}

case "${1:-}" in
    --disarm)
        disarm
        exit
        ;;
    --status)
        if [ -e "$STATE" ]; then
            echo "armed for $(date -d "@$(cat "$STATE")" '+%F %T'), sysfs: $(cat "$RTC/wakealarm")"
        else
            echo "not armed"
        fi
        exit
        ;;
esac

boot_report
trap 'disarm; exit 0' TERM INT
log 6 "arming the RTC wake alarm every $INTERVAL s, $HORIZON s ahead"
while :; do
    arm
    sleep "$INTERVAL" &
    wait $!
done
