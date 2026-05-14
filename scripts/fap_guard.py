#!/usr/bin/env python3
"""Offline safety checks for Kindled Spark before installing on a Flipper."""

from __future__ import annotations

import argparse
import re
import struct
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FAP = ROOT / "target/thumbv7em-none-eabihf/release/kindled_spark.fap"
SDK_API = Path.home() / ".ufbt/current/sdk_headers/f7_sdk/targets/f7/api_symbols.csv"
NM = Path.home() / ".ufbt/toolchain/arm64-darwin/bin/arm-none-eabi-nm"

REQUIRED_RUSTFLAGS = {
    "-Z",
    "no-unique-section-names",
    "target-cpu=cortex-m4",
    "link-args=--script=flipperzero-rt.ld --Bstatic --relocatable --discard-all --strip-all --lto-O3 --lto-whole-program-visibility",
}
MAX_STACK_ARRAY_BYTES = 1024
MIN_STACK_SIZE = 4096
EXPECTED_API_VERSION = 0x00570001
EXPECTED_HW_TARGET = 7


class GuardError(Exception):
    pass


def fail(message: str) -> None:
    raise GuardError(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def flatten_flags(flags: list[str]) -> set[str]:
    values = set(flags)
    for flag in flags:
        if flag.startswith("-C") or flag.startswith("-Z"):
            continue
        values.add(flag)
    return values


def cargo_build_target_and_rustflags(config_text: str) -> tuple[str | None, list[str]]:
    section = None
    build_target = None
    rustflags: list[str] = []
    collecting_rustflags = False

    for raw_line in config_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            collecting_rustflags = False
            continue

        if section == "build" and line.startswith("target"):
            match = re.search(r'"([^"]+)"', line)
            if match:
                build_target = match.group(1)
            continue

        if section == "target.thumbv7em-none-eabihf" and line.startswith("rustflags"):
            collecting_rustflags = True
            continue

        if collecting_rustflags:
            if line.startswith("]"):
                collecting_rustflags = False
                continue
            match = re.search(r'"([^"]+)"', line)
            if match:
                rustflags.append(match.group(1))

    return build_target, rustflags


def check_cargo_config() -> None:
    config_path = ROOT / ".cargo/config.toml"
    if not config_path.exists():
        fail(".cargo/config.toml is missing")

    build_target, rustflags = cargo_build_target_and_rustflags(read(config_path))
    if build_target != "thumbv7em-none-eabihf":
        fail(f"Cargo build target must be thumbv7em-none-eabihf, got {build_target!r}")

    present = flatten_flags(rustflags)
    missing = sorted(REQUIRED_RUSTFLAGS - present)
    if missing:
        fail(f"Cargo rustflags missing required Flipper runtime flags: {missing}")


def check_runtime_manifest() -> None:
    main_rs = read(ROOT / "src/main.rs")
    if "rt::entry!(main)" not in main_rs:
        fail("src/main.rs must declare rt::entry!(main)")

    match = re.search(r"rt::manifest!\((?P<body>.*?)\);", main_rs, re.S)
    if not match:
        fail("src/main.rs must declare rt::manifest!(...)")

    body = match.group("body")
    if 'name = "Kindled Spark"' not in body:
        fail('runtime manifest must use name = "Kindled Spark"')

    stack = re.search(r"stack_size\s*=\s*(\d+)", body)
    if not stack:
        fail("runtime manifest must set stack_size explicitly")
    if int(stack.group(1)) < MIN_STACK_SIZE:
        fail(f"runtime stack_size must be at least {MIN_STACK_SIZE}")


def check_no_large_stack_arrays() -> None:
    pattern = re.compile(r"let\s+mut\s+\w+\s*=\s*\[0u8;\s*([0-9_]+)\s*\]")
    failures: list[str] = []
    for path in sorted((ROOT / "src").rglob("*.rs")):
        text = read(path)
        for match in pattern.finditer(text):
            size = int(match.group(1).replace("_", ""))
            if size > MAX_STACK_ARRAY_BYTES:
                line = text[: match.start()].count("\n") + 1
                rel = path.relative_to(ROOT)
                failures.append(f"{rel}:{line} declares {size} byte stack array")
    if failures:
        fail("large stack arrays are forbidden in Flipper app code:\n" + "\n".join(failures))


def parse_elf_sections(path: Path) -> dict[str, bytes]:
    data = path.read_bytes()
    if data[:4] != b"\x7fELF":
        fail(f"{path} is not an ELF file")
    if data[4] != 1 or data[5] != 1:
        fail("FAP must be ELF32 little-endian")

    shoff = struct.unpack_from("<I", data, 32)[0]
    shentsize = struct.unpack_from("<H", data, 46)[0]
    shnum = struct.unpack_from("<H", data, 48)[0]
    shstrndx = struct.unpack_from("<H", data, 50)[0]
    if shoff == 0 or shnum == 0:
        fail("ELF section table is missing")

    headers = []
    for i in range(shnum):
        off = shoff + i * shentsize
        headers.append(struct.unpack_from("<IIIIIIIIII", data, off))

    try:
        shstr = headers[shstrndx]
    except IndexError as exc:
        raise GuardError("invalid ELF section string table index") from exc
    names = data[shstr[4] : shstr[4] + shstr[5]]

    sections: dict[str, bytes] = {}
    for header in headers:
        name_off, _type, _addr, _offset, offset, size, *_rest = header
        end = names.find(b"\0", name_off)
        if end < 0:
            continue
        name = names[name_off:end].decode("ascii", errors="replace")
        sections[name] = data[offset : offset + size]
    return sections


def check_fap_metadata(sections: dict[str, bytes]) -> None:
    meta = sections.get(".fapmeta")
    if not meta:
        fail("FAP is missing .fapmeta")
    if len(meta) < 18:
        fail(".fapmeta is too small")

    magic, manifest_version, api_version, hw_target, stack_size = struct.unpack_from(
        "<IIIHH", meta, 0
    )
    if magic != 0x52474448:
        fail(f"bad FAP manifest magic: 0x{magic:08x}")
    if manifest_version != 1:
        fail(f"unsupported FAP manifest version: {manifest_version}")
    if api_version != EXPECTED_API_VERSION:
        fail(f"FAP API version mismatch: 0x{api_version:08x}")
    if hw_target != EXPECTED_HW_TARGET:
        fail(f"FAP hardware target must be {EXPECTED_HW_TARGET}, got {hw_target}")
    if stack_size < MIN_STACK_SIZE:
        fail(f"FAP stack size must be at least {MIN_STACK_SIZE}, got {stack_size}")


def check_section_layout(sections: dict[str, bytes]) -> None:
    bad_unique_sections = [
        name
        for name in sections
        if name.startswith(".text.") or name.startswith(".rel.text.")
    ]
    if bad_unique_sections:
        fail(
            "-Z no-unique-section-names is not taking effect; found sections "
            + ", ".join(sorted(bad_unique_sections))
        )

    if ".rel.text" not in sections:
        fail("FAP is missing .rel.text; Rust FAP must be linked as relocatable")


def valid_api_symbols() -> set[str]:
    if not SDK_API.exists():
        fail(f"SDK API symbol file not found: {SDK_API}")
    names = set()
    for line in SDK_API.read_text(encoding="utf-8").splitlines()[1:]:
        parts = line.split(",", 3)
        if len(parts) >= 3 and parts[1] == "+":
            names.add(parts[2])
    return names


def check_imports(path: Path) -> None:
    if not NM.exists():
        fail(f"arm-none-eabi-nm not found: {NM}")
    result = subprocess.run(
        [str(NM), "-P", "-u", str(path)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    unresolved = {line.split()[0] for line in result.stdout.splitlines() if line.strip()}
    invalid = sorted(unresolved - valid_api_symbols())
    if invalid:
        fail("FAP imports symbols not provided by this SDK API: " + ", ".join(invalid))


def check_artifact() -> None:
    if not FAP.exists():
        fail(f"FAP artifact is missing: {FAP}")
    if FAP.stat().st_size == 0:
        fail("FAP artifact is empty")
    sections = parse_elf_sections(FAP)
    check_fap_metadata(sections)
    check_section_layout(sections)
    check_imports(FAP)


def run_static() -> None:
    check_cargo_config()
    check_runtime_manifest()
    check_no_large_stack_arrays()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--artifact",
        action="store_true",
        help="also validate the built .fap artifact",
    )
    args = parser.parse_args()

    try:
        run_static()
        if args.artifact:
            check_artifact()
    except GuardError as exc:
        print(f"fap_guard: {exc}", file=sys.stderr)
        return 1
    print("fap_guard: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
