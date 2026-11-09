#!/usr/bin/env python3
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / "profile/laden-os/airootfs/usr/bin/laden-layout"
FIXTURE = ROOT / "tests/fixtures/outputs.json"


class LayoutTests(unittest.TestCase):
    def test_primary_and_largest_come_from_json(self):
        completed = subprocess.run(
            [str(LAYOUT), "--json", str(FIXTURE)],
            check=True,
            capture_output=True,
            text=True,
        )
        lines = dict(line.split("=", 1) for line in completed.stdout.splitlines())
        self.assertEqual(lines["primary"], "PANEL-0")
        self.assertEqual(lines["primary_pixels"], str(1920 * 1080))
        self.assertEqual(lines["largest"], "EXTERNAL-0")
        self.assertEqual(lines["largest_pixels"], str(2560 * 1440))

    def test_source_has_no_connector_literals(self):
        text = LAYOUT.read_text(encoding="utf-8")
        for literal in ("DP-", "HDMI", "eDP", "VGA-"):
            self.assertNotIn(literal, text)


if __name__ == "__main__":
    unittest.main()
