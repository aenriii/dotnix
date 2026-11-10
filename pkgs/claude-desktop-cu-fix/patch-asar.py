# TEMP (2026-11-09): test the claude-desktop-extra fork's background-display
# PATH fix (branch fix/cu-target-started-path) before it is released. The Nix
# package installs the prebuilt release tarball, so the fork's local js/ never
# reaches it; this swaps the executor text inside app.asar instead.
#
# usage: patch-asar.py <app.asar> <old.js> <new.js>
# Replaces the one verbatim copy of old.js (stripped) with new.js (stripped) in
# whichever file of the archive holds it, then rewrites the asar header: that
# file's size and integrity, and the offsets of every file stored after it.
# Fails if old.js is not found exactly once.
import hashlib, json, struct, sys

asar, old_p, new_p = sys.argv[1:4]
data = open(asar, "rb").read()
old = open(old_p, "rb").read().strip()
new = open(new_p, "rb").read().strip()

if data.count(old) != 1:
    sys.exit(f"patch-asar: old executor found {data.count(old)} times in {asar}, expected 1")

# Header: pickle(uint32 4) + pickle(uint32 hdr_pickle_size) + [uint32 payload_size, uint32 str_len, json, pad]
hdr_pickle_size = struct.unpack("<I", data[4:8])[0]
str_len = struct.unpack("<I", data[12:16])[0]
header = json.loads(data[16:16 + str_len])
base = 8 + hdr_pickle_size

def files(node):
    for name, v in node.get("files", {}).items():
        if "files" in v:
            yield from files(v)
        else:
            yield v

hit = data.find(old)
entries = [v for v in files(header) if "offset" in v]
target = next(v for v in entries if base + int(v["offset"]) <= hit < base + int(v["offset"]) + v["size"])
t_off, t_size = int(target["offset"]), target["size"]
body = data[base + t_off: base + t_off + t_size].replace(old, new)
delta = len(body) - t_size

target["size"] = len(body)
if "integrity" in target:
    bs = target["integrity"].get("blockSize", 4 * 1024 * 1024)
    target["integrity"]["hash"] = hashlib.sha256(body).hexdigest()
    target["integrity"]["blocks"] = [hashlib.sha256(body[i:i + bs]).hexdigest() for i in range(0, len(body), bs)]
for v in entries:
    if int(v["offset"]) > t_off:
        v["offset"] = str(int(v["offset"]) + delta)

js = json.dumps(header, separators=(",", ":")).encode()
pad = (4 - len(js) % 4) % 4
payload = struct.pack("<I", len(js)) + js + b"\0" * pad
pickle = struct.pack("<I", len(payload)) + payload
out = struct.pack("<I", 4) + struct.pack("<I", len(pickle)) + pickle
out += data[base:base + t_off] + body + data[base + t_off + t_size:]
open(asar, "wb").write(out)
print(f"patch-asar: replaced executor ({len(old)} -> {len(new)} bytes) in an entry of {t_size} bytes")
