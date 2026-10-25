#!/usr/bin/env python3
"""Build an offline Windows x64 LÖVE distribution from a verified LÖVE ZIP.

No network access is performed. The client and runtime must be provided locally.
The distributed client deliberately omits the user-imported original Qeep art.
"""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

RUNTIME_SHA256 = "ba6e56be2685e53c817749c4a5007f51137136fe5a3ab64920508babc2e74369"
PRODUCT = "QeepRevival2008"
MAX_RUNTIME_UNCOMPRESSED = 100 * 1024 * 1024
FIXED_DATE = (2024, 1, 1, 0, 0, 0)


class PackagingError(ValueError):
    pass


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fixed_write(archive: zipfile.ZipFile, name: str, data: bytes) -> None:
    info = zipfile.ZipInfo(name, FIXED_DATE)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (0o644 << 16)
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def client_files(client: Path, include_original_assets: bool = False) -> dict[str, bytes]:
    client = client.resolve(strict=True)
    if not (client / "main.lua").is_file():
        raise PackagingError("Client must contain main.lua at its root")
    result = {}
    for path in sorted(client.rglob("*")):
        if path.is_symlink():
            raise PackagingError(f"Symlinks cannot be included: {path}")
        if not path.is_file():
            continue
        rel = path.relative_to(client).as_posix()
        parts = PurePosixPath(rel).parts
        if any(part.startswith(".") or part == "__pycache__" for part in parts):
            continue
        if len(parts) >= 2 and parts[0] == "assets" and parts[1] == "original" and not include_original_assets:
            continue
        if path.suffix.lower() in {".db", ".tmp", ".bak", ".pyc", ".exe", ".dll", ".jar"}:
            continue
        result[rel] = path.read_bytes()
    return result


def build_love(client: Path, include_original_assets: bool = False) -> bytes:
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w") as archive:
        for name, data in client_files(client, include_original_assets).items():
            fixed_write(archive, name, data)
    return out.getvalue()


def runtime_files(runtime_zip: Path, expected_sha256: str) -> dict[str, bytes]:
    if not re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha256):
        raise PackagingError("Expected runtime SHA-256 must be a 64-character hex string")
    if sha256_file(runtime_zip) != expected_sha256.lower():
        raise PackagingError("LÖVE runtime SHA-256 does not match trusted expected value")
    result: dict[str, bytes] = {}
    with zipfile.ZipFile(runtime_zip) as archive:
        infos = [i for i in archive.infolist() if not i.is_dir()]
        if sum(i.file_size for i in infos) > MAX_RUNTIME_UNCOMPRESSED:
            raise PackagingError("Runtime archive exceeds size limit")
        parsed = []
        for info in infos:
            path = PurePosixPath(info.filename.replace("\\", "/"))
            if path.is_absolute() or any(p in (".", "..") for p in path.parts) or ":" in info.filename:
                raise PackagingError("Unsafe entry in LÖVE runtime archive")
            mode = (info.external_attr >> 16) & 0o170000
            if mode == stat.S_IFLNK:
                raise PackagingError("Runtime ZIP contains a symlink")
            parsed.append((path, info))
        exe = [(path, info) for path, info in parsed if path.name.lower() == "love.exe"]
        if len(exe) != 1:
            raise PackagingError("Runtime must contain exactly one love.exe")
        parent = exe[0][0].parent
        for path, info in parsed:
            if path.parent != parent:
                continue
            filename = path.name
            if filename.lower() in ("love.exe", "license.txt") or filename.lower().endswith(".dll"):
                if filename.lower() in {key.lower() for key in result}:
                    raise PackagingError("Duplicate runtime entry")
                result[filename] = archive.read(info)
    lower = {n.lower() for n in result}
    if not {"love.exe", "love.dll", "lua51.dll", "sdl2.dll"}.issubset(lower):
        raise PackagingError("Required LÖVE Windows binaries are missing")
    if "license.txt" not in lower:
        raise PackagingError("Runtime license.txt missing; cannot redistribute")
    return result


def make_distribution(client: Path, runtime_zip: Path, expected_sha256: str,
                      output_zip: Path, output_love: Path,
                      include_original_assets: bool = False) -> dict[str, str]:
    game = build_love(client, include_original_assets)
    runtime = runtime_files(runtime_zip, expected_sha256)
    love_exe_name = next(n for n in runtime if n.lower() == "love.exe")
    fused = runtime.pop(love_exe_name) + game
    with zipfile.ZipFile(io.BytesIO(fused)) as archive:
        if "main.lua" not in archive.namelist():
            raise PackagingError("Fused EXE does not contain main.lua")
    output_zip.parent.mkdir(parents=True, exist_ok=True)
    output_love.parent.mkdir(parents=True, exist_ok=True)
    output_love.write_bytes(game)
    help_text = (
        "Qeep Revival 2008 - Windows x64 experimental client (Lua / LOVE 11.5)\r\n"
        "Run QeepRevival2008.exe without installing LOVE separately.\r\n"
        "This does not include the private Lua server; run your own server separately.\r\n"
        "Keep all DLL files alongside the EXE.\r\n"
        "The social service is a LAN laboratory; do not expose it to the public internet.\r\n"
        "This package does not claim historical screen fidelity or include the Qeep JAR.\r\n"
        "Original Qeep PNGs are excluded from public builds.\r\n"
    ).encode("utf-8")
    with zipfile.ZipFile(output_zip, "w") as archive:
        prefix = PRODUCT + "/"
        fixed_write(archive, prefix + PRODUCT + ".exe", fused)
        for filename, contents in sorted(runtime.items()):
            fixed_write(archive, prefix + filename, contents)
        fixed_write(archive, prefix + "LEIA-ME.txt", help_text)
    return {"windows_zip_sha256": sha256_file(output_zip),
            "love_sha256": sha256_file(output_love),
            "runtime_sha256": expected_sha256.lower()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", type=Path, default=Path("client"))
    parser.add_argument("--runtime-zip", type=Path, required=True)
    parser.add_argument("--expected-runtime-sha256", default=RUNTIME_SHA256)
    parser.add_argument("--output-zip", type=Path, default=Path("dist/Qeep-Revival-2008-Windows-x64.zip"))
    parser.add_argument("--output-love", type=Path, default=Path("dist/Qeep-Revival-2008.love"))
    parser.add_argument("--include-original-assets", action="store_true",
                        help="ONLY for personal local packages, never for public publishing")
    args = parser.parse_args()
    try:
        results = make_distribution(args.client, args.runtime_zip, args.expected_runtime_sha256,
                                    args.output_zip, args.output_love, args.include_original_assets)
    except (PackagingError, OSError, zipfile.BadZipFile) as exc:
        parser.exit(1, f"Packaging error: {exc}\n")
    for key, value in results.items():
        print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
