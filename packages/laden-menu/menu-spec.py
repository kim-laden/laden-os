# Laden OS application menu: single source of truth.
# gen.py turns this into laden.menu, .directory files, icons and Red Team launchers.

# Duplicates / developer leftovers hidden from the menu (still installed, still runnable).
HIDDEN = """com.rustdesk.RustDesk.desktop 
uxterm.desktop xterm.desktop avahi-discover.desktop bssh.desktop bvnc.desktop
rygel-preferences.desktop lstopo.desktop qv4l2.desktop qvidcap.desktop
designer-qt4.desktop linguist-qt4.desktop qdbusviewer-qt4.desktop assistant-qt4.desktop
org.kde.kdevelop_ps.desktop kdesystemsettings.desktop org.kde.kdeconnect.nonplasma.desktop
org.torproject.torbrowser-launcher.settings.desktop vscodium-wayland.desktop
org.kde.kalgebramobile.desktop gnome-system-monitor-kde.desktop fluid1.3.desktop
org.kde.kosmindoormap.desktop org.kde.kirigami2.gallery.desktop org.gnome.Evince.desktop
jconsole-java11-openjdk.desktop jshell-java11-openjdk.desktop
jconsole-java-openjdk.desktop jshell-java-openjdk.desktop
org.kde.plasmaengineexplorer.desktop org.kde.plasma.lookandfeelexplorer.desktop
org.kde.plasma.themeexplorer.desktop rustdesk-link.desktop
""".split()

# Red Team GUI apps (by desktop file id) -> submenu
RT_GUI = {
  "recon":    ["maltego.desktop", "zenmap.desktop", "zenmap-root.desktop"],
  "web":      ["burpsuite.desktop", "burp-browser.desktop", "zaproxy.desktop"],
  "wireless": ["kismet.desktop", "one.flipperzero.qFlipper.desktop"],
  "exploit":  ["armitage.desktop"],
  "passwords":["hashcat-gui.desktop", "johnny.desktop"],
  "sniffing": ["org.wireshark.Wireshark.desktop", "wireshark.desktop", "networkminer.desktop", "ettercap.desktop"],
  "forensics":["autopsy.desktop", "guymager.desktop"],
  "reverse":  ["ghidra.desktop", "org.radare.iaito.desktop", "cutter.desktop", "re.rizin.cutter.desktop"],
  "tunnels":  ["rustdesk.desktop", "org.remmina.Remmina.desktop",
               "org.kde.krdc.desktop", "vncviewer.desktop", "org.gnome.Connections.desktop",
               "proton.vpn.app.gtk.desktop", "org.torproject.torbrowser-launcher.desktop"],
}

