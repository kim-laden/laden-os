#!/usr/bin/env python3
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "profile/laden-os"
AI = PROFILE / "airootfs"


class LiveSessionFixTests(unittest.TestCase):
    def test_shortcuts_are_single_chords(self):
        for relative in (
            "etc/skel/.config/kglobalshortcutsrc",
            "etc/xdg/kglobalshortcutsrc",
        ):
            text = (AI / relative).read_text(encoding="utf-8")
            self.assertIn("[services][lcp.desktop]\n_launch=Alt+T\n", text)
            self.assertIn("[services][lcp-toggle.desktop]\n_launch=Alt+Q\n", text)
            self.assertIn("[services][org.kde.konsole.desktop]\n_launch=none\n", text)
            self.assertNotIn("Alt+T,Alt+T", text)
            self.assertNotIn(",LCP", text)
        lcp = (AI / "usr/share/applications/lcp.desktop").read_text(encoding="utf-8")
        toggle = (AI / "usr/share/applications/lcp-toggle.desktop").read_text(encoding="utf-8")
        self.assertIn("X-KDE-Shortcuts=Alt+T\n", lcp)
        self.assertIn("X-KDE-Shortcuts=Alt+Q\n", toggle)
        script = (AI / "usr/lib/laden-os/apply-shortcuts").read_text(encoding="utf-8")
        self.assertIn("134217812", script)
        self.assertIn("134217809", script)
        self.assertIn("lcp.desktop", script)

    def test_top_panel_stays_docked(self):
        applets = (AI / "etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc").read_text(
            encoding="utf-8"
        )
        self.assertIn("location=3\n", applets)
        self.assertIn("AppletOrder=4;5;26;6;7;8;20;21\n", applets)
        for relative in (
            "etc/skel/.config/plasmashellrc",
            "etc/xdg/plasmashellrc",
        ):
            text = (AI / relative).read_text(encoding="utf-8")
            self.assertIn("[PlasmaViews][Panel 2]\nfloating=0\n", text)

    def test_installer_keeps_the_wayland_display(self):
        policy = (AI / "usr/share/polkit-1/actions/org.ladenos.install.policy").read_text(
            encoding="utf-8"
        )
        self.assertIn("/usr/bin/laden-install", policy)
        self.assertIn("org.freedesktop.policykit.exec.allow_gui", policy)
        self.assertIn(">true<", policy)
        self.assertIn("<allow_any>no</allow_any>", policy)
        desktop = (AI / "usr/share/applications/laden-install.desktop").read_text(encoding="utf-8")
        self.assertIn("Exec=/usr/bin/laden-install\n", desktop)
        self.assertNotIn("Exec=pkexec", desktop)
        script = (AI / "usr/bin/laden-install").read_text(encoding="utf-8")
        self.assertIn("exec pkexec /usr/bin/laden-install", script)
        self.assertIn("QT_QPA_PLATFORM=wayland", script)
        self.assertIn("The installer has no display.", script)
        sudoers = (AI / "etc/sudoers.d/10-laden-live").read_text(encoding="utf-8")
        self.assertIn("WAYLAND_DISPLAY", sudoers)
        self.assertIn("XDG_RUNTIME_DIR", sudoers)

    def test_lcp_opens_at_the_desktop_pane_and_colors_commands(self):
        colors = (AI / "etc/fish/conf.d/laden-colors.fish").read_text(encoding="utf-8")
        self.assertIn("fish_color_command '#00ff9d'", colors)
        self.assertIn("fish_color_param '#f4fff9'", colors)
        self.assertIn("fish_color_quote '#e6d36a'", colors)
        self.assertIn("fish_color_redirection '#3df0ff'", colors)
        self.assertIn("fish_color_error '#ff5c7a'", colors)
        self.assertIn("fish_color_valid_path '#6ec8ff'", colors)
        self.assertNotIn("/home/laden", colors)
        greeting = (AI / "etc/skel/.config/fish/config.fish").read_text(encoding="utf-8")
        self.assertIn('Laden OS — Let\'s do it!', greeting)
        local = (AI / "etc/skel/.config/the-cockpit/local.lua").read_text(encoding="utf-8")
        self.assertIn("set_inner_size(960, 1024)", local)
        self.assertIn("gui-startup", local)
        self.assertIn("#6ec8ff", local)
        self.assertIn("#e6d36a", local)
        self.assertNotIn("/home/laden", local)
        installer = (AI / "usr/lib/laden-os/install-cockpit").read_text(encoding="utf-8")
        self.assertIn('install -m 644 -o live -g live "$laden_local"', installer)
        self.assertLess(
            installer.index("bash \"$src/install.sh\""),
            installer.index('"$laden_local"'),
        )

    def test_autopsy_jdk_points_at_java_17(self):
        packages = (PROFILE / "packages.d/lab.txt").read_text(encoding="utf-8")
        self.assertIn("\njdk17-openjdk\n", packages)
        hook = (AI / "etc/pacman.d/hooks/90-laden-autopsy-jdk.hook").read_text(encoding="utf-8")
        self.assertIn("Exec = /usr/lib/laden-os/autopsy-jdk", hook)
        self.assertNotIn("remove from airootfs", hook)
        script = AI / "usr/lib/laden-os/autopsy-jdk"
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            conf = root / "opt/autopsy/etc/autopsy.conf"
            java = root / "usr/lib/jvm/java-17-openjdk/bin/java"
            conf.parent.mkdir(parents=True)
            java.parent.mkdir(parents=True)
            conf.write_text('default_options="--branding autopsy"\njdkhome="jre"\n', encoding="utf-8")
            java.write_text(
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    echo 'openjdk version "17.0.16"' >&2
                    """
                ),
                encoding="utf-8",
            )
            java.chmod(java.stat().st_mode | stat.S_IEXEC)
            completed = subprocess.run(
                ["bash", str(script), str(root)],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertIn('jdkhome="/usr/lib/jvm/java-17-openjdk"', conf.read_text(encoding="utf-8"))
            self.assertNotIn('jdkhome="jre"', conf.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
