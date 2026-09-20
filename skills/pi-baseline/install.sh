#!/bin/bash
# Installs the Raspberry Pi baseline: a persistent journal, the pi-health and pi-button loggers, the
# pi-wake alarm and, given a URL, the pi-heartbeat ping. Safe to re-run.
#
#   sudo bash install.sh [--heartbeat-url URL]
set -euo pipefail
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi

heartbeat_url=""
while [ $# -gt 0 ]; do
    case "$1" in
        --heartbeat-url) heartbeat_url=$2; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

install -d /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' >/etc/systemd/journald.conf.d/80-raspi-config-journal-storage.conf
printf '[Journal]\nSyncIntervalSec=30s\n' >/etc/systemd/journald.conf.d/81-pi-baseline-journal-sync.conf
systemctl restart systemd-journald
journalctl --flush

install -m 0755 pi-health.sh /usr/local/bin/pi-health
install -m 0644 pi-health.service /etc/systemd/system/pi-health.service
install -m 0755 pi-button.py /usr/local/bin/pi-button
install -m 0644 pi-button.service /etc/systemd/system/pi-button.service
install -m 0755 pi-wake.sh /usr/local/bin/pi-wake
install -m 0644 pi-wake.service /etc/systemd/system/pi-wake.service
install -m 0644 pi-heartbeat.service /etc/systemd/system/pi-heartbeat.service
install -m 0644 pi-heartbeat.timer /etc/systemd/system/pi-heartbeat.timer

if [ -n "$heartbeat_url" ]; then
    install -d -m 0755 /etc/pi-baseline
    (umask 077; printf 'HEARTBEAT_URL=%s\n' "$heartbeat_url" >/etc/pi-baseline/heartbeat.env)
fi

systemctl daemon-reload
systemctl enable pi-health.service pi-button.service pi-wake.service
systemctl restart pi-health.service pi-button.service pi-wake.service
if [ -e /etc/pi-baseline/heartbeat.env ]; then
    systemctl enable --now pi-heartbeat.timer
    systemctl start pi-heartbeat.service
else
    echo "no heartbeat configured; re-run with --heartbeat-url URL to enable it"
fi

systemctl --no-pager --lines=3 status pi-health.service pi-button.service pi-wake.service pi-heartbeat.timer || true
