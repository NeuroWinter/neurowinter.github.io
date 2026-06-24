---
layout: post
category: Security
title: "The wool DRM, part 2: the Rust wall I didn't crack"
heading: "The wool DRM, part 2: the Rust wall I didn't crack"
description: "The current wool DRM tier is Rust with its AES key held on a C2, never in the binary. I mapped the format down to the byte and never decrypted a line. That is the design working as intended."
---

## TLDR:

- Recap: `wyourname/wool` is the script-DRM repo a big slice of the Chinese
  reward-farming (薅羊毛) scene rents to seal their fraud scripts. The old
  Cython tier baked its key into the binary, so I cracked it. That was the
  previous post.
- The current tier is Rust (`loader_v2`, `common`, `component`) doing AES-CBC.
  The key is never in the binary: `common` fetches it per machine from a C2 and
  `loader_v2` decrypts with it.
- I did not crack one ev2 payload, and that is the design working as intended.
- Score: 49 ev2 scripts mapped, 0 decrypted. The crypto is ordinary, the wall
  is where the key lives.
- The C2 is `1.94.146.238:8099` (Huawei Cloud, Shanghai) with a `doudoudou.top`
  backup. It currently 404s and `control.json` carries `status: false`, but the
  binaries were still updated in June 2026, so someone is still running it.
- Everything I say about what the sealed scripts do is inference, not
  extraction. All read-only, nothing farmed, nothing logged into.

---

## Recap: the loader I cracked

A quick recap if you skipped
[the first post]({% post_url 2026-06-23-the-wool-drm %}). `wool` is a zero-star
GitHub repo that does one job, script DRM, and a large part of the Chinese
reward-farming scene rents it to seal their fraud scripts. The repo ships four
loaders. The
old one is a Cython module running a hand-ported JavaScript DES, and I reversed
it end to end, because the key was baked into the binary. Recover that key once
and every payload the loader ever sealed falls open.

This post is about the other three, the ones written in Rust. They are the tier
the operator built after deciding the baked-in key was the mistake, which it
was... The cipher is no harder. The key just stopped living on your machine.

---

## Track B: The Great Rust Wall (ev2)

I found Track B by accident. With the DES loader working, I started feeding it
every encrypted file in the repo thinking I had hit the jackpot, and most
decrypted fine. Then a whole folder, `encrypted_files_v2`, threw
`json.JSONDecodeError` on every single file. The DES loader was trying to parse
them as something they weren't and giving up the ghost. These were not DES
payloads. They were a different format altogether, for a different loader. That
is when it clicked: two generations of this thing, not one. Hence the different
.so files!

The newer generation is Rust. `loader_v2` (827 KB) and `component` (8.2 MB) are
both Rust compiled to native code, and where the Cython loader handed me
everything, these kept their secrets. So I'll say it up front: I did not get
through this tier. I can map it, fingerprint the format, and name most moving
parts. But I never decrypted a single ev2 payload. That is by design, and the
design is good, well its good against offline attacks.

