#!/usr/bin/env python3
"""Fetch/build a locked GitHub revision, then forward arguments and exit status."""

import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    if len(sys.argv) < 2:
        print("usage: run-odin-lint.py LOCK_FILE [LINTER_ARGUMENT ...]", file=sys.stderr)
        return 2
    lock_path = Path(sys.argv[1]).resolve()
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    repository, revision = lock["repository"], lock["revision"]
    if not isinstance(repository, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", repository):
        raise ValueError("repository must be a GitHub OWNER/REPO")
    if not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("revision must be a full lowercase 40-character commit SHA")
    odin = shutil.which(os.environ.get("ODIN", "odin"))
    if odin is None:
        raise ValueError("Odin is required; install the documented version or set ODIN to its executable")
    odin = str(Path(odin).resolve())
    compiler = subprocess.check_output([odin, "version"], text=True).strip()
    if not re.search(r"(?:^|\s)version\s+[^\s:]+:9a69916(?:85)?$", compiler):
        raise ValueError("Odin dev-2026-11a compiler 9a6991685 (or 9a69916) is required; found " + compiler)
    identity = "\n".join((repository, revision, compiler, sys.platform, platform.machine()))
    key = hashlib.sha256(identity.encode()).hexdigest()
    cache = lock_path.parent / ".work" / "odin-lint"
    cache.mkdir(parents=True, exist_ok=True)
    binary = cache / (key + (".exe" if os.name == "nt" else ""))
    if not binary.is_file():
        print(f"Building odin-lint from {repository}@{revision}", file=sys.stderr)
        # Private temporary sources never enter the consumer's project graph.
        # Only a successful build is atomically published into the cache.
        with tempfile.TemporaryDirectory(prefix="build-", dir=cache) as temporary:
            source = Path(temporary) / "source"
            subprocess.run(["git", "init", "--quiet", str(source)], check=True, stdout=sys.stderr)
            subprocess.run(["git", "-C", str(source), "fetch", "--quiet", "--depth=1", "--no-tags",
                            "--", f"https://github.com/{repository}.git", revision], check=True, stdout=sys.stderr)
            subprocess.run(["git", "-C", str(source), "checkout", "--quiet", "--detach", "FETCH_HEAD"],
                           check=True, stdout=sys.stderr)
            actual = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
            if actual != revision:
                raise ValueError(f"fetched revision {actual} does not match {revision}")
            built = Path(temporary) / binary.name
            subprocess.run([odin, "build", "src", "-debug", "-thread-count:2",
                            f"-define:ODIN_LINT_REVISION={revision}", f"-out:{built}"],
                           cwd=source, check=True, stdout=sys.stderr)
            os.replace(built, binary)
    status = subprocess.run([str(binary), *sys.argv[2:]]).returncode
    if status < 0:
        print(f"odin-lint analysis failed: analyzer terminated by signal {-status}", file=sys.stderr)
        return 2
    if status not in (0, 1, 2):
        print(f"odin-lint analysis failed: analyzer exited with unexpected status {status}", file=sys.stderr)
        return 2
    return status


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"odin-lint setup failed: {error}", file=sys.stderr)
        sys.exit(2)
