#!/usr/bin/env python3
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FINALIZE = ROOT / "profile/laden-os/airootfs/usr/lib/laden-os/install-finalize"
PROFILE = ROOT / "profile/laden-os"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


class InstallFinalizeTests(unittest.TestCase):
    def make_root(self, connections: str) -> Path:
        work = Path(tempfile.mkdtemp(prefix="laden-finalize-"))
        self.addCleanup(subprocess.call, ["rm", "-rf", str(work)])
        write(work / "etc/laden-os/product.conf", "name=Laden OS\nintel_capture=off\n")
        write(
            work / "etc/motd",
            "Laden OS\nThe live session is discarded on reboot. SSH is off.\n",
        )
        write(work / "etc/machine-id", "uninitialized\n")
        write(work / "etc/plasmalogin.conf", "[Autologin]\nUser=live\n")
        write(work / "etc/sudoers.d/10-laden-live", "live ALL=(ALL:ALL) NOPASSWD: ALL\n")
        write(work / "etc/polkit-1/rules.d/49-laden-live.rules", "polkit.addRule\n")
        write(work / "etc/xdg/kscreenlockerrc", "Lock=false\n")
        write(work / "etc/xdg/powerdevilrc", "LockBeforeTurnOffDisplay=false\n")
        write(work / "etc/skel/.config/kscreenlockerrc", "Lock=false\n")
        write(
            work / "etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc",
            "Image=file:///usr/share/backgrounds/laden/laden-os-lets-do-it-7680x4320.png\n",
        )
        write(work / "etc/mkinitcpio.conf.d/archiso.conf", "HOOKS=(archiso)\n")
        write(work / "etc/sudoers.d/10-laden-dev", "dev ALL=(ALL:ALL) NOPASSWD: ALL\n")
        write(work / "etc/ssh/sshd_config.d/99-laden-dev.conf", "AllowUsers dev\n")
        write(work / "etc/laden-os/dev-vm.conf", "role=development\n")
        write(work / "etc/systemd/journald.conf.d/volatile-storage.conf", "Storage=volatile\n")
        write(work / "etc/systemd/logind.conf.d/do-not-suspend.conf", "IdleAction=ignore\n")
        write(work / "etc/systemd/system/multi-user.target.wants/pacman-init.service", "old\n")
        write(work / "etc/pacman.d/hooks/40-laden-live-user.hook", "# remove from airootfs!\n")
        write(work / "etc/passwd", "root:x:0:0:root:/root:/bin/bash\nlive:x:1000:1000::/home/live:/bin/fish\n")
        write(work / "etc/shadow", "root:!:1::::::\nlive:!:1::::::\n")
        write(work / "etc/ssh/ssh_host_ed25519_key", "old-host-key\n")
        write(work / "home/live/.config/the-cockpit/connections.lua", connections)
        write(
            work / "home/live/.config/plasma-org.kde.plasma.desktop-appletsrc",
            "Image=laden-os-lets-do-it-7680x4320.png\n",
        )
        write(work / "home/laden/notes.txt", "leaked\n")
        write(work / "var/lib/laden-os/service-identity.key", "old-key\n")
        write(work / "var/lib/laden-os/service-identity.fingerprint", "old\n")
        os.chmod(work / "etc/sudoers.d/10-laden-live", 0o440)
        return work

    def run_finalize(self, root: Path, mode: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["LADEN_INSTALL_ROOT"] = str(root)
        return subprocess.run(
            ["bash", str(FINALIZE), mode],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def test_prepare_and_finish_remove_live_state_and_keep_identity(self):
        root = self.make_root("-- Published example. No active entry.\n")
        prepared = self.run_finalize(root, "prepare")
        self.assertEqual(prepared.returncode, 0, prepared.stderr)
        finished = self.run_finalize(root, "finish")
        self.assertEqual(finished.returncode, 0, finished.stderr)

        self.assertFalse((root / "etc/plasmalogin.conf").exists())
        motd = (root / "etc/motd").read_text(encoding="utf-8")
        self.assertIn("This system is installed on disk.", motd)
        self.assertNotIn("discarded on reboot", motd)
        self.assertFalse((root / "etc/sudoers.d/10-laden-live").exists())
        self.assertFalse((root / "etc/polkit-1/rules.d/49-laden-live.rules").exists())
        self.assertFalse((root / "etc/xdg/kscreenlockerrc").exists())
        self.assertFalse((root / "etc/sudoers.d/10-laden-dev").exists())
        self.assertFalse((root / "etc/ssh/sshd_config.d/99-laden-dev.conf").exists())
        self.assertFalse((root / "etc/mkinitcpio.conf.d/archiso.conf").exists())
        self.assertFalse((root / "etc/pacman.d/hooks/40-laden-live-user.hook").exists())
        self.assertFalse((root / "home/live").exists())
        self.assertFalse((root / "home/laden").exists())
        self.assertFalse((root / "etc/ssh/ssh_host_ed25519_key").exists())
        self.assertNotIn("live:", (root / "etc/passwd").read_text(encoding="utf-8"))
        self.assertIn("root:", (root / "etc/passwd").read_text(encoding="utf-8"))
        applets = (root / "etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc").read_text(
            encoding="utf-8"
        )
        self.assertIn("laden-os-lets-do-it-v2-7680x4320.png", applets)
        self.assertNotIn("laden-os-lets-do-it-7680x4320.png", applets)
        machine_id = (root / "etc/machine-id").read_text(encoding="utf-8").strip()
        self.assertRegex(machine_id, r"^[0-9a-f]{32}$")
        self.assertEqual(
            (root / "var/lib/laden-os/service-identity.fingerprint").read_text(encoding="utf-8").strip(),
            "generated-in-test-mode",
        )
        self.assertFalse((root / "var/lib/laden-os/service-identity.key").exists())
        self.assertTrue((root / "etc/mkinitcpio.conf.d/laden-installed.conf").is_file())
        self.assertEqual(os.readlink(root / "etc/systemd/system/sshd.service"), "/dev/null")
        cockpit = root / "etc/skel/.config/the-cockpit/connections.lua"
        self.assertTrue(cockpit.is_file())
        again = self.run_finalize(root, "finish")
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual((root / "etc/machine-id").read_text(encoding="utf-8").strip(), machine_id)
        self.assertEqual(stat.S_IMODE((root / "etc/machine-id").stat().st_mode), 0o644)

    def test_active_cockpit_entry_fails_prepare(self):
        root = self.make_root('  { host = "example" }\n')
        prepared = self.run_finalize(root, "prepare")
        self.assertNotEqual(prepared.returncode, 0)
        self.assertIn("active entry", prepared.stderr)

    def test_calamares_sequence_finalizes_before_bootloader(self):
        settings = (PROFILE / "airootfs/etc/calamares/settings.conf").read_text(encoding="utf-8")
        execute = settings.split("- exec:", 1)[1]
        prepare = execute.index("shellprocess@prepare")
        users = execute.index("\n  - users\n")
        finish = execute.index("shellprocess@finalize")
        boot = execute.index("\n  - bootloader\n")
        self.assertLess(prepare, users)
        self.assertLess(users, finish)
        self.assertLess(finish, boot)
        partition = (PROFILE / "airootfs/usr/share/laden-os/installer/partition.conf").read_text(
            encoding="utf-8"
        )
        self.assertIn('efiSystemPartition: "/boot"', partition)
        self.assertIn("small", partition)
        users_conf = (PROFILE / "airootfs/etc/calamares/modules/users.conf").read_text(encoding="utf-8")
        self.assertIn("sudoersConfigureWithGroup: true", users_conf)
        self.assertIn("doAutologin: false", users_conf)


if __name__ == "__main__":
    unittest.main()
