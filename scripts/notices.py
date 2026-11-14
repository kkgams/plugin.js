#!/usr/bin/env python3
"""Attach or read recipient licenses and MPL source in the OCI component."""
import argparse
from pathlib import Path
import sys

SECTION = b"gams:licenses"


def uleb(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def read_uleb(data, offset):
    value = 0
    for shift in range(0, 35, 7):
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, offset
    raise ValueError("Invalid WebAssembly section length")


def sections(data):
    if data[:8] != b"\0asm\x0d\0\x01\0":
        raise ValueError("Expected a WebAssembly component")
    offset = 8
    while offset < len(data):
        kind = data[offset]
        size, start = read_uleb(data, offset + 1)
        end = start + size
        if end > len(data):
            raise ValueError("Truncated WebAssembly section")
        if kind == 0:
            length, content = read_uleb(data, start)
            yield data[content:content + length], data[content + length:end]
        offset = end


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extract", action="store_true")
    parser.add_argument("component", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    args = parser.parse_args()
    data = args.component.read_bytes()
    found = [payload for name, payload in sections(data) if name == SECTION]
    if args.extract:
        if args.output or len(found) != 1:
            parser.error("Extraction requires one embedded notice section and no output path")
        sys.stdout.buffer.write(found[0])
        return
    if args.output is None or found:
        parser.error("Embedding requires an output path and no existing notice section")
    root = Path(__file__).resolve().parents[1]
    files = [root / "NOTICE", root / "LICENSE"]
    files += sorted(path for path in (root / "licenses").rglob("*") if path.is_file() and path.name != ".DS_Store")
    files += [root / "src/crates/rust-hooks/Cargo.toml", root / "src/crates/rust-hooks/src/lib.rs",
              root / "src/crates/rust-hooks/src/wrappers.cpp"]
    payload = b"".join(b"\n===== " + str(path.relative_to(root)).encode() + b" =====\n"
                       + path.read_bytes() + b"\n" for path in files)
    section = uleb(len(SECTION)) + SECTION + payload
    args.output.write_bytes(data + b"\0" + uleb(len(section)) + section)


if __name__ == "__main__":
    main()
