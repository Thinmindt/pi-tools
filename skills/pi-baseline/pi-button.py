#!/usr/bin/env python3
"""Logs every press and release of the Raspberry Pi 5 power button.

A press is logged at critical priority, which journald syncs to disk at once, and appended to a file
of its own with an explicit fsync, so a record survives the hard power-off that a long press causes
even if journald's sync loses the race to it.
"""

import os
import struct
import sys
from datetime import datetime
from pathlib import Path

BUTTON_NAME = "pwr_button"
INPUT_EVENT = struct.Struct("llHHi")
EV_KEY = 1
KEY_POWER = 116
CRITICAL, NOTICE, INFO = 2, 5, 6
RECORD = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/pi-baseline")) / "button.log"


def log(level: int, message: str) -> None:
    print(message if sys.stdout.isatty() else f"<{level}>{message}", flush=True)


def record(at: float, message: str) -> None:
    line = (
        f"{datetime.fromtimestamp(at).isoformat(timespec='milliseconds')} {message}\n"
    )
    try:
        with RECORD.open("a") as f:
            f.write(line)
            f.flush()
            os.fsync(f.fileno())
    except OSError as e:
        log(NOTICE, f"could not record to {RECORD}: {e}")


def last_recorded() -> str | None:
    try:
        lines = RECORD.read_text().splitlines()
    except OSError:
        return None
    return lines[-1] if lines else None


def find_button() -> Path | None:
    for name_file in Path("/sys/class/input").glob("event*/device/name"):
        if name_file.read_text().strip() == BUTTON_NAME:
            return Path("/dev/input") / name_file.parent.parent.name
    return None


def watch(device: Path) -> None:
    pressed_at = None
    with device.open("rb", buffering=0) as events:
        while data := events.read(INPUT_EVENT.size):
            seconds, micros, kind, code, value = INPUT_EVENT.unpack(data)
            if kind != EV_KEY or code != KEY_POWER:
                continue
            now = seconds + micros / 1e6
            if value == 1:
                pressed_at = now
                log(CRITICAL, "power button pressed")
                record(now, "pressed")
            elif value == 0:
                held = (
                    f" after {now - pressed_at:.1f} s" if pressed_at is not None else ""
                )
                pressed_at = None
                log(NOTICE, f"power button released{held}")
                record(now, f"released{held}")


def main() -> None:
    device = Path(sys.argv[1]) if len(sys.argv) > 1 else find_button()
    if device is None:
        log(INFO, f"no {BUTTON_NAME} input device on this model; nothing to watch")
        return
    if last := last_recorded():
        log(INFO, f"last recorded: {last}")
    log(INFO, f"watching {device}")
    watch(device)


if __name__ == "__main__":
    main()
