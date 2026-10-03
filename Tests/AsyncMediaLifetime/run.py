#!/usr/bin/env python3
"""Run the production callback bodies with real Legacy dispatch and checked media.

No libVLC build is required. The fake descriptor deliberately rejects any lookup
after callback return, even if a descriptor retain would otherwise mask the bug.
Pass --source to run against an unpatched VLCMediaPlayer.m as a negative control.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, default=root / "Sources/Playback/VLCMediaPlayer.m")
args = parser.parse_args()
source = args.source.read_text()
names = ["HandleMediaPlayerMediaChanged", "HandleMediaPlayerMediaMetaChanged",
         "HandleMediaPlayerMediaSubItemsChanged", "HandleMediaPlayerMediaAttachmentsAdded"]
callbacks = []
for name in names:
    start = source.index("static void " + name + "(")
    end = source.index("\nstatic void ", start + 1)
    callbacks.append(source[start:end])

with tempfile.TemporaryDirectory(prefix="vlckit-lifetime-") as directory:
    build = Path(directory)
    (build / "Callbacks.inc").write_text("\n".join(callbacks))
    executable = build / "lifetime-tests"
    subprocess.run(["xcrun", "clang", "-fobjc-arc", "-fblocks", "-g", "-O1",
                    "-fsanitize=address", "-framework", "Foundation",
                    "-I", str(build), "-I", str(root / "Sources"),
                    "-I", str(root / "Headers/Internal"),
                    "-I", str(root / "Headers/Public"),
                    str(root / "Tests/AsyncMediaLifetime/main.m"),
                    str(root / "Sources/Events/VLCEventsHandler.m"),
                    str(root / "Sources/Events/VLCEventsConfiguration.m"),
                    "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True, timeout=60)
