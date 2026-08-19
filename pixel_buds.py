#!/usr/bin/env python3
from __future__ import annotations

import fcntl
import json
import math
import os
import re
import shutil
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path


def run(command: list[str], timeout: int = 15) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=timeout, check=False,
            env={**os.environ, "LC_ALL": "C", "LANG": "C"},
        )
        return result.returncode, result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def buds() -> tuple[str, str] | None:
    code, output = run(["bluetoothctl", "devices", "Paired"])
    if code != 0:
        return None
    for line in output.splitlines():
        match = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.+)", line)
        if match and "buds" in match[2].lower():
            return match[1], match[2]
    return None


def pbpctrl() -> str | None:
    cargo = Path.home() / ".cargo/bin/pbpctrl"
    return str(cargo) if cargo.is_file() and os.access(cargo, os.X_OK) else shutil.which("pbpctrl")


@contextmanager
def device_lock():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/omarchy-pixel-buds-{os.getuid()}"))
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (runtime / "omarchy-pixel-buds.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def battery(output: str) -> dict[str, int | None]:
    def level(label: str) -> int | None:
        match = re.search(rf"^{label}:\s+(\d+)%", output, re.MULTILINE)
        return int(match[1]) if match else None

    return {"left": level("left bud"), "right": level("right bud"), "case": level("case")}


def equalizer(values: object) -> list[float] | None:
    if not isinstance(values, list) or len(values) != 5:
        return None
    try:
        bands = [float(value) for value in values]
    except (TypeError, ValueError):
        return None
    return bands if all(math.isfinite(value) and -6 <= value <= 6 for value in bands) else None


def status() -> dict:
    device = buds()
    if not device:
        return {
            "paired": False, "connected": False, "name": "Pixel Buds",
            "pbpctrl": pbpctrl() is not None, "battery": {}, "anc": None, "eq": None,
        }

    address, name = device
    _, info = run(["bluetoothctl", "info", address])
    connected = "Connected: yes" in info
    binary = pbpctrl()
    state = {
        "paired": True, "connected": connected, "name": name,
        "pbpctrl": binary is not None, "battery": {}, "anc": None, "eq": None,
    }
    if not connected or not binary:
        return state

    with device_lock():
        battery_code, battery_output = run([binary, "--device", address, "show", "battery"])
        anc_code, anc_output = run([binary, "--device", address, "get", "anc"])
        eq_code, eq_output = run([binary, "--device", address, "get", "eq"])
    if battery_code == 0:
        state["battery"] = battery(battery_output)
    if anc_code == 0 and anc_output in {"off", "active", "aware", "adaptive"}:
        state["anc"] = anc_output
    if eq_code == 0:
        try:
            state["eq"] = equalizer(json.loads(eq_output))
        except json.JSONDecodeError:
            pass
    return state


def act(action: str, args: list[str]) -> int:
    if action == "install-pbpctrl":
        try:
            subprocess.Popen(["omarchy", "launch", "terminal", "yay", "-S", "pbpctrl-git"])
            return 0
        except OSError:
            return 1

    device = buds()
    if not device:
        return 1
    address, _ = device
    modes = {"anc-off": "off", "anc-active": "active", "anc-aware": "aware", "anc-adaptive": "adaptive"}
    if not (binary := pbpctrl()):
        return 2
    with device_lock():
        if action in modes:
            return run([binary, "--device", address, "set", "anc", modes[action]])[0]
        if action == "set-eq" and (bands := equalizer(args)) is not None:
            return run([binary, "--device", address, "set", "eq", *map(str, bands)])[0]
    return 2


def main() -> int:
    if len(sys.argv) == 1 or sys.argv[1] == "status":
        print(json.dumps(status()))
        return 0
    return act(sys.argv[1], sys.argv[2:])


if __name__ == "__main__":
    raise SystemExit(main())
