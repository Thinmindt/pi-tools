#!/bin/bash
# Installs the Raspberry Pi baseline: a persistent journal and the pi-health logger. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi

install -d /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' >/etc/systemd/journald.conf.d/80-raspi-config-journal-storage.conf
systemctl restart systemd-journald
journalctl --flush

install -m 0755 pi-health.sh /usr/local/bin/pi-health
install -m 0644 pi-health.service /etc/systemd/system/pi-health.service
systemctl daemon-reload
systemctl enable pi-health.service
systemctl restart pi-health.service

systemctl --no-pager --lines=3 status pi-health.service
