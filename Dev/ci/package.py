#!/usr/bin/env python3
"""Stamp build provenance and verify the BigWigs-produced installable ZIP."""

import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile


VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:-(?:alpha|beta)\.[0-9]+)?")
TOC = "social_diary.toc"


def field(text, key):
    values = re.findall(r"^## " + re.escape(key) + r": *([^\r\n]+)$", text, re.M)
    if len(values) != 1:
        raise ValueError(f"Expected one {key} field in the TOC")
    return values[0].strip()


def stamp(text, channel, commit, ref):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("A full commit SHA is required")
    version = field(text, "Version")
    if not VERSION.fullmatch(version):
        raise ValueError("TOC version must be X.Y.Z, X.Y.Z-alpha.N or X.Y.Z-beta.N")
    if channel == "tag" and ref != "v" + version:
        raise ValueError(f"Tag {ref} does not match TOC version {version}")
    if channel == "main":
        if ref != "main":
            raise ValueError("Testing packages must come from main")
        version += "+main." + commit[:12]
    text = re.sub(r"^## Version:.*$", "## Version: " + version, text, flags=re.M)
    for key, value in (("X-Social-Diary-Commit", commit), ("X-Social-Diary-Channel", channel)):
        text = re.sub(r"^## " + key + r":.*\n?", "", text, flags=re.M)
        text = "## " + key + ": " + value + "\n" + text
    return text


def ignored_paths(pkgmeta):
    """Read the existing simple ignore list; fail on unsupported list syntax."""
    patterns = [".git", ".pkgmeta"]
    reading = False
    for line in pkgmeta.splitlines():
        if line == "ignore:":
            reading = True
        elif reading and line and not line.startswith((" ", "#")):
            break
        elif reading and line.strip() and not line.lstrip().startswith("#"):
            match = re.fullmatch(r"  - ([^'\"#]+)", line)
            if not match:
                raise ValueError("Unsupported .pkgmeta ignore syntax")
            patterns.append(match[1].strip())
    if not reading:
        raise ValueError("Missing .pkgmeta ignore list")
    return patterns


def verify_archive(path, source_toc, patterns):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("ZIP contains duplicate paths")
        bad = archive.testzip()
        if bad:
            raise ValueError(f"Corrupt ZIP member: {bad}")
        for name in names:
            parts = PurePosixPath(name).parts
            if not parts or parts[0] != "social_diary" or ".." in parts or "\\" in name:
                raise ValueError(f"Unexpected ZIP path: {name}")
            relative = "/".join(parts[1:])
            if any(fnmatch.fnmatchcase(relative, pattern) or
                   fnmatch.fnmatchcase(relative, pattern + "/*") for pattern in patterns):
                raise ValueError(f"Development file included: {name}")
        if "social_diary/LICENSE" not in names:
            raise ValueError("Packaged licence is missing")
        toc = archive.read("social_diary/" + TOC).decode("utf-8-sig").replace("\r\n", "\n")
        for key in ("Version", "Interface", "X-Social-Diary-Commit", "X-Social-Diary-Channel"):
            if field(toc, key) != field(source_toc, key):
                raise ValueError(f"Packaged {key} differs from the tested build")
        if "@do-not-package@" in toc or "@end-do-not-package@" in toc:
            raise ValueError("Development TOC block was not stripped")
        for line in toc.splitlines():
            entry = line.strip().replace("\\", "/")
            if entry and not entry.startswith("#"):
                if "social_diary/" + entry not in names:
                    raise ValueError(f"TOC references missing file: {entry}")
        return field(toc, "Version")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "verify"))
    parser.add_argument("channel", choices=("main", "tag"))
    args = parser.parse_args()
    commit = os.environ["GITHUB_SHA"]
    if subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() != commit:
        raise ValueError("Checkout does not match the workflow's commit")
    toc = Path(TOC)
    text = toc.read_text(encoding="utf-8-sig")
    if args.command == "prepare":
        toc.write_text(stamp(text, args.channel, commit, os.environ["GITHUB_REF_NAME"]), encoding="utf-8")
        return
    if field(text, "X-Social-Diary-Commit") != commit or field(text, "X-Social-Diary-Channel") != args.channel:
        raise ValueError("Build provenance does not match the workflow")
    output = Path(".release")
    archives = sorted(output.glob("*.zip"))
    if len(archives) != 1:
        raise ValueError("Expected exactly one installable ZIP")
    archive = archives[0]
    version = verify_archive(archive, text, ignored_paths(Path(".pkgmeta").read_text()))
    info = {
        "repository": os.environ["GITHUB_REPOSITORY"],
        "commit": commit,
        "ref": os.environ["GITHUB_REF_NAME"],
        "channel": args.channel,
        "version": version,
        "archive": archive.name,
        "sha256": digest(archive),
        "run_url": f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
    }
    metadata = output / "BUILD-INFO.json"
    metadata.write_text(json.dumps(info, indent=2, sort_keys=True) + "\n")
    (output / "SHA256SUMS").write_text("".join(f"{digest(path)}  {path.name}\n" for path in (archive, metadata)))
    print(f"Verified {archive.name}: {version}, commit {commit}")


if __name__ == "__main__":
    main()
