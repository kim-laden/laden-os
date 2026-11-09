#!/bin/bash
# SPDX-License-Identifier: MIT
# Boot-test a Laden OS 0.2 ISO in QEMU/KVM on BIOS (SeaBIOS) or UEFI (OVMF).
# Headless: drives the live system through the serial root console, checks
# SDDM + Plasma for the live user, starts the installer, takes screenshots.
# Only the ISO (read-only cdrom) and a throwaway qcow2 are attached.
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: $0 bios|uefi ISO [outdir]" >&2; exit 2; }
FW=$1; ISO=$(readlink -f "$2"); OUTDIR=${3:-$(dirname "$ISO")/tests}
[[ -f $ISO && ! -b $ISO ]] || { echo "ISO must be a regular file" >&2; exit 2; }
dir=$OUTDIR/$FW-$(date +%Y%m%d-%H%M%S); mkdir -p "$dir"
fw=()
if [[ $FW == uefi ]]; then
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$dir/vars.fd"
  fw=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
      -drive if=pflash,format=raw,file="$dir/vars.fd")
fi
qemu-img create -q -f qcow2 "$dir/disk.qcow2" 40G
nice -n 10 qemu-system-x86_64 -machine q35,accel=kvm -cpu host -m 6144 -smp 4 \
  -cdrom "$ISO" -boot order=d,menu=off \
  -drive file="$dir/disk.qcow2",if=virtio,format=qcow2 \
  -nic user,model=virtio-net-pci -vga virtio -display none \
  -chardev socket,id=s0,path="$dir/serial.sock",server=on,wait=off,logfile="$dir/serial.log" -serial chardev:s0 \
  -monitor unix:"$dir/monitor.sock",server,nowait \
  -name "laden-test-$FW" "${fw[@]}" &
qpid=$!
set +e
python3 -u - "$dir" "$qpid" <<'PY'
import os, socket, sys, time, re
d, qpid = sys.argv[1], int(sys.argv[2])
def alive():
    try: os.kill(qpid, 0); return True
    except OSError: return False
def connect(path, tries=60):
    for _ in range(tries):
        try:
            s = socket.socket(socket.AF_UNIX); s.connect(path); return s
        except OSError: time.sleep(1)
    raise SystemExit("cannot connect " + path)
ser = connect(d + "/serial.sock"); ser.settimeout(1)
mon = connect(d + "/monitor.sock")
buf = ""
def read_until(pat, timeout):
    global buf
    end = time.time() + timeout
    while time.time() < end:
        if not alive(): raise SystemExit("qemu exited")
        try:
            chunk = ser.recv(65536).decode(errors="replace")
            buf += chunk
        except socket.timeout:
            pass
        m = re.search(pat, buf)
        if m:
            out = buf[:m.end()]; buf = buf[m.end():]; return out
    raise SystemExit("timeout waiting for %r" % pat)
def run(cmd, timeout=60):
    tag = "END%d" % int(time.time()*1000)
    ser.sendall((cmd + "; echo " + tag + "=$?\n").encode())
    out = read_until(tag + r"=(\d+)", timeout)
    return out
def shot(name):
    mon.sendall(("screendump %s/%s.ppm\n" % (d, name)).encode()); time.sleep(2)
t0 = time.time()
read_until(r"root@laden-live", 420)
time.sleep(2); ser.sendall(b"export TERM=dumb PROMPT_COMMAND= ; unset WEZTERM_SHELL_SKIP_ALL; PS1='# '\n")
print("serial root shell after %ds" % (time.time()-t0))
time.sleep(3); ser.sendall(b"\n"); time.sleep(1)
res = {}
# wait for SDDM + Plasma (live user autologin)
for i in range(90):
    o = run("systemctl is-active sddm; pgrep -u live -x plasmashell >/dev/null && echo PLASMA_UP || echo PLASMA_DOWN")
    if "PLASMA_UP" in o: break
    time.sleep(4)
res["sddm_plasma"] = "PLASMA_UP" in o
time.sleep(15); shot("desktop")
# open the application launcher (Meta) for a menu screenshot, then close it
mon.sendall(b"sendkey meta_l\n"); time.sleep(4); shot("menu")
mon.sendall(b"sendkey esc\n"); time.sleep(2)
o = run("export TERM=dumb; cat /etc/os-release | head -3; uname -r; systemctl is-system-running; systemctl --failed --no-legend | head; loginctl list-sessions --no-legend; journalctl -b -u sddm --no-pager | tail -n 15")
print(o)
uid = "$(id -u live)"
run("runuser -u live -- env XDG_RUNTIME_DIR=/run/user/" + uid + " WAYLAND_DISPLAY=$(basename $(ls /run/user/$(id -u live)/wayland-[0-9] | head -1)) QT_QPA_PLATFORM=wayland setsid /usr/bin/laden-installer >/dev/null 2>&1 < /dev/null & true")
up = False
for i in range(30):
    o = run("pgrep -x calamares >/dev/null && echo CAL_UP || echo CAL_DOWN")
    if "CAL_UP" in o: up = True; break
    time.sleep(2)
time.sleep(20)
o = run("pgrep -x calamares >/dev/null && echo CAL_STILL_UP || echo CAL_GONE; tail -n 5 /tmp/laden-installer.log; ls /root/.cache/calamares/ 2>/dev/null; grep -c 'Calamares will now quit\\|ERROR' /root/.cache/calamares/session.log 2>/dev/null")
print(o)
res["calamares"] = up and "CAL_STILL_UP" in o
shot("calamares")
o = run("ls -la /tmp/laden-installer.log; tail -n 30 /tmp/laden-installer.log; journalctl -b --no-pager | grep -iE 'calamares|sudo' | tail -n 15; grep -iE 'branding|Bad|missing|error|fail' /root/.cache/calamares/session.log 2>/dev/null | head -40", 30); print(o)
if not res["calamares"]:
    o = run("XDG_RUNTIME_DIR=/run/user/" + uid + " WAYLAND_DISPLAY=$(basename $(ls /run/user/$(id -u live)/wayland-[0-9] | head -1)) QT_QPA_PLATFORM=wayland timeout 25 calamares -d > /tmp/cal-root.log 2>&1; echo rc=$?; grep -iE 'error|fail|bad|missing|cannot|could not|warning' /tmp/cal-root.log | head -40; tail -n 15 /tmp/cal-root.log", 60); print(o)
open(d + "/result.txt", "w").write("\n".join("%s=%s" % kv for kv in res.items()) + "\n")
print(res)
mon.sendall(b"quit\n")
sys.exit(0 if all(res.values()) else 1)
PY
st=$?
set -e
kill $qpid 2>/dev/null || true; wait $qpid 2>/dev/null || true
for p in "$dir"/*.ppm; do [[ -f $p ]] && magick "$p" "${p%.ppm}.png" && rm -f "$p"; done
rm -f "$dir/disk.qcow2" "$dir/vars.fd"
echo "fw=$FW status=$st dir=$dir"
exit $st
