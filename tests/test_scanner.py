#!/usr/bin/env python3
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCANNER = ROOT / "scripts/scan-secrets.py"
FIXTURE = ROOT / "tests/fixtures/fake-key.pem"


def scan(path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCANNER), str(path)],
        capture_output=True,
        text=True,
    )


class ScannerTests(unittest.TestCase):
    def test_fixture_is_detected_and_not_printed(self):
        result = scan(FIXTURE)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("private-key", result.stdout)
        self.assertNotIn("QUFBQUFB", result.stdout)

    def test_clean_tree_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "readme.txt"
            path.write_text("Laden OS\n", encoding="utf-8")
            result = scan(Path(tmp))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_findings_under_a_directory_named_build_are_not_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "build" / "scan-root"
            root.mkdir(parents=True)
            (root / "note.txt").write_text("see /home/laden/secret\n", encoding="utf-8")
            result = scan(root)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("host-home", result.stdout)

    def test_nested_build_directory_is_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            nested = root / "build"
            nested.mkdir()
            (nested / "secret.txt").write_text("see /home/laden/secret\n", encoding="utf-8")
            (root / "ok.txt").write_text("Laden OS\n", encoding="utf-8")
            result = scan(root)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_header_without_a_body_is_not_a_private_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "manual.txt"
            path.write_text(
                'The header is -----BEGIN PRIVATE KEY----- in documentation.\n',
                encoding="utf-8",
            )
            result = scan(Path(tmp))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_akia_inside_a_word_list_is_not_a_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "words.txt"
            path.write_text("INWARDISAKIA0123456789ABCDEFICIYANNA\n", encoding="utf-8")
            result = scan(Path(tmp))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_host_home_and_empty_password_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "note.txt").write_text("see /home/laden/secret\n", encoding="utf-8")
            (root / "shadow").write_text("root::14871::::::\nlive:!:14871::::::\n", encoding="utf-8")
            result = scan(root)
            self.assertEqual(result.returncode, 1)
            self.assertIn("host-home", result.stdout)
            self.assertIn("user=root", result.stdout)
            self.assertNotIn("user=live", result.stdout)


if __name__ == "__main__":
    unittest.main()
