#!/bin/bash
# Logs the Raspberry Pi's 5 V input, SoC temperature and firmware throttle flags once per interval.
# Under systemd each line carries a syslog priority prefix; lines reporting a problem are warnings.
set -u

INTERVAL=${PI_HEALTH_INTERVAL:-60}
MIN_VOLTS=${PI_HEALTH_MIN_VOLTS:-4.75}

log() {
    local level=$1
    shift
    if [ -t 1 ]; then echo "$*"; else echo "<$level>$*"; fi
}

dt_hex() {
    [ -r "$1" ] && od -An -tx1 "$1" | tr -d ' \n'
}

boot_report() {
    local rsts power_reset
    rsts=$(dt_hex /proc/device-tree/chosen/bootloader/rsts)
    power_reset=$(dt_hex /proc/device-tree/chosen/power/power_reset)
    if [ -n "$power_reset" ] && [ $((16#$power_reset)) -ne 0 ]; then
        log 4 "boot: PMIC cut power for a voltage fault before this boot (power_reset=0x$power_reset rsts=0x${rsts:-n/a})"
    else
        log 6 "boot: power_reset=0x${power_reset:-n/a} rsts=0x${rsts:-n/a}"
    fi
}

sample() {
    local throttled volts temp flags="" level=6
    throttled=$(vcgencmd get_throttled | cut -d= -f2)
    volts=$(vcgencmd pmic_read_adc EXT5V_V 2>/dev/null | awk -F= '/EXT5V_V/ {printf "%.2f", $2}')
    temp=$(awk '{printf "%.1f", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp)
    (( throttled & 0x1 )) && flags+=" UNDERVOLTAGE"
    [ -n "$volts" ] && awk -v v="$volts" -v min="$MIN_VOLTS" 'BEGIN {exit !(v < min)}' && flags+=" LOW-5V"
    (( throttled & 0xe )) && flags+=" THROTTLED"
    [ -n "$flags" ] && level=4
    log "$level" "5V=${volts:-n/a}V temp=${temp}C throttled=$throttled$flags"
}

boot_report
if [ "${1:-}" = --once ]; then
    sample
    exit
fi
while :; do
    sample
    sleep "$INTERVAL"
done