# Red Team terminal launchers: (submenu, binary, display name, comment, help args)
# Only tools that are installed show up (TryExec).
RT_CLI = [
  ("recon","nmap","Nmap","Network scanner and port mapper","--help"),
  ("recon","rustscan","RustScan","Very fast port scanner","--help"),
  ("recon","masscan","Masscan","Internet-scale port scanner","--help"),
  ("recon","amass","Amass","Attack surface and subdomain mapping","-h"),
  ("recon","subfinder","Subfinder","Passive subdomain discovery","-h"),
  ("recon","theHarvester","theHarvester","E-mails, names and hosts from OSINT","-h"),
  ("recon","dnsrecon","DNSRecon","DNS enumeration","-h"),
  ("recon","whatweb","WhatWeb","Identify web technologies","--help"),
  ("recon","enum4linux-ng","enum4linux-ng","SMB/Windows enumeration","-h"),
  ("recon","nxc","NetExec","Network service swiss-army knife (SMB, WinRM, LDAP...)","--help"),
  ("web","sqlmap","sqlmap","Automatic SQL injection","-h"),
  ("web","ffuf","ffuf","Fast web fuzzer","-h"),
  ("web","gobuster","Gobuster","Directory, DNS and vhost brute forcing","--help"),
  ("web","feroxbuster","feroxbuster","Recursive content discovery","--help"),
  ("web","nikto","Nikto","Web server scanner","-Help"),
  ("web","wpscan","WPScan","WordPress scanner","--help"),
  ("web","xsstrike","XSStrike","XSS detection suite","-h"),
  ("web","httpx","httpx","HTTP probing toolkit","-h"),
  ("web","nuclei","Nuclei","Template based vulnerability scanner","-h"),
  ("web","beef","BeEF","Browser Exploitation Framework (web UI on :3000)",""),
  ("wireless","aircrack-ng","Aircrack-ng","Wi-Fi auditing suite (needs sudo)","--help"),
  ("wireless","wifite","Wifite","Automated Wi-Fi auditor (needs sudo)","-h"),
  ("wireless","hcxdumptool","hcxdumptool","Capture Wi-Fi handshakes/PMKIDs (needs sudo)","-h"),
  ("wireless","reaver","Reaver","WPS attack tool","-h"),
  ("wireless","bully","Bully","WPS brute force","-h"),
  ("wireless","mdk4","MDK4","Wi-Fi stress testing","--help"),
  ("exploit","msfconsole","Metasploit Console","Metasploit Framework console","!"),
  ("exploit","msfvenom","msfvenom","Payload generator","-h"),
  ("exploit","searchsploit","SearchSploit","Search Exploit-DB offline","-h"),
  ("exploit","sliver-client","Sliver","Sliver C2 client","!"),
  ("exploit","sliver-server","Sliver Server","Sliver C2 server","!"),
  ("exploit","secretsdump.py","Impacket","Impacket tools (secretsdump, psexec, ...)","-h"),
  ("exploit","evil-winrm","Evil-WinRM","WinRM shell","-h"),
  ("passwords","hashcat","Hashcat","GPU password recovery (NVIDIA CUDA)","--help"),
  ("passwords","john","John the Ripper","Password cracker",""),
  ("passwords","hydra","Hydra","Online login brute forcing","-h"),
  ("passwords","crunch","Crunch","Wordlist generator",""),
  ("passwords","cewl","CeWL","Wordlists from websites","--help"),
  ("passwords","hashid","hashID","Identify hash types","-h"),
  ("passwords","lazagne","LaZagne","Recover stored credentials","-h"),
  ("passwords","firefox-decrypt","firefox_decrypt","Extract Firefox saved logins","-h"),
  ("passwords","mimipenguin","mimipenguin","Dump Linux login passwords (needs sudo)",""),
  ("sniffing","tshark","TShark","Wireshark in the terminal","-h"),
  ("sniffing","tcpdump","tcpdump","Packet capture","--help"),
  ("sniffing","bettercap","bettercap","Network attack and monitoring (needs sudo)","-h"),
  ("sniffing","ettercap","Ettercap","MITM suite (ettercap -G for the GUI)","-h"),
  ("sniffing","mitmproxy","mitmproxy","Interactive HTTPS proxy","--help"),
  ("sniffing","responder","Responder","LLMNR/NBT-NS poisoner (needs sudo)","-h"),
  ("sniffing","sslstrip","sslstrip","HTTPS downgrade","-h"),
  ("sniffing","sslsplit","SSLsplit","Transparent TLS interception","-h"),
  ("forensics","vol","Volatility 3","Memory forensics","-h"),
  ("forensics","fls","The Sleuth Kit","Disk image forensics (fls, icat, mmls ...)",""),
  ("forensics","foremost","Foremost","File carving","-h"),
  ("forensics","scalpel","Scalpel","File carving","-h"),
  ("forensics","bulk_extractor","bulk_extractor","Bulk feature extraction","-h"),
  ("forensics","chainsaw","Chainsaw","Windows event log hunting","--help"),
  ("forensics","dc3dd","dc3dd","Forensic disk imaging","--help"),
  ("forensics","unblob","unblob","Extract firmware and archives","--help"),
  ("reverse","gdb","GDB","GNU debugger","--help"),
  ("reverse","r2","radare2","Reverse engineering framework","-h"),
  ("reverse","rizin","Rizin","Reverse engineering framework","-h"),
  ("reverse","binwalk","Binwalk","Firmware analysis","--help"),
  ("reverse","readpe","readpe","PE file inspector (pev)","--help"),
  ("tunnels","tailscale","Tailscale","Mesh VPN: tailscale status / up","status"),
  ("tunnels","chisel","Chisel","TCP/UDP tunnel over HTTP","--help"),
  ("tunnels","ligolo-proxy","Ligolo-ng","Tunnelling via TUN interface","-h"),
  ("tunnels","socat","socat","Relay anything to anything","-h"),
  ("tunnels","ncat","Ncat","Netcat from Nmap","-h"),
  ("tunnels","proxychains4","ProxyChains","Force traffic through proxies",""),
  ("tunnels","wg","WireGuard","WireGuard tools","--help"),
  ("tunnels","openvpn","OpenVPN","OpenVPN client","--help"),
]

