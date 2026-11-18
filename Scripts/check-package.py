#!/usr/bin/env python3
"""Check the downloadable app after extracting it outside the checkout on macOS."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import subprocess
import struct
import tempfile
import time
import urllib.request


def check(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify(archive, smoke, architecture):
    checksum = archive.with_name("SHA256SUMS.txt").read_text().split()
    check(len(checksum) == 2 and checksum[1] == archive.name, "Invalid checksum file")
    check(hashlib.sha256(archive.read_bytes()).hexdigest() == checksum[0], "ZIP checksum mismatch")
    with tempfile.TemporaryDirectory(prefix="SnowPlay download ") as folder:
        work = Path(folder)
        subprocess.run(["ditto", "-x", "-k", str(archive), str(work)], check=True)
        app = work / "SnowPlay.app"
        binary = app / "Contents/MacOS/SnowPlay"
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        check(info["LSMinimumSystemVersion"] == "13.0", "Unexpected minimum macOS version")
        subprocess.run(["lipo", str(binary), "-verify_arch", "arm64", "x86_64"], check=True)
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        resources = app / "Contents/Resources/SnowPlay_SnowPlay.bundle/Resources"
        check((resources / "Web/index.html").is_file(), "Control panel missing from bundle")
        assets = resources / "SnowPlayAssets"
        index = json.loads((assets / "Prepared/index.json").read_text())
        for row in index["assets"]:
            source = (assets / row["source"]).read_bytes()
            check(hashlib.sha256(source).hexdigest() == row["sha256"], f'Source changed for {row["id"]}')
            for scale, suffix in [(1, ""), (2, "@2x")]:
                texture = (assets / f'Prepared/{row["id"]}{suffix}.png').read_bytes()
                check(texture.startswith(b"\x89PNG\r\n\x1a\n"), f'Invalid texture {row["id"]}')
                dimensions = struct.unpack(">II", texture[16:24])
                expected = (math.ceil(row["width"] * scale), math.ceil(row["height"] * scale))
                check(dimensions == expected, f'Invalid texture dimensions for {row["id"]}')
        print("PASS: ZIP checksum, universal executable, signature and bundled resources")
        if smoke:
            smoke_test(binary, work, architecture)


def smoke_test(binary, work, architecture):
    environment = os.environ.copy()
    environment.pop("SNOWPLAY_RESOURCE_ROOT", None)
    url_file = work / "control-url"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    command = [str(binary), "--config", str(work / "settings.json"),
               "--no-auto-delivery", "--control-url-file", str(url_file)]
    if architecture:
        command = ["arch", "-" + architecture] + command
    with (work / "app.log").open("w+") as log:
        process = subprocess.Popen(
            command,
            cwd=work, env=environment, stdout=log, stderr=log,
        )
        try:
            deadline = time.monotonic() + 30
            while not url_file.exists() and time.monotonic() < deadline:
                check(process.poll() is None, "App exited before starting its control panel")
                time.sleep(0.1)
            check(url_file.exists(), "Timed out waiting for the control panel")
            origin = url_file.read_text().strip()

            def get(path):
                with opener.open(origin + path, timeout=5) as response:
                    return response.read()

            state = json.loads(get("/api/state"))
            check(not state["diagnostic"], state["diagnostic"])
            check(state["displays"] > 0, "No display detected, run in a logged-in desktop session")
            check(b"SnowPlay" in get("/"), "Control panel did not load")
            check(b"fetch(" in get("/app.js"), "Control panel JavaScript did not load")
            ids = json.loads(get("/api/assets"))["ids"]
            for asset_id in ids:
                check(get("/assets/" + asset_id).startswith(b"\x89PNG\r\n\x1a\n"),
                      f"Preview did not load for {asset_id}")
            request = urllib.request.Request(
                origin + "/api/action", data=json.dumps({"action": "pause"}).encode(),
                headers={"Content-Type": "application/json", "Origin": origin,
                         "X-SnowPlay-Token": state["sessionToken"]},
            )
            with opener.open(request, timeout=5) as response:
                check(json.load(response)["paused"], "Pause control failed")
            print(f"PASS: relocated app starts, panel loads, {len(ids)} previews load, controls respond")
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read())
            raise
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=Path, default=Path("dist/SnowPlay-macOS.zip"))
    parser.add_argument("--smoke", action="store_true", help="Launch in an active macOS desktop session")
    parser.add_argument("--arch", choices=["arm64", "x86_64"], help="Architecture to use for --smoke")
    args = parser.parse_args()
    verify(args.archive.resolve(), args.smoke, args.arch)
