# pi-baseline

A Claude Code plugin that gives every Raspberry Pi the same baseline:

- **A persistent systemd journal.** Raspberry Pi OS keeps the journal in RAM, so after an unexpected
  power-off there are no logs to explain it.
- **pi-health.** Logs the 5 V supply voltage, SoC temperature and firmware throttle flags to the
  journal once a minute. Any line that reports a problem is logged as a warning.
- **pi-button.** Logs every press of the Pi 5's power button. A long press forces the power off
  without telling Linux, so this line is the only record that it happened.

When Claude Code starts on a Pi that doesn't have the baseline, the plugin asks Claude to offer to
install it.

## Setting up a new Pi

```
claude plugin marketplace add Thinmindt/pi-baseline
claude plugin install pi-baseline@pi-baseline
```

Then start Claude Code in any project and accept its offer to install. The installer needs sudo.

To install without Claude Code:

```
git clone https://github.com/Thinmindt/pi-baseline
sudo bash pi-baseline/skills/pi-baseline/install.sh
```

## Updating

After changing the kit, bump `version` in `.claude-plugin/plugin.json` and push. Then on each Pi, run
the following and restart Claude Code:

```
claude plugin marketplace update pi-baseline
claude plugin update pi-baseline@pi-baseline
```

## Reading the logs

```
journalctl -t pi-health -p warning      # problems only
journalctl -t pi-health --since today   # the trend
journalctl -t pi-button                 # power button presses
journalctl -b -1 -e                     # end of the previous boot, after a crash
pi-health --once                        # current reading
```

The 5 V reading comes from the Raspberry Pi 5's power chip. Older models log `5V=n/a`.
