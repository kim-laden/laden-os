#!/usr/bin/env python3
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUARD = ROOT / "profile/laden-os/airootfs/usr/lib/laden-os/install-guard"
RULES = ROOT / "profile/laden-os/airootfs/usr/lib/laden-os/protected-disks.txt"


def classify(lsblk, mounts, identity=False):
    fixture = {"lsblk": lsblk, "mounts": mounts}
    flag = "--identity" if identity else "--ignored"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".json") as handle:
        json.dump(fixture, handle)
        handle.flush()
        out = subprocess.check_output(
            [str(GUARD), "--fixture", handle.name, "--rules", str(RULES), flag],
            text=True,
        )
    return [line for line in out.splitlines() if line]


class InstallGuardTests(unittest.TestCase):
    def test_acer_and_host_disks_are_refused(self):
        ignored = classify(
            {
                "blockdevices": [
                    {
                        "name": "nvme1n1",
                        "type": "disk",
                        "serial": "SME8N00091140886D",
                        "model": "HFS001TEJ9X125N",
                        "children": [{"name": "nvme1n1p1", "label": "Acer"}],
                    },
                    {
                        "name": "nvme0n1",
                        "type": "disk",
                        "serial": "50026B768761A57F",
                        "model": "KINGSTON SNV3S1000G",
                    },
                    {
                        "name": "sda",
                        "type": "disk",
                        "serial": "VMWARE-EMPTY",
                        "model": "VMware Virtual S",
                    },
                ]
            },
            [],
        )
        self.assertIn("/dev/nvme1n1", ignored)
        self.assertIn("/dev/nvme0n1", ignored)
        self.assertNotIn("/dev/sda", ignored)
        identity = classify(
            {
                "blockdevices": [
                    {
                        "name": "nvme1n1",
                        "type": "disk",
                        "serial": "SME8N00091140886D",
                        "model": "HFS001TEJ9X125N",
                    },
                    {
                        "name": "sda",
                        "type": "disk",
                        "serial": "VMWARE-EMPTY",
                        "model": "VMware Virtual S",
                    },
                ]
            },
            [{"target": "/", "source": "/dev/sda2"}],
            identity=True,
        )
        self.assertEqual(identity, ["/dev/nvme1n1"])

    def test_acer_label_is_refused_without_the_serial(self):
        ignored = classify(
            {
                "blockdevices": [
                    {
                        "name": "sdb",
                        "type": "disk",
                        "serial": "OTHER",
                        "model": "Some Disk",
                        "children": [{"name": "sdb1", "partlabel": "acer"}],
                    }
                ]
            },
            [],
        )
        self.assertEqual(ignored, ["/dev/sdb"])

    def test_running_system_disk_is_refused(self):
        ignored = classify(
            {
                "blockdevices": [
                    {
                        "name": "sda",
                        "type": "disk",
                        "serial": "VMWARE-EMPTY",
                        "model": "VMware Virtual S",
                        "children": [{"name": "sda2", "mountpoints": ["/"]}],
                    }
                ]
            },
            [{"target": "/", "source": "/dev/sda2"}],
        )
        self.assertEqual(ignored, ["/dev/sda"])


if __name__ == "__main__":
    unittest.main()