RT_SUBS = [  # id, name, comment
  ("recon","Recon","Scanning, OSINT and enumeration"),
  ("web","Web","Web application testing"),
  ("wireless","Wireless & Hardware","Wi-Fi, radio and hardware tools"),
  ("exploit","Exploitation & C2","Frameworks, payloads and command & control"),
  ("passwords","Passwords","Cracking and credential recovery"),
  ("sniffing","Sniffing & MITM","Capture and intercept traffic"),
  ("forensics","Forensics","Disk, memory and log forensics"),
  ("reverse","Reverse Engineering","Debuggers, disassemblers, firmware"),
  ("tunnels","Remote Access & Tunnels","Remote desktop, VPN, pivoting"),
]

GAMING_TOOLS = """steam.desktop net.lutris.Lutris.desktop com.heroicgameslauncher.hgl.desktop
net.davidotek.pupgui2.desktop protontricks.desktop winetricks.desktop io.github.Faugus.faugus-launcher.desktop
io.github.benjamimgois.goverlay.desktop io.github.radiolamp.mangojuice.desktop io.github.Foldex.AdwSteamGtk.desktop
org.prismlauncher.PrismLauncher.desktop org.libretro.RetroArch.desktop org.vinegarhq.Sober.desktop
Superposition.desktop io.github.wivrn.wivrn.desktop wayvr.desktop""".split()
STREAM = """com.obsproject.Studio.desktop dev.lizardbyte.app.Sunshine.desktop com.moonlight_stream.Moonlight.desktop
streamlink-twitch-gui.desktop com.github.wwmm.easyeffects.desktop org.pipewire.Helvum.desktop
org.rncbc.qpwgraph.desktop hu.irl.cameractrls.desktop guvcview.desktop org.kde.kamoso.desktop
org.kde.plasma.camera.desktop org.gnome.Snapshot.desktop soundux.desktop discord.desktop""".split()
LADEN = """arch-update.desktop org.laden.KernelManager.desktop org.laden.Scheduler.desktop laden-ops.desktop
cockpit.desktop cockpit-hp.desktop systemsettings.desktop btrfs-assistant.desktop limine-snapper-restore.desktop
io.github.ilya_zlobintsev.LACT.desktop nvidia-settings.desktop org.kde.plasma-welcome.desktop
""".split()
TERMINALS = """lcp.desktop the-cockpit.desktop org.wezfurlong.wezterm.desktop org.kde.konsole.desktop kitty.desktop Alacritty.desktop
org.kde.yakuake.desktop org.gnome.Console.desktop""".split()

