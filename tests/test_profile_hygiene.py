#!/usr/bin/env python3
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "profile/laden-os"


class ProfileHygieneTests(unittest.TestCase):
    def test_profile_does_not_embed_host_or_rejected_assets(self):
        banned = ("/home/laden", "laden-emerald", "[cachyos", "BEGIN PRIVATE KEY", "BEGIN OPENSSH")
        installer = PROFILE / "airootfs/usr/lib/laden-os/install-finalize"
        for path in PROFILE.rglob("*"):
            if not path.is_file() or path.is_symlink():
                continue
            text = path.read_bytes()
            if path == installer:
                text = text.replace(b"/home/laden", b"")
            for item in banned:
                self.assertNotIn(item.encode(), text, f"{item} in {path}")

    def test_default_wallpaper_is_the_8k_asset(self):
        script = (PROFILE / "airootfs/usr/lib/laden-os/apply-wallpaper").read_text(encoding="utf-8")
        self.assertIn("laden-os-lets-do-it-v2-7680x4320.png", script)
        self.assertIn("b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f", script)
        self.assertIn("preserveAspectCrop", script)
        self.assertNotIn("1920x1080.png", script)
        missing = script.index("default wallpaper missing")
        self.assertIn("exit 1", script[missing:missing + 160])
        self.assertNotIn("exit 0", script[missing:missing + 80])
        applets = (
            PROFILE / "airootfs/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "Image=file:///usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png",
            applets,
        )
        self.assertIn("FillMode=2", applets)
        self.assertNotIn("laden-os-lets-do-it-7680x4320.png", applets)

    def test_development_access_is_not_in_the_profile(self):
        tree = PROFILE / "airootfs"
        banned = ("10-laden-dev", "99-laden-dev.conf", "AllowUsers dev")
        cleanup = {
            tree / "usr/lib/laden-os/install-finalize",
            tree / "usr/lib/laden-os/install-system",
        }
        for path in tree.rglob("*"):
            if not path.is_file() or path.is_symlink():
                continue
            text = path.read_bytes()
            if path in cleanup:
                self.assertNotIn(b"NOPASSWD", text, f"NOPASSWD in {path}")
                self.assertNotIn(b"AllowUsers dev", text, f"AllowUsers dev in {path}")
                self.assertNotIn(b"BEGIN PRIVATE KEY", text, f"private key in {path}")
                continue
            for item in banned:
                self.assertNotIn(item.encode(), text, f"{item} in {path}")
        exclude = (PROFILE / "dev-vm-sync-exclude.txt").read_text(encoding="utf-8")
        self.assertIn("etc/mkinitcpio.conf.d/archiso.conf", exclude)
        self.assertIn("etc/systemd/system/sshd.service", exclude)


if __name__ == "__main__":
    unittest.main()
