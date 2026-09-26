# pi-tools

A Claude Code plugin marketplace for Raspberry Pis. Its one plugin so far is **pi-baseline**, which
gives every Raspberry Pi the same baseline:

- **A persistent systemd journal, synced every 30 s.** Raspberry Pi OS keeps the journal in RAM, so
  after an unexpected power-off there are no logs to explain it; and journald's default 5 min sync
  loses the last minutes even when the journal is on disk.
- **pi-health.** Logs the 5 V supply voltage, the PMIC's core, 3.3 V and 1.8 V rails, SoC temperature
  and firmware throttle flags to the journal once a minute. Any line that reports a problem is logged
  as a warning.
- **pi-button.** Logs every press of the Pi 5's power button, to the journal and to an fsynced file
  of its own. A long press forces the power off without telling Linux, so that record is the only
  evidence that it happened.
- **pi-wake.** Keeps the Pi 5's RTC wake alarm armed ten minutes ahead, so a Pi that the power chip has
  switched off powers itself back on instead of waiting for someone to notice. A clean shutdown
  disarms it.
- **pi-heartbeat.** Pings a dead man's switch (Healthchecks.io or similar) once a minute, so you are
  told when the Pi goes quiet. Enabled only when given a URL.

When Claude Code starts on a Pi that doesn't have the baseline, the plugin asks Claude to offer to
install it.

## Setting up a new Pi

```
claude plugin marketplace add Thinmindt/pi-tools
claude plugin install pi-baseline@pi-tools
```

A Pi that added this marketplace when it was called `pi-baseline` runs
`claude plugin marketplace remove pi-baseline` first. What is already installed on the Pi (the
journal settings, the services, `/etc/pi-baseline` and `/var/lib/pi-baseline`) is untouched, and
the plugin keeps its name.

Then start Claude Code in any project and accept its offer to install. The installer needs sudo.

To install without Claude Code:

```
git clone https://github.com/Thinmindt/pi-tools
sudo bash pi-tools/skills/pi-baseline/install.sh [--heartbeat-url https://hc-ping.com/...]
```

## Checks

`scripts/check.sh` runs every gate, locally and in CI: the privacy check (the conventions plugin's
`check_private.sh`, copied unchanged, reading a gitignored `.private-terms`), the JSON files parse,
shellcheck, ruff and codespell. It needs `uv`; the tools run through `uvx` at pinned versions.

## Updating

After changing the kit, bump `version` in `.claude-plugin/plugin.json` and push. Then on each Pi, run
the following and restart Claude Code:

```
claude plugin marketplace update pi-tools
claude plugin update pi-baseline@pi-tools
```

## Reading the logs

```
journalctl -t pi-health -p warning      # problems only
journalctl -t pi-health --since today   # the trend
journalctl -t pi-button                 # power button presses; at each start, the last on record
cat /var/lib/pi-baseline/button.log     # every press and release, fsynced as it happened
journalctl -t pi-wake                   # did the last boot follow a clean shutdown; what powered it on
journalctl -b -1 -e                     # end of the previous boot, after a crash
pi-health --once                        # current reading
pi-wake --status                        # when the wake alarm is set for
```

The 5 V reading and the rails come from the Raspberry Pi 5's power chip. Older models log `5V=n/a`.