How do I know it's Rust if it's stripped? Because Rust has a few tell tale
signs. It bakes the source path of every panic site into the binary, including
the full path of every crate it pulled from the build machine's cargo registry,
versions and all. The operator's function names are gone, but the dependency
tree is sitting in `strings`: `pyo3` (a Python extension written in Rust),
`tokio` (async), `flate2` (gzip), and in `loader_v2`, `zeroize` next to a
`src/utils/crypto.rs` doing block-cipher work. No more JavaScript DES :(. This
is the real thing.

The split across the binaries is the clever part. `loader_v2` exposes one
Python method, `_decrypt(eb)`, that takes an encrypted bundle and does the
whole job inside Rust: custom Base64, AES-CBC, gzip, marshal, run. Unlike Track
A's `get_key()`, nothing hands you the key. It never leaves Rust memory, and
`zeroize` wipes it after use. It's also machine-bound: `sysinfo` reads
`/proc/cpuinfo` and friends so a bundle is tied to the hardware it was
provisioned for. And the key does not live in the binary at all. It comes from
the operators C2 server.

That server is in `control.json`, in the root of the repo:

```json
{"message":"已更新","status":false,
 "url1":"Hw0bBUhBTlxLTk1BREZYT19WT0NXRUtXTg==",
 "url2":"Hw0bBUhBTgwVHlcLGgcKDhgBGAxBAR0eTg==","version":1.07}
```

The URLs are base64 over a fixed key XOR, and the key is `wyourname`, the
author's own username:

```python
>>> import base64
>>> def dexor(s, key=b"wyourname"):
...     raw = base64.b64decode(s)
...     return bytes(c ^ key[i % len(key)] for i, c in enumerate(raw))
...
>>> dexor("Hw0bBUhBTlxLTk1BREZYT19WT0NXRUtXTg==")
b'http://1.94.146.238:8099/'
>>> dexor("Hw0bBUhBTgwVHlcLGgcKDhgBGAxBAR0eTg==")
b'http://api.doudoudou.top/'
```

The primary on a Huawei Cloud box in Shanghai, and a backup on `doudoudou.top`.
The third Rust binary, `common` (3.2 MB), is the client that talks to it:
`reqwest` and `rustls` in its crate list, it fingerprints the machine, POSTs to
that C2 over HTTP, and gets back the per script key, which it feeds to
`loader_v2` to do the decrypt. So the work is split three ways: `common`
fetches the key, `loader_v2` uses it, and the operator's server is the only
place the key ever sits in the clear.

That is the whole design, and it is the part Track A got wrong. Track A baked
the key into the loader the key was in the same draw as the lock, so recovering
it once broke everything. Track B leaves the locked payloads public, on
GitHub's CDN where there is nothing to take down since the scripts are not
readable at all, and keeps the keys on a server it controls. You can clone
every ev2 file in the repo. Without the C2, they are noise. Though I do wonder
I could brute force them somehow... Spoiler: You can't. With standard AES-CBC
and zero key leaks in the binary, the keyspace is a computational brick wall.

### component.so: the heavy runtime

`loader_v2` is the light tier. `component.so` is the other one, and it is a
different animal: 8.2 MB, built on a statically-linked OpenSSL instead of
Rust's `rustls`, with its symbol table left in. Among its strings, XOR'd with
`wyourname` again, is a client-key path:

```
/etc/ssl/private/UAP_reload_ca.key
```

I have to be careful here, because this is where I start reading tea leaves. I
never watched `component` talk to anything, the C2 is dark, so the mutual-TLS
story is inferred from that one string, not seen on the wire. But it's a loud
string. A binary that statically links the whole OpenSSL stack and reaches for
a CA private key at a fixed path is almost certainly doing client-certificate
auth: a server that won't open the door unless you present a cert it issued.

Which raises a question I can't fully answer: how does that key get onto the
box? `component` reads the path, it doesn't write it, and it ships no
certificate of its own. So something else has to drop the key at install time,
which means these instances aren't generic, they're provisioned. Whatever sets
a subscriber up hands them a client cert tied to the operator's CA. I never
caught that step happening, so the mechanism is a gap, but the shape is clear
enough: this tier expects a tailored, pre-seeded box, not a fresh `pip
install`. I guess maybe this comes from Qinglong?

It doesn't stop there. `component` enumerates every single network interface
and reads the MAC addresses (`getifaddrs`), binding the license to physical
hardware, not just an OS install. And it can update and delete itself:

```
New version available! Please update.
No wyourname.so file found in the current path.
```

When the C2 signals a new version, the binary deletes itself and pulls the
replacement, so the operator can push fresh code to every install silently by
bumping a counter. The whole thing is hardened like commercial DRM, because
that is basically exactly what it is.

One fun detail is where the operator talking back. Among those same XOR'd
strings, decoded with the same `wyourname` key:

```
Whatareyoulookingat
```

Which is a fair question to leave for whoever is doing exactly what I was doing.

### What the sealed files give up anyway

I couldn't read the ev2 payloads, but I didn't leave them alone, and an
encrypted file is rarely as opaque as it looks. Strip off the outer
`func_mod::xor` layer (a reversible byte-to-printable transform, with no secret
in it) and the structure is right there. Every file opens with the same
12-character magic, `|(LTm_R7mUd@`, and the first 86 bytes are byte-for-byte
identical across all 192 files I pulled: that magic plus a first instruction
that is always the same gzip header. The plaintext is gzipped bytecode, and the
format barely bothers to hide that much.

The binary claimed AES. The format confirmed it, and told me something odder
besides: this isn't one big encrypted blob. It's a stream of small structured
records, one per bytecode instruction, each sitting between `>TZK>` delimiters
with its encrypted bytes in the middle. Run an autocorrelation over a file and
there's a clean spike at a 64-character period: 16 bytes, one AES-CBC block. So
each instruction is encrypted on its own, a block at a time. The operator
didn't encrypt a file, they built a custom per-instruction container and AES'd
the contents one record at a time.

```
+----------------+-----------------------+----------------+-----------------+
| >TZK>          | AES-CBC ciphertext    | >5@K>zNZuqYvC~ | opcode argument |
| frame delim    | 16 bytes (one block)  | inner delim    | 2 chars, clear  |
+----------------+-----------------------+----------------+-----------------+
```

One record, repeated once per instruction. The file opens with the 12-char
magic `|(LTm_R7mUd@` once. In the file each ciphertext byte is written as four
ASCII characters and the delimiters are literal, so that 16-byte block is 64
characters on disk; longer instructions chain more blocks.

And the records leak. Each encrypted instruction is trailed by a two-character
argument that isn't encrypted at all, and I'm sure of that from how it behaves
across builds. The repo ships every script compiled for four Python versions,
and bytecode changes between versions, so the encrypted bytes shift from the
3.9 file to the 3.11 one. The two char suffixes don't. A value that stays
identical across all four builds, at a fixed spot right after the delimiter,
can't be inside the ciphertext: it's the opcode's argument, outside the
encryption in the clear.

That is the ceiling. With the magic, the block structure, the plaintext
arguments, and file sizes lined up against scripts I'd already cracked on the
xxwppp side (the sister cluster of repos that runs on the same Track A loader,
so its payloads come out readable), I can sketch the skeleton of any ev2 file
in the repo. What I can't do is read a line of it. The key is the one thing the
format doesn't leak.


---

## The contrast: yphd, reversed before lunch

To see why the wool C2 model is actually strong, it helps to look at someone in
the same scene who did it the other way. `yphd` and `khr2606` are two binaries
from a neighbouring repo, and they look intimidating: 15 MB and 10 MB ELF
files, every string encrypted, no readable Python anywhere. But they are Nuitka
`--onefile` builds. Nuitka is a Python to C compiler, and `--onefile` bundles
the whole interpreter plus a zstd-compressed copy of the program into a single
executable. The "encryption" is just Nuitka packing its constant tables. It
isn't a security feature and it isn't gated on anything. Everything needed to
run is inside the file.

Which means it all comes back out. The Nuitka bootstrap unpacks itself to a
temp directory at startup; catch it there and you have the original Python.
`khr2606` turned out to be a solver for China Unicom's "Customer Day" Bubble
Battle, a hexagonal bubble shooter run as a loyalty promotion - pretty much a
clone of `Puzzle Bobble` with some rewards. The script runs a BFS over the grid
to find floating bubbles, picks the shot that clears the most, and, my
favourite touch, deliberately stops once it has eliminated more than 200 so it
doesn't look like a bot. The whole thing was readable in about two hours.

That is the point. `yphd` packs its code; wool gates its code. Packing always
loses under scruitany, because the unpacked version has to exist somewhere at
runtime for the program to do anything. A C2 held key never has to exist on the
victim's machine at all. It is the difference between a locked box you were
also handed the key to, and a locked box whose key stays on someone else's
server.

---

## Where it stops

So here is the honest dead end. There are 49 ev2 scripts in the repo, four
Python builds each, 196 files in all, and I have 192 of them, every build of
all but one script. I can describe the format down to the byte, I know the
cipher is AES-CBC, I know the key is universal and the same for every user.
What I do not have is that key, because it only comes from the C2, and the C2
will not talk to me. Every path I tried on `1.94.146.238:8099` returns 404, and
`control.json` carries `status: false`. Whether the server is off, moved, or
simply refusing anything without a valid machine fingerprint and the right
client certificate, I can't tell from the outside. The repo itself is alive,
its compiled binaries were updated as recently as June 2026. Someone is still
maintaining it. The doors are just locked.

Which means everything I can say about what those 49 scripts actually do is
inference, and I want to be clear about that. The names are romanized guesses
from the encoded filenames. The categories, KuWo Music, Ximalaya, Bilibili,
state-media reading apps, a pile of regional civic platforms, come from file
size, instruction counts, the plaintext argument bytes, and matching sealed
files against their cleartext twins on the xxwppp side. None of it was
extracted. I never saw the source of one ev2 script. If this series tells you
what `nebula-pr` does, it is a hypothesis with evidence behind it, not a
decryption.

That is the wall, and it's a good one. The reason I can tell the Track A story
all the way through and the Track B story only halfway comes down to a single
design decision: where the key lives.

---

## Resources

- [PyO3](https://pyo3.rs/), the Rust-to-Python bridge behind `loader_v2`,
  `common`, and `component`.
- [AES](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard) in CBC mode,
  the cipher behind the ev2 format, with the key held off the box on the C2.
- [Python's `marshal`](https://docs.python.org/3/library/marshal.html) and
  [`PyEval_EvalCode`](https://docs.python.org/3/c-api/veryhigh.html#c.PyEval_EvalCode),
  the last two steps of the ev2 pipeline once the AES layer comes off.