# Top level, in order: id, name, comment, rules (python dict consumed by gen.py)
TOP = [
  ("laden","Laden","Laden OS: updates, kernels, scheduler and settings", {"files": LADEN}),
  ("gaming","Gaming","Play, launch and tune games", {"subs": [
      ("library","Game Library","Your installed games", {"cats_all":[["Game"]], "not_cats":["KDE","Education"], "not_files": GAMING_TOOLS}),
      ("launchers","Launchers & Tools","Steam, Lutris, Heroic, Proton and overlays", {"files": GAMING_TOOLS}),
      ("casual","Casual Games","Quick games for a break", {"cats_all":[["Game","KDE"],["Game","GNOME"],["Game","Education"]], "not_files": GAMING_TOOLS}),
  ]}),
  ("create","Create","Video, audio, graphics and 3D", {"subs": [
      ("video","Video","Edit and convert video", {"cats_all":[["AudioVideoEditing","Video"],["VideoEditing"]], "files":["org.kde.kdenlive.desktop","org.shotcut.Shotcut.desktop","fr.handbrake.ghb.desktop","com.blackmagicdesign.resolve.desktop","DaVinciResolve.desktop","org.kde.k3b.desktop"], "not_files": ["cockos-reaper.desktop"]+STREAM}),
      ("audio","Audio & Music","Record, mix and produce", {"cats_any":["AudioEditing","Sequencer","X-Multitrack","Midi"], "cats_all":[["Audio","AudioVideoEditing"],["Audio","Recorder"]], "files":["cockos-reaper.desktop","org.kde.kmix.desktop","org.kde.krecorder.desktop","lsp-plugins.desktop","org.kde.audex.desktop","org.ffado.FfadoMixer.desktop"], "not_files": STREAM+["org.kde.kdenlive.desktop","org.shotcut.Shotcut.desktop","vlc.desktop"]}),
      ("graphics","Graphics & Photo","Draw, paint, edit photos", {"cats_any":["2DGraphics","RasterGraphics","VectorGraphics","Photography","Graphics"], "not_cats":["3DGraphics","Office","Viewer","Scanning"], "not_files":["net.christianbeier.Gromit-MPX.desktop","org.kde.kruler.desktop"]}),
      ("3d","3D","Model, render and simulate", {"cats_any":["3DGraphics"], "files":["org.freecad.FreeCAD.desktop","freecad.desktop"]}),
  ]}),
  ("stream","Stream","Broadcast, capture and route audio", {"files": STREAM}),
  ("media","Media","Watch, listen and view photos", {"files":["org.kde.gwenview.desktop","org.gnome.Loupe.desktop","org.kde.koko.desktop"], "cats_any":["Player","TV","Music","AudioVideo"], "not_cats":["AudioVideoEditing","AudioEditing","Sequencer","Midi","Mixer","Education"], "not_files": STREAM+["org.kde.krecorder.desktop","org.kde.k3b.desktop","org.kde.audex.desktop","pavucontrol.desktop","org.pulseaudio.pavucontrol.desktop","org.kde.kmix.desktop","cockos-reaper.desktop"]}),
  ("redteam","Red Team","Pentesting and security toolkit. Use it on systems you are allowed to test.", {"rt": True}),
  ("internet","Internet","Browse, chat, mail and share", {"cats_any":["Network","WebBrowser","Email","InstantMessaging","Chat","IRCClient","Feed","P2P","FileTransfer"], "not_cats":["Game","AudioVideo","Office","Development"], "not_files": STREAM+["steam.desktop","wireless-workbench.desktop"]}),
  ("office","Office","Documents, mail, calendar and reading", {"cats_any":["Office","WordProcessor","Spreadsheet","Presentation","Calendar","ContactManagement","Viewer"], "not_cats":["Development","Photography","Settings","Video","AudioVideo"], "not_files":["org.kde.gwenview.desktop","org.gnome.Loupe.desktop","org.kde.koko.desktop","org.kde.kgraphviewer.desktop"]}),
  ("dev","Develop","Code, build and debug", {"cats_any":["Development","IDE","TextEditor"], "files":["org.kde.kgraphviewer.desktop"]}),
  ("system","System","Terminals, disks, monitors and virtual machines", {"cats_any":["System","Settings","Monitor","TerminalEmulator","HardwareSettings","PackageManager","Filesystem","FileManager","Emulator"], "not_cats":["Game","Development"], "not_files": LADEN+["org.kde.kinfocenter.desktop"], "files": TERMINALS+["org.kde.kinfocenter.desktop","org.kde.kmenuedit.desktop"]}),
  ("utilities","Utilities","Handy everyday tools", {"cats_any":["Utility","Accessibility","Archiving","Calculator","Clock","Scanning"], "not_cats":["Development","Game","TextEditor","TerminalEmulator","Office","System","Network"], "not_files": LADEN+GAMING_TOOLS+STREAM, "files":["net.christianbeier.Gromit-MPX.desktop","org.kde.kruler.desktop","org.kde.kcolorchooser.desktop","org.kde.spectacle.desktop"]}),
  ("learn","Learn & Science","Education and science", {"cats_any":["Education","Science"], "not_cats":["Game"]}),
  ("help","Help","Guides and documentation", {"cats_any":["Documentation"], "not_cats":["System"]}),
]
FAVORITES = ["steam.desktop","Counter-Strike 2.desktop","com.obsproject.Studio.desktop","org.kde.kdenlive.desktop",
             "blender.desktop","lcp.desktop","firefox.desktop","org.kde.dolphin.desktop","arch-update.desktop"]
