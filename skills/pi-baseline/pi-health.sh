#!/bin/bash
# Logs the Raspberry Pi's 5 V input, SoC temperature, firmware throttle flags and the main PMIC rails
# once per interval. Under systemd each line carries a syslog priority prefix; lines reporting a
# problem are warnings.
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
    local rsts power_reset kind=""
    rsts=$(dt_hex /proc/device-tree/chosen/bootloader/rsts)
    power_reset=$(dt_hex /proc/device-tree/chosen/power/power_reset)
    if [ -n "$rsts" ]; then
        if (( 16#$rsts & 0x20 )); then kind=" (warm reboot: software or watchdog)"; else kind=" (power-on)"; fi
    fi
    if [ -n "$power_reset" ] && [ $((16#$power_reset)) -ne 0 ]; then
        log 4 "boot: PMIC cut power for a voltage fault before this boot (power_reset=0x$power_reset rsts=0x${rsts:-n/a}$kind)"
    else
        log 6 "boot: power_reset=0x${power_reset:-n/a} rsts=0x${rsts:-n/a}$kind"
    fi
}

# Prints: EXT5V_V VDD_CORE_V VDD_CORE_A 3V3_SYS_V 3V3_SYS_A 1V8_SYS_V 1V8_SYS_A, or nothing on a Pi
# whose firmware has no PMIC ADC.
rails() {
    vcgencmd pmic_read_adc 2>/dev/null | awk '
        { split($2, a, "="); v[$1] = a[2] + 0 }
        END { if ("EXT5V_V" in v) printf "%.2f %.3f %.2f %.2f %.2f %.2f %.2f\n",
                  v["EXT5V_V"], v["VDD_CORE_V"], v["VDD_CORE_A"], v["3V3_SYS_V"], v["3V3_SYS_A"], v["1V8_SYS_V"], v["1V8_SYS_A"] }'
}

sample() {
    local throttled temp flags="" level=6 volts="" core="" v33="" v18=""
    local ext core_v core_a v33_v v33_a v18_v v18_a
    throttled=$(vcgencmd get_throttled | cut -d= -f2)
    temp=$(awk '{printf "%.1f", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp)
    if read -r ext core_v core_a v33_v v33_a v18_v v18_a < <(rails); then
        volts=$ext
        core=" core=${core_v}V/${core_a}A"
        v33=" 3v3=${v33_v}V/${v33_a}A"
        v18=" 1v8=${v18_v}V/${v18_a}A"
    fi
    (( throttled & 0x1 )) && flags+=" UNDERVOLTAGE"
    [ -n "$volts" ] && awk -v v="$volts" -v min="$MIN_VOLTS" 'BEGIN {exit !(v < min)}' && flags+=" LOW-5V"
    (( throttled & 0xe )) && flags+=" THROTTLED"
    [ -n "$flags" ] && level=4
    log "$level" "5V=${volts:-n/a}V temp=${temp}C throttled=$throttled$core$v33$v18$flags"
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
