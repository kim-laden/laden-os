#!/bin/bash
# SPDX-License-Identifier: MIT
# Boot the installed disk image in QEMU with no ISO attached.
# The image must already exist under build/install-vm/.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=$ROOT/build/install-vm
IMAGE=$DEST/laden-os-install.raw
READY=$DEST/READY
PASSWORD=$DEST/password
CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
VARS_SRC=/usr/share/edk2/x64/OVMF_VARS.4m.fd

refuse() {
    local path=$1
    case "$path" in
        /dev/*|*/dev/*)
            echo "refusing a host device path: $path" >&2
            exit 2
            ;;
    esac
    if [[ -b $path || -c $path ]]; then
        echo "refusing a block or character device: $path" >&2
        exit 2
    fi
}

refuse "$IMAGE"
if [[ ! -s $IMAGE || ! -f $READY || ! -f $PASSWORD ]]; then
    echo "No finished install image. Run scripts/install-disk.sh first." >&2
    exit 2
fi
if [[ ! -f $CODE || ! -f $VARS_SRC ]]; then
    echo "OVMF firmware is missing." >&2
    exit 2
fi

stamp=$(date +%Y%m%d-%H%M%S)
out=$DEST/boot-$stamp
mkdir -p "$out"
serial=$out/serial.sock
monitor=$out/monitor.sock
vars=$out/OVMF_VARS.4m.fd
cp -a "$VARS_SRC" "$vars"
qemu_log=$out/qemu.log

qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -m 6144 \
    -smp 4 \
    -drive "file=$IMAGE,format=raw,if=virtio,index=0,media=disk" \
    -boot order=c,menu=off \
    -nic none \
    -serial "unix:$serial,server=on,wait=off" \
    -vga virtio \
    -display "vnc=127.0.0.1:79" \
    -monitor "unix:$monitor,server=on,nowait" \
    -drive "if=pflash,format=raw,readonly=on,file=$CODE" \
    -drive "if=pflash,format=raw,file=$vars" \
    -name laden-os-installed \
    -no-reboot \
    >"$qemu_log" 2>&1 &
qemu_pid=$!
echo "$qemu_pid" >"$out/qemu.pid"

cleanup() {
    if kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

set +e
python3 -u - "$serial" "$monitor" "$PASSWORD" "$READY" "$out" "$qemu_pid" <<'PY'
import pathlib, re, socket, sys, time
serial_path, monitor_path, password_path, ready_path, out_dir, qemu_pid = sys.argv[1:]
qemu_pid = int(qemu_pid)
out = pathlib.Path(out_dir)
password = pathlib.Path(password_path).read_text(encoding="utf-8").strip()
expected = {}
for line in pathlib.Path(ready_path).read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        expected[key.strip()] = value.strip()
log_path = out / "serial.log"
log_path.write_text("", encoding="utf-8")
ansi = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

def alive():
    try:
        os_kill = __import__("os").kill
        os_kill(qemu_pid, 0)
    except OSError:
        return False
    return True

def connect(path, tries=60):
    last = None
    for _ in range(tries):
        if not alive():
            raise SystemExit("qemu exited")
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(path)
            sock.settimeout(1)
            return sock
        except OSError as exc:
            last = exc
            time.sleep(1)
    raise SystemExit(f"could not connect to {path}: {last}")

serial = connect(serial_path)
monitor = connect(monitor_path)
buffer = ""

def pull(seconds):
    global buffer
    end = time.time() + seconds
    while time.time() < end:
        if not alive():
            raise SystemExit("qemu exited")
        try:
            chunk = serial.recv(65536)
        except socket.timeout:
            chunk = b""
        if chunk:
            text = chunk.decode("utf-8", "replace")
            buffer += text
            with log_path.open("a", encoding="utf-8") as handle:
                handle.write(text)
        else:
            time.sleep(0.2)

def visible():
    return ansi.sub("", buffer)

def wait_for(token, seconds):
    end = time.time() + seconds
    while time.time() < end:
        if token in visible():
            return
        pull(1)
    raise SystemExit(f"timed out waiting for {token!r}")

def send(text):
    serial.sendall(text.encode("utf-8"))

def screendump(name):
    path = out / name
    monitor.sendall(f"screendump {path}\n".encode())
    time.sleep(1.5)

def sendkey_text(text):
    for char in text:
        if char.isascii() and (char.islower() or char.isdigit()):
            key = char
        elif char == "-":
            key = "minus"
        else:
            raise SystemExit("password has a character the greeter helper cannot type")
        monitor.sendall(f"sendkey {key}\n".encode())
        time.sleep(0.08)
    monitor.sendall(b"sendkey ret\n")

print("waiting for the serial login prompt", flush=True)
wait_for("login:", 420)
user = expected.get("user", "laden")
send(user + "\n")
wait_for("Password:", 60)
send(password + "\n")
# The motd contains the slogan before fish will read a command.
wait_for(user + "@", 120)
send("exec bash --noprofile --norc\n")
wait_for("bash-", 40)
pull(1)
proof = r'''
set +e
echo PROOF_BEGIN
echo USER=$(id -un)
echo UID_NUM=$(id -u)
echo MACHINE_ID=$(tr -d "[:space:]" </etc/machine-id)
if [[ -r /var/lib/laden-os/service-identity.fingerprint ]]; then echo FINGERPRINT_USER=readable; else echo FINGERPRINT_USER=denied; fi
echo ID_DIR=$(stat -c %a /var/lib/laden-os 2>/dev/null || echo unreadable)
echo SHORTCUT=$(awk 'f { print; exit } $0 ~ /lcp[.]desktop/ { f = 1 }' /home/laden/.config/kglobalshortcutsrc | tr -d "[:space:]")
if [[ -f /etc/plasmalogin.conf ]]; then echo AUTOLOGIN=present; else echo AUTOLOGIN=absent; fi
if [[ -f /etc/sudoers.d/10-laden-live ]]; then echo LIVE_SUDO=present; else echo LIVE_SUDO=absent; fi
if [[ -f /etc/polkit-1/rules.d/49-laden-live.rules ]]; then echo LIVE_POLKIT=present; else echo LIVE_POLKIT=absent; fi
if id live >/dev/null 2>&1; then echo LIVE_USER=present; else echo LIVE_USER=absent; fi
if [[ -f /etc/sudoers.d/10-laden-dev || -f /etc/ssh/sshd_config.d/99-laden-dev.conf ]]; then echo DEV_ACCESS=present; else echo DEV_ACCESS=absent; fi
echo SSHD=$(readlink /etc/systemd/system/sshd.service)
echo SSH_KEYS=$(find /etc/ssh -name 'ssh_host_*' 2>/dev/null | wc -l)
echo WALL_HASH=$(sha256sum /usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png | awk '{print $1}')
echo WALL_CFG=$(grep -o 'laden-os-lets-do-it[-v0-9]*7680x4320.png' /home/laden/.config/plasma-org.kde.plasma.desktop-appletsrc | head -n 1)
echo CAPTURE=$(awk -F= '$1=="intel_capture"{print $2}' /etc/laden-os/product.conf)
echo ROOT_FS=$(findmnt -n -o FSTYPE /)
echo ROOT_OPTS=$(findmnt -n -o OPTIONS /)
if [[ -d /sys/firmware/efi ]]; then echo EFI=yes; else echo EFI=no; fi
echo FSTAB_BEGIN
cat /etc/fstab
echo FSTAB_END
if sudo -n true; then echo SUDO_N=pass; else echo SUDO_N=fail; fi
if grep -q NOPASSWD /etc/sudoers.d/10-installer /etc/sudoers.d/* 2>/dev/null; then echo NOPASSWD=yes; else echo NOPASSWD=no; fi
echo COCKPIT_VERSION=$(tr -d "[:space:]" </usr/share/the-cockpit/VERSION)
echo LCP=$(command -v lcp)
conn=/home/laden/.config/the-cockpit/connections.lua
if [[ -f $conn ]] && grep -E '^[[:space:]]*\{' "$conn" | grep -q .; then echo CONNECTIONS=active; elif [[ -f $conn ]]; then echo CONNECTIONS=empty; else echo CONNECTIONS=missing; fi
if lsinitcpio /boot/initramfs-linux.img | grep -q archiso; then echo ARCHISO=present; else echo ARCHISO=absent; fi
echo SWAP=$(awk 'NR>1{print $1}' /proc/swaps | tr '\n' ' ')
echo HOSTNAME=$(tr -d "[:space:]" </etc/hostname)
echo PROOF_DONE
'''
send("cat >/tmp/laden-proof.sh <<'ENDPROOF'\n" + proof + "ENDPROOF\n")
send("bash /tmp/laden-proof.sh\n")
wait_for("PROOF_DONE", 180)
send("stty -echo\n")
time.sleep(0.4)
pull(0.5)
send(
    "printf '%s\\n' '"
    + password
    + "' | sudo -S -p '' sh -c '"
    + "if openssl pkey -in /var/lib/laden-os/service-identity.key -noout; then echo KEY_ROOT=yes; else echo KEY_ROOT=no; fi; "
    + "echo FINGERPRINT_ROOT=$(tr -d \"[:space:]\" </var/lib/laden-os/service-identity.fingerprint); "
    + "echo KEY_MODE=$(stat -c %a /var/lib/laden-os/service-identity.key); "
    + "echo FP_MODE=$(stat -c %a /var/lib/laden-os/service-identity.fingerprint)'\n"
)
send("stty echo\n")
wait_for("FINGERPRINT_ROOT=", 40)
screendump("after-serial.ppm")
# The greeter is up by the time the serial proof finishes. Capture it
# before any key is sent to the graphical console.
time.sleep(5)
screendump("greeter.ppm")
print("typing the password into the greeter", flush=True)
sendkey_text(password)
time.sleep(35)
screendump("desktop-early.ppm")
time.sleep(55)
screendump("desktop.ppm")
monitor.sendall(b"sendkey alt-t 200\n")
time.sleep(20)
screendump("cockpit.ppm")
send("if pgrep -f 'wezterm-gui|the-cockpit' >/dev/null; then echo COCKPIT_PROC=up; else echo COCKPIT_PROC=down; fi\n")
wait_for("COCKPIT_PROC=", 20)
if "COCKPIT_PROC=down" in visible():
    send(
        "pid=$(pgrep -u laden -x plasmashell | head -n 1); "
        "eval \"$(tr '\\0' '\\n' < /proc/$pid/environ | grep -E '^(WAYLAND_DISPLAY|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | sed 's/^/export /')\"; "
        "/usr/bin/lcp >/tmp/lcp-out 2>&1 & echo LAUNCHED=yes\n"
    )
    time.sleep(18)
    screendump("cockpit-manual.ppm")
    send("if pgrep -f 'wezterm-gui|the-cockpit' >/dev/null; then echo COCKPIT_MANUAL=up; else echo COCKPIT_MANUAL=down; fi\n")
else:
    send("echo COCKPIT_MANUAL=skipped\n")
send("if pgrep -x plasmashell >/dev/null; then echo PLASMA_AFTER=up; else echo PLASMA_AFTER=down; fi\n")
send("if [[ -f /home/laden/.config/laden-os/wallpaper-initialized ]]; then echo WALL_MARKER=yes; else echo WALL_MARKER=no; fi\n")
send("echo GUI_DONE\n")
wait_for("GUI_DONE", 30)
monitor.sendall(b"system_powerdown\n")
time.sleep(8)

text = log_path.read_text(encoding="utf-8", errors="replace")
if password and password in text:
    text = text.replace(password, "<redacted>")
    log_path.write_text(text, encoding="utf-8")
text = re.sub(r"\x1b\][^\x1b]*(?:\x1b\\|\x07)", "", text)
text = ansi.sub("", text)
start = text.rfind("PROOF_BEGIN")
end = text.rfind("PROOF_DONE")
block = text[start:end] if start >= 0 and end > start else ""
facts = {}
for line in block.splitlines():
    if "=" in line and line.split("=", 1)[0].isidentifier():
        key, value = line.split("=", 1)
        facts[key] = value.strip()
gui = text[text.rfind("PROOF_DONE"):]
for line in gui.splitlines():
    if line.startswith(("PLASMA_AFTER=", "WALL_MARKER=", "KEY_ROOT=", "FINGERPRINT_ROOT=", "KEY_MODE=", "FP_MODE=", "COCKPIT_PROC=", "COCKPIT_MANUAL=", "LAUNCHED=")):
        key, value = line.split("=", 1)
        facts[key] = value.strip()

problems = []
def need(key, value):
    if facts.get(key) != value:
        problems.append(f"{key}={facts.get(key)!r} expected {value}")

need("USER", expected.get("user", "laden"))
need("MACHINE_ID", expected.get("machine_id", ""))
need("FINGERPRINT_USER", "denied")
need("KEY_ROOT", "yes")
need("FINGERPRINT_ROOT", expected.get("fingerprint", ""))
need("KEY_MODE", "600")
need("AUTOLOGIN", "absent")
need("LIVE_SUDO", "absent")
need("LIVE_POLKIT", "absent")
need("LIVE_USER", "absent")
need("DEV_ACCESS", "absent")
need("SSHD", "/dev/null")
need("SSH_KEYS", "0")
need("WALL_HASH", "b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f")
need("WALL_CFG", "laden-os-lets-do-it-v2-7680x4320.png")
need("CAPTURE", "off")
need("ROOT_FS", "ext4")
need("EFI", "yes")
need("SUDO_N", "fail")
need("NOPASSWD", "no")
need("COCKPIT_VERSION", "1.1.0")
need("LCP", "/usr/bin/lcp")
need("CONNECTIONS", "empty")
need("ARCHISO", "absent")
need("HOSTNAME", "laden")
if "rw" not in facts.get("ROOT_OPTS", ""):
    problems.append("root is not mounted rw")
if not facts.get("SWAP"):
    problems.append("swap is not active")
if "UUID=" not in block:
    problems.append("fstab has no UUID")
(out / "facts.txt").write_text("".join(f"{k}={v}\n" for k, v in sorted(facts.items())), encoding="utf-8")
if problems:
    print("FAIL")
    print("\n".join(problems))
    raise SystemExit(1)
print("PASS")
print((out / "facts.txt").read_text(encoding="utf-8"))
PY
status=$?
set -e
if command -v convert >/dev/null; then
    for ppm in "$out"/*.ppm; do
        [[ -f $ppm ]] || continue
        convert "$ppm" "${ppm%.ppm}.png" || true
    done
fi
echo "status=$status dir=$out" | tee "$out/summary.txt"
exit "$status"
