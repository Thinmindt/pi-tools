#!/bin/bash
# Installs the Raspberry Pi baseline: a persistent journal and the pi-health and pi-button loggers.
# Safe to re-run.
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
install -m 0755 pi-button.py /usr/local/bin/pi-button
install -m 0644 pi-button.service /etc/systemd/system/pi-button.service
systemctl daemon-reload
systemctl enable pi-health.service pi-button.service
systemctl restart pi-health.service pi-button.service

systemctl --no-pager --lines=3 status pi-health.service pi-button.service
