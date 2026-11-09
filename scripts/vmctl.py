#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Drive a scripts/vm-0.2.sh VM: screenshots, mouse, keyboard, serial shell.
  vmctl.py DIR shot NAME            -> DIR/NAME.png
  vmctl.py DIR click X Y [X Y ...]  (pixel coords of the current screen)
  vmctl.py DIR type TEXT
  vmctl.py DIR key KEY [KEY ...]    (QEMU qcodes, combos like ctrl-alt-f2)
  vmctl.py DIR sh 'CMD' [TIMEOUT]   (live ISO root shell on ttyS0)
  vmctl.py DIR wait REGEX TIMEOUT   (wait for text on the serial console)
  vmctl.py DIR hmp 'CMD'"""
import json, os, re, socket, subprocess, sys, time
D = sys.argv[1]; cmd = sys.argv[2]; args = sys.argv[3:]
def conn(name):
    for _ in range(50):
        try:
            s = socket.socket(socket.AF_UNIX); s.connect(os.path.join(D, name)); return s
        except OSError: time.sleep(0.2)
    sys.exit("no " + name)
_mon = None
def hmp(c):
    """HMP command on a persistent connection; waits for the next (qemu) prompt."""
    global _mon
    if _mon is None:
        _mon = conn("mon.sock"); _mon.settimeout(5); _read_prompt()
    _mon.sendall((c + "\n").encode()); return _read_prompt()
def _read_prompt():
    out = b""
    while not out.rstrip().endswith(b"(qemu)"):
        b = _mon.recv(65536)
        if not b: break
        out += b
    return out.decode(errors="replace")
def qmp(*cmds):
    s = conn("qmp.sock"); f = s.makefile("rw")
    f.readline(); f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush(); f.readline()
    res = []
    for c in cmds:
        f.write(json.dumps(c) + "\n"); f.flush()
        while True:
            r = json.loads(f.readline())
            if "return" in r or "error" in r: res.append(r); break
    s.close(); return res
def size():
    p = os.path.join(D, ".size.ppm"); hmp("screendump " + p); time.sleep(0.5)
    with open(p, "rb") as fh: hdr = fh.read(64).split()
    return int(hdr[1]), int(hdr[2])
if cmd == "shot":
    p = os.path.join(D, args[0]); hmp("screendump %s.ppm" % p); time.sleep(1)
    subprocess.run(["magick", p + ".ppm", p + ".png"], check=True); os.remove(p + ".ppm"); print(p + ".png")
elif cmd == "click":
    w, h = size()
    for i in range(0, len(args), 2):
        x, y = int(args[i]), int(args[i+1])
        ev = lambda t, a, v: {"type": "abs", "data": {"axis": a, "value": v}}
        for j in range(3):  # several moves: the first one only wakes the pointer up
            qmp({"execute": "input-send-event", "arguments": {"events": [
                {"type": "abs", "data": {"axis": "x", "value": x * 32767 // (w - 1) + j}},
                {"type": "abs", "data": {"axis": "y", "value": y * 32767 // (h - 1)}}]}})
            time.sleep(0.2)
        qmp({"execute": "input-send-event", "arguments": {"events": [{"type": "btn", "data": {"down": True, "button": "left"}}]}})
        time.sleep(0.1)
        qmp({"execute": "input-send-event", "arguments": {"events": [{"type": "btn", "data": {"down": False, "button": "left"}}]}})
        time.sleep(0.5)
elif cmd == "key":
    for k in args: hmp("sendkey " + k); time.sleep(0.3)
elif cmd == "type":
    m = {" ": "spc", "-": "minus", ".": "dot", "/": "slash", "_": "shift-minus", "@": "shift-2", "!": "shift-1",
         "=": "equal", ",": "comma", ":": "shift-semicolon", ";": "semicolon", "'": "apostrophe", '"': "shift-apostrophe",
         "|": "shift-backslash", ">": "shift-dot", "<": "shift-comma", "$": "shift-4", "*": "shift-8", "&": "shift-7",
         "(": "shift-9", ")": "shift-0", "\n": "ret", "+": "shift-equal", "~": "shift-grave_accent", "#": "shift-3"}
    for ch in " ".join(args):
        k = m.get(ch) or (("shift-" + ch.lower()) if ch.isupper() else ch)
        hmp("sendkey " + k); time.sleep(0.15)
elif cmd in ("sh", "wait"):
    s = conn("serial.sock"); s.settimeout(1); buf = ""
    if cmd == "sh":
        tag = "END%d" % int(time.time() * 1000)
        s.sendall(("export TERM=dumb PS1='# ' PROMPT_COMMAND=; " + args[0] + "; echo " + tag + "=$?\n").encode())
        pat, tmo = tag + r"=(\d+)", float(args[1]) if len(args) > 1 else 120
    else:
        pat, tmo = args[0], float(args[1])
    end = time.time() + tmo
    while time.time() < end:
        try: buf += s.recv(65536).decode(errors="replace")
        except socket.timeout: pass
        m = re.search(pat, buf)
        if m:
            if cmd == "sh":
                body = buf[:m.start()]
                body = re.sub(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)", "", body); body = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", body)
                lines = body.splitlines()
                print("\n".join(l for l in lines if tag not in l)); sys.exit(int(m.group(1)))
            print("matched"); sys.exit(0)
    print(buf[-3000:]); sys.exit("timeout")
elif cmd == "hmp":
    print(hmp(" ".join(args)))
