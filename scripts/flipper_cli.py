#!/usr/bin/env python3
"""Run a Flipper Zero CLI command over USB CDC and print the response."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / ".ufbt/current/scripts"))

from flipper.storage import FlipperStorage
from flipper.utils.cdc import resolve_port


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", help="CLI command to send")
    parser.add_argument("-p", "--port", default="auto", help="CDC port")
    args = parser.parse_args()

    port = resolve_port(None, args.port)
    if not port:
        print("Flipper CDC port not found", file=sys.stderr)
        return 2

    with FlipperStorage(port) as storage:
        storage.send_and_wait_eol(args.command + "\r")
        data = storage.read.until(storage.CLI_PROMPT)
        sys.stdout.write(data.decode("utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
