"""Retag World Conquest III saves to a new add-on version after a release.

Wesnoth refuses to load a save whose required add-on version is newer than the installed one,
and warns about older ones; WC3 releases keep save compatibility, so after shipping X.Y.Z the
saves are retagged to it.

    python tools/retag_saves.py 0.11.1

Only saves whose wc2-extras version is >= 0.4.0 (older ones are from before save compatibility)
and older than the new version are changed. Each original is copied to
saves-backup/pre-<version>/ first, and each save keeps its modified time so the in-game load
list stays in date order.
"""
import glob
import gzip
import os
import re
import shutil
import sys

USERDATA = os.path.expanduser("~/Documents/My Games/Wesnoth1.18")
MIN_VERSION = (0, 4, 0)

ADDON = re.compile(
    r'(\[addon\]\s*\n\s*id="wc2-extras"\s*\n\s*min_version=")([^"]*)'
    r'("\s*\n\s*name="[^"]*"\s*\n\s*required=\w+\s*\n\s*version=")([^"]*)(")'
)


def parse(version):
    return tuple(int(x) for x in re.findall(r"\d+", version)[:3])


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    new = sys.argv[1]
    backup = os.path.join(USERDATA, "saves-backup", "pre-" + new)
    os.makedirs(backup, exist_ok=True)
    retagged, found = 0, {}
    for path in sorted(glob.glob(os.path.join(USERDATA, "saves", "*.gz"))):
        with gzip.open(path, "rb") as f:
            data = f.read().decode("utf-8")
        m = ADDON.search(data)
        if not m:
            continue
        current = m.group(4)
        found[current] = found.get(current, 0) + 1
        if parse(current) < MIN_VERSION or parse(current) >= parse(new):
            continue
        stat = os.stat(path)
        shutil.copy2(path, os.path.join(backup, os.path.basename(path)))
        data = ADDON.sub(lambda m: m.group(1) + new + m.group(3) + new + m.group(5), data, count=1)
        with gzip.open(path, "wb") as f:
            f.write(data.encode("utf-8"))
        os.utime(path, (stat.st_atime, stat.st_mtime))
        retagged += 1
    print(f"retagged {retagged} saves to {new}; versions found before: {found}; backups in {backup}")


if __name__ == "__main__":
    main()
