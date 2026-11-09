#!/bin/bash
# SPDX-License-Identifier: MIT
# Boot a Laden OS ISO in QEMU. Never attaches a physical disk.
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "usage: $0 bios|uefi|both ISO" >&2
    exit 2
fi
MODE=$1
ISO=$(readlink -f "$2")
ROOT=$(cd "$(dirname "$0")/.." && pwd)
case "$ISO" in
    /dev/*) echo "refusing /dev path" >&2; exit 2 ;;
esac
if [[ -b $ISO || ! -f $ISO ]]; then
    echo "ISO must be a regular file: $ISO" >&2
    exit 2
fi

OUT=$ROOT/build/test-results
mkdir -p "$OUT"
CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
VARS_SRC=/usr/share/edk2/x64/OVMF_VARS.4m.fd

run_one() {
    local firmware=$1
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    local dir=$OUT/${firmware}-${stamp}
    mkdir -p "$dir"
    local serial=$dir/serial.log
    local monitor=$dir/monitor.sock
    local control=$dir/control.sock
    local shot=$dir/screen.ppm
    local vars=$dir/OVMF_VARS.4m.fd
    local vnc_port=77
    if [[ $firmware == uefi ]]; then
        vnc_port=78
    fi
    local -a fw=()
    if [[ $firmware == uefi ]]; then
        cp -a "$VARS_SRC" "$vars"
        fw=(
            -drive "if=pflash,format=raw,readonly=on,file=$CODE"
            -drive "if=pflash,format=raw,file=$vars"
        )
    fi
    qemu-system-x86_64 \
        -machine q35,accel=kvm \
        -cpu host \
        -m 6144 \
        -smp 4 \
        -cdrom "$ISO" \
        -boot order=d,menu=off \
        -nic none \
        -serial "file:$serial" \
        -vga virtio \
        -display "vnc=127.0.0.1:$vnc_port" \
        -monitor "unix:$monitor,server,nowait" \
        -device virtio-serial \
        -chardev "socket,id=ctrl,path=$control,server=on,wait=off" \
        -device "virtserialport,chardev=ctrl,name=laden.control" \
        -name "laden-os-$firmware" \
        "${fw[@]}" &
    local qemu_pid=$!
    echo "$qemu_pid" >"$dir/qemu.pid"

    set +e
    python3 -u - "$serial" "$control" "$monitor" "$shot" "$dir/result.txt" "$qemu_pid" <<'PY'
import os, pathlib, socket, sys, time
serial_path, control_path, monitor_path, shot_path, result_path, qemu_pid = sys.argv[1:]
qemu_pid = int(qemu_pid)

def blocks():
    text = pathlib.Path(serial_path).read_text(errors="replace") if pathlib.Path(serial_path).exists() else ""
    parts = [b for b in text.split("LADEN_STATUS") if b.strip()]
    parsed = []
    for part in parts:
        item = {}
        for line in part.splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                item[key.strip()] = value.strip()
        if item:
            parsed.append(item)
    return parsed

def qemu_alive():
    try:
        os.kill(qemu_pid, 0)
    except OSError:
        return False
    return True

def wait_for(predicate, seconds=600):
    end = time.time() + seconds
    while time.time() < end:
        if not qemu_alive():
            raise SystemExit("qemu exited before the expected status")
        found = predicate(blocks())
        if found:
            return found
        time.sleep(2)
    raise SystemExit("timed out waiting for boot status")

first = wait_for(lambda items: next((i for i in items if i.get("plasma") == "up"), None))
mon = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
mon.connect(monitor_path)
desktop_path = str(pathlib.Path(shot_path).with_name("desktop.ppm"))
idle_path = str(pathlib.Path(shot_path).with_name("idle.ppm"))
time.sleep(2)
mon.sendall(f"screendump {desktop_path}\n".encode())
time.sleep(1)
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
for _ in range(30):
    try:
        sock.connect(control_path)
        break
    except OSError:
        time.sleep(1)
else:
    raise SystemExit("control port did not accept a connection")
sock.sendall(b"create-proof\n")
proved = wait_for(lambda items: next((i for i in reversed(items) if i.get("proof") == "present"), None))
mon.sendall(f"screendump {shot_path}\n".encode())
time.sleep(1)
mon.sendall(b"system_reset\n")
second = wait_for(lambda items: next((i for i in reversed(items) if i.get("plasma") == "up" and i.get("fingerprint") not in {first.get("fingerprint"), proved.get("fingerprint")}), None))
# The reset boot is the last plasma=up block whose fingerprint differs.
fresh = second
idle = int(os.environ.get("LADEN_IDLE_SECONDS", "0"))
if idle > 0:
    time.sleep(idle)
    mon.sendall(f"screendump {idle_path}\n".encode())
    time.sleep(1)
mon.sendall(b"system_powerdown\n")
mon.close()
sock.close()
problems = []
if fresh.get("proof") != "absent":
    problems.append("proof survived reboot")
if not first.get("fingerprint") or first.get("fingerprint") == "missing":
    problems.append("missing first fingerprint")
if fresh.get("fingerprint") == first.get("fingerprint"):
    problems.append("fingerprint repeated")
if fresh.get("ssh") not in {"masked", "not-installed", "disabled"}:
    problems.append("ssh state " + str(fresh.get("ssh")))
listeners = fresh.get("listeners", "")
if ":22" in listeners.split(","):
    problems.append("ssh listener")
text = "first_fingerprint={first}\nproof_fingerprint={proved}\nreset_fingerprint={fresh}\nreset_proof={proof}\nreset_ssh={ssh}\nreset_listeners={listeners}\n".format(
    first=first.get("fingerprint"),
    proved=proved.get("fingerprint"),
    fresh=fresh.get("fingerprint"),
    proof=fresh.get("proof"),
    ssh=fresh.get("ssh"),
    listeners=listeners,
)
pathlib.Path(result_path).write_text(text, encoding="utf-8")
print(text)
if problems:
    print("FAIL " + "; ".join(problems))
    raise SystemExit(1)
print("PASS")
PY
    local py_status=$?
    set -e
    if kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" || true
        wait "$qemu_pid" || true
    fi
    if command -v convert >/dev/null; then
        for ppm in "$shot" "$dir/desktop.ppm" "$dir/idle.ppm"; do
            if [[ -f $ppm ]]; then
                convert "$ppm" "${ppm%.ppm}.png" || true
            fi
        done
    fi
    echo "firmware=$firmware status=$py_status dir=$dir" | tee "$dir/summary.txt"
    return "$py_status"
}

case "$MODE" in
    bios) run_one bios ;;
    uefi) run_one uefi ;;
    both) run_one bios && run_one uefi ;;
    *) echo "unknown mode $MODE" >&2; exit 2 ;;
esac
