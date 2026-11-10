#!/usr/bin/env python3
"""Generate the Laden OS meta-package PKGBUILDs (../laden-<name>/PKGBUILD).
Hard depends = small essentials (all resolvable from the configured repos);
everything big or optional goes to optdepends.  Edit the lists here, re-run."""
import os
VER, REL = "2026.11.09", "1"
RELS = {"desktop": "2", "gaming": "2", "streaming": "2"}  # per-meta pkgrel bumps
B = "[blackarch]"
M = {
 "desktop": ("Laden OS base desktop: KDE Plasma, Laden branding, tools and audio", [
   "laden-branding","laden-desktop-settings","laden-keyring","laden-mirrorlist",
   "laden-update","laden-kernel-manager","laden-scheduler","laden-menu","laden-terminal",
   "plasma-desktop","plasma-workspace","sddm","sddm-kcm","plasma-nm","plasma-pa","bluedevil",
   "powerdevil","kscreen","kde-gtk-config","breeze-gtk","xdg-desktop-portal-kde",
   "dolphin","konsole","ark","spectacle","networkmanager",
   "pipewire","pipewire-pulse","pipewire-alsa","wireplumber",
   "fish","fastfetch","noto-fonts","noto-fonts-emoji","ttf-jetbrains-mono"], [
   ("linux-laden","Laden kernel (default boot entry)"),
   ("linux-laden-headers","headers for DKMS modules (NVIDIA, xpadneo)"),
   ("linux-cachyos-lts","fallback LTS kernel"),
   ("limine","bootloader"),("plymouth","boot splash"),
   ("wezterm","Laden default terminal"),("kate","text editor"),("firefox","web browser"),
   ("flatpak","Flatpak apps"),("discover","software center"),
   ("btrfs-assistant","btrfs snapshots GUI"),("snapper","btrfs snapshots"),
   ("paru","AUR helper"),("yay","AUR helper"),("chwd","hardware/driver detection"),
   ("power-profiles-daemon","power profiles"),("ananicy-cpp","process priority daemon"),
   ("cachyos-settings","CachyOS system tuning"),("pipewire-jack","JACK apps on PipeWire")]),
 "gaming": ("Laden OS gaming: Steam, Proton/Wine, overlays, controllers", [
   "steam","steam-devices","gamemode","lib32-gamemode","mangohud","lib32-mangohud","gamescope",
   "vulkan-icd-loader","lib32-vulkan-icd-loader","lib32-pipewire",
   "umu-launcher","protonup-qt","ttf-liberation","laden-gaming-tweaks"], [
   ("proton-cachyos-slr","Proton-CachyOS (Steam Linux Runtime), ~1.6 GB"),
   ("proton-cachyos-native","Proton-CachyOS native build, ~1.6 GB"),
   ("wine-cachyos-opt","Wine-CachyOS, ~770 MB"),("wine","Wine, ~600 MB"),
   ("wine-mono","Wine .NET"),("wine-gecko","Wine HTML engine"),
   ("winetricks","Wine helper"),("protontricks","winetricks for Proton"),
   ("lutris","game launcher"),("heroic-games-launcher","Epic/GOG/Amazon launcher"),
   ("faugus-launcher","simple umu/Proton launcher"),("prismlauncher","Minecraft launcher"),
   ("goverlay","MangoHud GUI"),("mangojuice","MangoHud GUI"),
   ("xpadneo-dkms","Xbox wireless controller driver"),("antimicrox","map controller to keys"),
   ("sunshine","game-stream host"),("moonlight-qt","game-stream client"),
   ("discord","voice chat"),("wqy-zenhei","CJK font for game launchers"),
   ("nvidia-utils","NVIDIA userspace (chwd picks the driver)"),
   ("lib32-nvidia-utils","NVIDIA 32-bit userspace for Steam/Proton"),
   ("nvidia-settings","NVIDIA settings"),("opencl-nvidia","NVIDIA OpenCL"),
   ("lib32-opencl-nvidia","NVIDIA 32-bit OpenCL"),("nvidia-prime","PRIME offload (laptops)"),
   ("vulkan-intel","Intel Vulkan"),("lib32-vulkan-intel","Intel 32-bit Vulkan"),
   ("vulkan-radeon","AMD Vulkan"),("lib32-vulkan-radeon","AMD 32-bit Vulkan"),
   ("lib32-mesa","32-bit Mesa"),("cachyos-gaming-meta","CachyOS gaming bundle")]),
 "creator": ("Laden OS creator: video, audio and image editing", [
   "kdenlive","ffmpeg","imagemagick","mpv","yt-dlp","qpwgraph","easyeffects"], [
   ("blender","3D, ~385 MB"),("gimp","image editor"),("krita","painting"),
   ("inkscape","vector graphics"),("audacity","audio editor"),("tenacity","audio editor"),
   ("darktable","RAW photos"),("rawtherapee","RAW photos"),("digikam","photo manager"),
   ("gmic","image filters"),("shotcut","video editor"),("handbrake","video transcoder"),
   ("scribus","desktop publishing"),("freecad","CAD, ~300 MB"),
   ("ardour","DAW"),("reaper","DAW"),("calf","audio plugins"),("lsp-plugins","audio plugins"),
   ("rnnoise","noise suppression"),("helvum","PipeWire patchbay"),
   ("vlc","media player"),("vlc-plugins-all","all VLC plugins"),("mediainfo-gui","media info"),
   ("davinci-resolve","DaVinci Resolve [cachyos], ~3.3 GB download / 7.3 GB installed")]),
 "streaming": ("Laden OS streaming: OBS, PipeWire capture, virtual camera", [
   "obs-studio","pipewire","pipewire-pulse","wireplumber","xdg-desktop-portal",
   "gst-plugin-pipewire","v4l-utils","streamlink"], [
   ("obs-studio-browser","OBS with browser source/websocket [cachyos], provides obs-studio"),
   ("obs-vkcapture","Vulkan/OpenGL game capture"),("lib32-obs-vkcapture","32-bit game capture"),
   ("obs-gstreamer","GStreamer sources/encoders for OBS"),
   ("v4l2loopback-utils","v4l2loopback tools"),
   ("noise-suppression-for-voice","RNNoise mic filter"),("rnnoise","noise suppression"),
   ("easyeffects","mic/voice effects"),("qpwgraph","PipeWire patchbay"),
   ("libva-nvidia-driver","VA-API on NVIDIA"),("libva-utils","VA-API tools"),
   ("gst-plugin-va","VA-API GStreamer"),("gst-plugins-good","GStreamer plugins"),
   ("gst-plugins-bad","GStreamer plugins"),("gst-plugins-ugly","GStreamer plugins"),
   ("guvcview","webcam"),("kamoso","webcam"),("kdeconnect","phone integration"),
   ("scrcpy","Android screen mirror"),("gpu-screen-recorder","low-overhead recorder"),
   ("sunshine","game-stream host"),("moonlight-qt","game-stream client")]),
 "pentest": ("Laden OS pentest: network, wireless, password and forensics tools", [
   "nmap","wireshark-qt","tcpdump","openbsd-netcat","socat","john","hashcat","hashcat-utils",
   "aircrack-ng","hcxtools","hcxdumptool","wifite","reaver","bully","sqlmap","hydra",
   "gobuster","rustscan","impacket","bettercap","mitmproxy","macchanger","arp-scan",
   "gdb","yara","sleuthkit","foremost","volatility3","tor","openvpn","wireguard-tools",
   "smbclient","bind"], [
   ("metasploit","exploitation framework, ~460 MB"),
   ("burpsuite",f"web proxy {B}, ~720 MB"),("zaproxy","web proxy, ~270 MB"),
   ("ettercap","MITM"),("maltego",f"OSINT {B}, ~300 MB"),("beef",f"browser exploitation {B}"),
   ("ffuf",f"web fuzzer {B}"),("httpx",f"HTTP probe {B}"),("sliver",f"C2 {B}"),
   ("autopsy",f"forensics GUI {B}, ~1.8 GB"),("chipsec",f"firmware security {B}"),
   ("chkrootkit",f"rootkit check {B}"),("exploitdb","searchsploit, ~170 MB"),
   ("seclists",f"wordlists {B}, ~1.9 GB"),("nikto","web scanner"),("wpscan","WordPress scanner"),
   ("responder",f"LLMNR poisoner {B}"),("netexec",f"network exec (CME successor) {B}"),
   ("radare2","reverse engineering"),("ghidra","reverse engineering, ~740 MB"),
   ("binwalk","firmware analysis"),("masscan","fast port scanner"),
   ("feroxbuster",f"content discovery {B}"),("dirb",f"content discovery {B}"),
   ("wfuzz",f"web fuzzer {B}"),("amass",f"subdomain enum {B}"),("subfinder",f"subdomain enum {B}"),
   ("nuclei",f"vuln scanner {B}"),("whatweb",f"web fingerprint {B}"),
   ("theharvester",f"OSINT {B}"),("enum4linux-ng",f"SMB enum {B}"),("smbmap",f"SMB enum {B}"),
   ("evil-winrm",f"WinRM shell {B}"),("proxychains-ng","proxy chains"),("kismet","wireless IDS"),
   ("mdk4","wireless testing"),("sslscan","TLS scanner"),("testssl.sh","TLS scanner"),
   ("lynis","hardening audit"),("rkhunter","rootkit check"),("whois","whois client")]),
}
def arr(xs, ind):
    return ("\n"+" "*ind).join(xs)
here = os.path.dirname(os.path.abspath(__file__))
for k,(desc,deps,opt) in list(M.items())+[("full",("Laden OS full: every Laden edition",
        [f"laden-{x}" for x in M],[]))]:
    name=f"laden-{k}"
    d=os.path.join(here,"..",name); os.makedirs(d,exist_ok=True)
    s=f"""# Maintainer: Laden OS Repo <admin@laden.no>
# Generated by packages/metas/gen-metas.py: edit there and re-run.
pkgname={name}
pkgver={VER}
pkgrel={RELS.get(k, REL)}
pkgdesc='{desc}'
arch=('any')
url='https://laden.no'
license=('MIT')
groups=('laden-meta')
depends=({arr(["'%s'"%x for x in deps],9)})
"""
    if opt:
        s+=f"optdepends=({arr(["'%s: %s'"%(a,b) for a,b in opt],12)})\n"
    s+="\npackage() { :; }\n"
    open(os.path.join(d,"PKGBUILD"),"w").write(s)
    print(name, len(deps), "deps", len(opt), "optdeps")
