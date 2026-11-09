#!/usr/bin/env python3
"""Scan a tree for live-image secrets.

The report names the rule and the path. It does not print the matched secret.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# A live key is a PEM block with a body. Format strings in libraries, man
# pages, and MIME magic files contain the header and are not keys.
PRIVATE_KEY_BLOCK = re.compile(
    br"-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----\r?\n"
    br"[A-Za-z0-9+/=\r\n]{64,}?"
    br"-----END (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----"
)
AWS_KEY = re.compile(br"(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}(?![A-Za-z0-9])")
GITHUB_TOKEN = re.compile(
    br"(?<![A-Za-z0-9])(?:ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,})(?![A-Za-z0-9])"
)

TEXT_SUFFIXES = {
    ".cfg", ".conf", ".desktop", ".fish", ".hook", ".html", ".json",
    ".jsonc", ".md", ".rules", ".service", ".sh", ".txt", ".xml",
}
SKIP_DIR_NAMES = {".git", "build", "host-tools", "pacman-cache", "work"}
MAX_BYTES = 20 * 1024 * 1024


def iter_files(root: Path):
    root = root.resolve()
    if root.is_file():
        yield root
        return
    for path in root.rglob("*"):
        # Skip names under the scan root only. An extracted image may live
        # inside a directory named build/; that ancestor is not a reason to
        # skip the image.
        rel_parts = path.relative_to(root).parts
        if any(part in SKIP_DIR_NAMES for part in rel_parts):
            continue
        if path.is_file() and not path.is_symlink():
            yield path


def marker_findings(blob: bytes) -> list[str]:
    found = []
    if PRIVATE_KEY_BLOCK.search(blob):
        found.append("private-key")
    if b"/home/laden" in blob:
        found.append("host-home")
    if AWS_KEY.search(blob):
        found.append("aws-key")
    if GITHUB_TOKEN.search(blob):
        found.append("github-token")
    return found


def scan_bytes(path: Path) -> list[str]:
    """Search a file of any size without loading all of it when it is large."""
    # Keep a window large enough for a PEM block that crosses a read boundary.
    overlap = 16384
    prev = b""
    found: set[str] = set()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            found.update(marker_findings(prev + chunk))
            prev = chunk[-overlap:]
    return sorted(found)


def shadow_problems(text: str) -> list[str]:
    problems = []
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        fields = line.split(":")
        if len(fields) < 2:
            continue
        password = fields[1]
        if password in {"!", "*", "!!", "!*"}:
            continue
        if password.startswith("!") or password.startswith("*"):
            continue
        problems.append(fields[0] or "(blank user)")
    return problems


def scan(root: Path) -> list[str]:
    findings: list[str] = []
    for path in iter_files(root):
        rel = path.as_posix()
        name = path.name
        if name in {"known_hosts", "id_rsa", "id_ed25519", ".git-credentials"}:
            findings.append(f"forbidden-name {rel}")
            continue
        try:
            size = path.stat().st_size
        except OSError as exc:
            findings.append(f"unreadable {rel} ({exc.__class__.__name__})")
            continue
        try:
            if size > MAX_BYTES or path.suffix.lower() not in TEXT_SUFFIXES:
                for kind in scan_bytes(path):
                    findings.append(f"{kind} {rel}")
                if size > MAX_BYTES:
                    continue
            data = path.read_bytes()
        except OSError as exc:
            findings.append(f"unreadable {rel} ({exc.__class__.__name__})")
            continue
        if path.suffix.lower() in TEXT_SUFFIXES and size <= MAX_BYTES:
            for kind in marker_findings(data):
                findings.append(f"{kind} {rel}")
        if name == "machine-id":
            text = data.decode("utf-8", "replace").strip()
            if text and text != "uninitialized":
                findings.append(f"machine-id {rel}")
        if name == "shadow":
            for user in shadow_problems(data.decode("utf-8", "replace")):
                findings.append(f"unlocked-or-empty-password user={user} path={rel}")
        if name.endswith(".network") and re.search(br"(?i)psk\s*=\s*\S+", data):
            findings.append(f"wifi-psk {rel}")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    if not args.root.exists():
        print(f"missing {args.root}", file=sys.stderr)
        return 2
    findings = scan(args.root)
    if findings:
        print(f"{len(findings)} finding(s)")
        for item in findings:
            print(item)
        return 1
    print(f"clean {args.root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
