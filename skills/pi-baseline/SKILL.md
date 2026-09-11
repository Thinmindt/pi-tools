---
name: pi-baseline
description: Baseline for every Raspberry Pi. Makes the systemd journal persistent and installs pi-health, which logs the 5 V supply voltage, SoC temperature and throttle flags every minute. Use when setting up a Raspberry Pi, starting a project that runs on one, or investigating why a Pi shut down or rebooted unexpectedly.
---

# Raspberry Pi baseline

Apply this to every Pi. Raspberry Pi OS keeps the journal in RAM by default, so an unexpected power-off
leaves no logs. A Pi 5 can switch itself off (solid red LED) because of a voltage fault or heat, and
without these logs there is nothing to show which one happened.

It installs two things:

1. **A persistent journal.** It writes `Storage=persistent` to
   `/etc/systemd/journald.conf.d/80-raspi-config-journal-storage.conf`, the file that raspi-config's
   logging option uses.
2. **pi-health.** `/usr/local/bin/pi-health` runs as `pi-health.service` and logs one line a minute:
   `5V=5.04V temp=54.9C throttled=0x0`.
   - A line is logged as a warning when the firmware reports undervoltage or throttling at that
     moment, or when the 5 V input drops below 4.75 V (the USB minimum).
   - At startup it also logs the bootloader's reset reason (`rsts`) and the power chip's
     `power_reset` flag, which is non-zero if the power chip cut power because of a voltage fault.

pi-health adds the trend. Undervoltage events themselves are already covered, because the kernel's
`rpi_volt` driver logs "Undervoltage detected!" at critical priority as soon as the firmware reports
one.

## Install

The installer needs root and is safe to re-run. If sudo asks for a password, the user has to run it
themselves, either with the `!` prefix or in a terminal:

    sudo bash ${CLAUDE_SKILL_DIR}/install.sh

It finishes with `systemctl status`. Check that the unit is `active (running)` and that there is a
`boot:` line followed by one sample line.

## Reading the logs

- `journalctl -t pi-health -p warning`: problems only
- `journalctl -t pi-health --since today`: the full trend
- `journalctl -k -g 'Undervoltage|Voltage normalised'`: the kernel's real-time undervoltage events
- `journalctl -b -1 -e`: the end of the previous boot, after a crash
- `pi-health --once`: the current reading, printed to the terminal

## Notes

- The 5 V reading comes from the Pi 5's power chip. Older models log `5V=n/a` and rely on the
  throttle flags.
- Set `PI_HEALTH_INTERVAL` (seconds) or `PI_HEALTH_MIN_VOLTS` in a unit drop-in to change the
  sampling interval or the warning threshold.
- A hard power cut can lose roughly the last 30 s of the journal. Critical messages are synced to
  disk immediately.
- If fake-hwclock is installed, it rewinds the clock at boot and journald logs "clock jumped
  backwards … rotating" once per boot. This is harmless.
