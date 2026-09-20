---
name: pi-baseline
description: Baseline for every Raspberry Pi. Makes the systemd journal persistent and installs pi-health, which logs the 5 V supply, PMIC rails, SoC temperature and throttle flags every minute; pi-button, which logs power button presses; pi-wake, which keeps an RTC alarm armed so a Pi 5 powers itself back on after an unexpected power-off; and pi-heartbeat, which pings a dead man's switch so someone is told when the Pi goes quiet. Use when setting up a Raspberry Pi, starting a project that runs on one, or investigating why a Pi shut down or rebooted unexpectedly.
---

# Raspberry Pi baseline

Apply this to every Pi. Raspberry Pi OS keeps the journal in RAM by default, so an unexpected power-off
leaves no logs. A Pi 5 can switch itself off (solid red LED) because of a voltage fault or heat, and
without these logs there is nothing to show which one happened.

It installs five things:

1. **A persistent journal that syncs every 30 s.** `Storage=persistent` goes in
   `/etc/systemd/journald.conf.d/80-raspi-config-journal-storage.conf`, the file that raspi-config's
   logging option uses, and `SyncIntervalSec=30s` in `81-pi-baseline-journal-sync.conf`. Without the
   second file journald syncs every 5 min, and a hard power cut loses up to that much of the journal's
   tail: the last lines before the cut are exactly the ones an investigation needs.
2. **pi-health.** `/usr/local/bin/pi-health` runs as `pi-health.service` and logs one line a minute:
   `5V=5.04V temp=54.9C throttled=0x0 core=0.864V/3.22A 3v3=3.32V/0.10A 1v8=1.81V/0.13A`.
   - A line is logged as a warning when the firmware reports undervoltage or throttling at that
     moment, or when the 5 V input drops below 4.75 V (the USB minimum).
   - The rails are the PMIC's own readings of the SoC core, 3.3 V and 1.8 V supplies. A rail that
     drifts before a power-off points at the board rather than the supply.
   - At startup it also logs the bootloader's reset reason (`rsts`, with "power-on" or "warm reboot"
     spelled out) and the power chip's `power_reset` flag, which is non-zero if the power chip cut
     power because of a voltage fault.
3. **pi-button.** `/usr/local/bin/pi-button` runs as `pi-button.service` and logs each press and
   release of the Pi 5's power button (the `pwr_button` input device).
   - Holding the button for several seconds makes the power chip cut power without telling Linux.
     The Pi is left off with a solid red LED, and nothing else records the cause.
   - The press is logged at critical priority, which journald syncs to disk at once, so the line
     survives the power cut.
   - On models without the button it logs that once and exits.
4. **pi-wake.** `/usr/local/bin/pi-wake` runs as `pi-wake.service` and keeps the RTC wake alarm
   armed 10 minutes ahead, re-arming every 5 minutes. The Pi 5 powers on from the power chip's
   standby state when the alarm fires, so a Pi that switched itself off comes back within 10 minutes
   instead of waiting for someone to press the button. A clean stop or shutdown disarms the alarm,
   so a deliberate `halt` stays halted. At startup it reports whether the previous boot ended
   cleanly and, if not, whether the alarm is what powered the Pi back on. On a model without an RTC
   the unit's condition fails and it stays inactive.
5. **pi-heartbeat.** `pi-heartbeat.timer` fetches a URL once a minute. Point it at a dead man's
   switch such as Healthchecks.io and the service alerts you when the pings stop. The URL is a
   secret: it lives in `/etc/pi-baseline/heartbeat.env` (root-only), never in this repository. The
   timer is enabled only when that file exists.

pi-health adds the trend. Undervoltage events themselves are already covered, because the kernel's
`rpi_volt` driver logs "Undervoltage detected!" at critical priority as soon as the firmware reports
one.

## Install

The installer is `install.sh` in this skill's directory (the plugin root's `skills/pi-baseline/`, or
the same path in a clone of the repo). It needs root and is safe to re-run. If sudo asks for a
password, the user has to run it themselves, either with the `!` prefix or in a terminal:

    sudo bash <skill directory>/install.sh

To enable the heartbeat, pass the ping URL once; it is kept in `/etc/pi-baseline/heartbeat.env`:

    sudo bash <skill directory>/install.sh --heartbeat-url https://hc-ping.com/...

On Healthchecks.io set the check's period to 1 minute and its grace time to a few minutes; the alert
arrives when period plus grace have passed with no ping.

It finishes with `systemctl status`. Check that pi-health, pi-button and pi-wake are `active (running)`,
that pi-health shows a `boot:` line followed by one sample line, that pi-button shows
`watching /dev/input/…`, and that pi-wake shows `arming the RTC wake alarm`. On a model without the
power button pi-button is `inactive (dead)` instead, and on one without an RTC so is pi-wake.

## Reading the logs

- `journalctl -t pi-health -p warning`: problems only
- `journalctl -t pi-health --since today`: the full trend
- `journalctl -k -g 'Undervoltage|Voltage normalised'`: the kernel's real-time undervoltage events
- `journalctl -t pi-button`: power button presses
- `journalctl -t pi-wake`: whether each boot followed a clean shutdown, and what powered the Pi on
- `journalctl -t pi-heartbeat`: failed pings (a successful one logs nothing)
- `journalctl -b -1 -e`: the end of the previous boot, after a crash
- `pi-health --once`: the current reading, printed to the terminal
- `pi-wake --status`: when the wake alarm is set for

## After an unexpected power-off

If the Pi was found off with a solid red LED, or came back on by itself, read:

- `journalctl -b -t pi-wake | head -1`: says whether the previous boot ended cleanly and whether the
  alarm powered the Pi on.
- `journalctl -b -1 -t pi-button`, the end of it:
  - `power button pressed` as the last line, with no `released` after it: the button was held until
    the power chip cut power.
  - A press and release followed by a normal shutdown sequence: a short press asked Linux to shut
    down. systemd-logind logs "Power key pressed short" as well.
  - Nothing near the end: the button was not involved. Check the `boot:` line of the next boot and
    the last pi-health samples, then suspect the power chip or the board.
- `journalctl -b -t pi-health | head -1`, the `boot:` line: `power_reset` non-zero means the power
  chip recorded a voltage fault; `rsts` says power-on or warm reboot. A warm reboot exactly 60 s after
  the journal's last line is the hardware watchdog (`RuntimeWatchdogSec=1min`) resetting a hung PID 1.

The journal's last timestamp is a lower bound: even at a 30 s sync interval the final lines before a
hard cut are lost. Anything the Pi writes more often, such as an application's per-frame log, dates
the cut more precisely.

## Testing pi-wake

Hold the power button until the LED turns solid red, then wait. The Pi should boot within 10 minutes
and pi-wake's first line should say the alarm powered it on. That is an unclean shutdown, like any
crash; do it when a few minutes of downtime are acceptable.

## Notes

- The 5 V reading comes from the Pi 5's power chip. Older models log `5V=n/a` and no rails, and rely
  on the throttle flags.
- Set `PI_HEALTH_INTERVAL` (seconds) or `PI_HEALTH_MIN_VOLTS` in a unit drop-in to change the
  sampling interval or the warning threshold; `PI_WAKE_INTERVAL` and `PI_WAKE_HORIZON` likewise.
- Critical messages are synced to disk immediately; everything else within the 30 s sync interval.
- If fake-hwclock is installed, it rewinds the clock at boot and journald logs "clock jumped
  backwards … rotating" once per boot. This is harmless, but it means early-boot timestamps are wrong
  until NTP syncs; pi-wake reads the RTC directly for that reason.
