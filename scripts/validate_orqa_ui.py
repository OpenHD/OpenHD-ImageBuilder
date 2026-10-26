"""Validate the complete native UI payload and its installed ELF dependency closure."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

def validate(root: Path, installed: bool) -> None:
    runtime = root / "usr/local/share/qopenhd-nxp"
    required = ["QOpenHD", "weston", "run-qopenhd.sh", "run-weston.sh",
                "nxp-boot-splash", "boot-logo.png",
                "libweston-9/drm-backend.so", "libweston-9/gl-renderer.so",
                "weston-modules/kiosk-shell.so"]
    manifest = json.loads((runtime / "manifest.json").read_text())
    if manifest.get("backend") != "hantro-wayland-dmabuf" or manifest.get("media_frameworks") != []:
        raise ValueError("Unexpected ORQA native video manifest")
    for name in required:
        if name not in manifest["files"]:
            raise ValueError(f"Unmanifested ORQA component: {name}")
    for name, checksum in manifest["files"].items():
        path = runtime / name
        if not path.resolve().is_relative_to(runtime.resolve()) or not path.is_file():
            raise ValueError(f"Invalid ORQA runtime manifest path: {name}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != checksum:
            raise ValueError(f"ORQA runtime checksum mismatch: {name}")
    if (runtime / "tests").exists() or (runtime / "libweston-9/headless-backend.so").exists():
        raise ValueError("Headless test components must not enter the production runtime")
    for name in ["qopenhd.service", "qopenhd-nxp-compositor.service", "openhd-nxp-boot-splash.service"]:
        if not (root / "usr/lib/systemd/system" / name).is_file():
            raise ValueError(f"Missing ORQA UI unit: {name}")
    early_splash = root / "usr/lib/systemd/system/sysinit.target.wants/openhd-nxp-boot-splash.service"
    if not early_splash.is_symlink() or str(early_splash.readlink()) != "../openhd-nxp-boot-splash.service":
        raise ValueError("ORQA early boot splash is not enabled in sysinit.target")
    if not (runtime / "nxp-boot-splash").stat().st_mode & 0o111:
        raise ValueError("ORQA early boot splash helper is not executable")
    if not (root / "etc/qopenhd-nxp/weston.ini").is_file():
        raise ValueError("Missing ORQA compositor output configuration")
    if not installed:
        return
    # Absolute target symlinks resolve against the mounted image, never the host.
    def target_file(path: Path) -> Path:
        for _ in range(32):
            if not path.is_symlink():
                return path
            value = path.readlink()
            path = root / str(value).lstrip("/") if value.is_absolute() else path.parent / value
        raise ValueError(f"Symlink loop in ORQA image: {path}")
    directories = [runtime / "lib", root / "usr/lib", root / "lib",
                   root / "usr/lib/aarch64-linux-gnu", root / "lib/aarch64-linux-gnu"]
    def resolve(name: str) -> Path:
        for directory in directories:
            path = target_file(directory / name)
            if path.is_file():
                return path
        raise ValueError(f"Unresolved ORQA image library: {name}")
    pending = [p for p in runtime.rglob("*") if p.is_file() and p.open("rb").read(4) == b"\x7fELF"]
    # These are loaded locally with dlopen rather than appearing in DT_NEEDED.
    pending += [resolve(name) for name in ["libimxvpuapi2.so.2", "libimxdmabuffer.so.1"]]
    seen = set()
    while pending:
        binary = pending.pop()
        if binary in seen:
            continue
        seen.add(binary)
        header = subprocess.check_output(["readelf", "-h", str(binary)], text=True)
        if not re.search(r"Machine:\s+AArch64", header):
            raise ValueError(f"Wrong ORQA ELF architecture: {binary}")
        dynamic = subprocess.check_output(["readelf", "-d", str(binary)], text=True)
        for name in re.findall(r"\(NEEDED\).*?\[(.*?)\]", dynamic):
            if name.startswith(("libavcodec", "libavformat", "libavutil", "libgst")):
                raise ValueError(f"Media-framework dependency in ORQA UI: {binary}: {name}")
            pending.append(resolve(name))
    print(f"ORQA UI: verified manifest and {len(seen)} AArch64 ELF dependencies")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--installed", action="store_true")
    args = parser.parse_args()
    validate(args.root, args.installed)
