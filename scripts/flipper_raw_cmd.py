#!/usr/bin/env python3
"""Send a raw Flipper CLI command and print output until prompt, timeout, or disconnect."""

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path.home() / ".ufbt/current/scripts"))

import serial
from flipper.utils.cdc import resolve_port


def read_for(port: serial.Serial, seconds: float) -> bytes:
    end = time.monotonic() + seconds
    data = bytearray()
    while time.monotonic() < end:
        try:
            chunk = port.read(1)
        except Exception as exc:
            data.extend(f"\n[serial error: {exc}]\n".encode())
            break
        if chunk:
            data.extend(chunk)
            if data.endswith(b">: "):
                break
        else:
            time.sleep(0.01)
    return bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command")
    parser.add_argument("-p", "--port", default="auto")
    parser.add_argument("--seconds", type=float, default=3.0)
    args = parser.parse_args()

    port_name = resolve_port(None, args.port)
    if not port_name:
        print("Flipper CDC port not found", file=sys.stderr)
        return 2

    port = serial.Serial(port_name, baudrate=115200, timeout=0.05)
    try:
        read_for(port, 0.5)
        port.write((args.command + "\r").encode("ascii"))
        output = read_for(port, args.seconds)
        sys.stdout.write(output.decode("utf-8", errors="replace"))
    finally:
        try:
            port.close()
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
