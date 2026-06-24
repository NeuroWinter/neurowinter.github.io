---
layout: post
category: Security
title: "The wool DRM, part 1: the Cython loader I cracked"
heading: "The wool DRM, part 1: the Cython loader I cracked"
description: "How a Chinese reward-farming scene seals its fraud scripts, and the old Cython DES loader I reversed end to end. The key was baked into the binary, so it protected nothing."
---

## TLDR:

- `wyourname/wool` is a zero-star GitHub repo that does one job: script DRM. A
  big slice of the Chinese reward-farming (薅羊毛) scene rents it to seal their
  fraud scripts so they can't be lifted straight off GitHub.
- Why bother locking a checkin script? In this scene the script is the product.
  It gets sold, rented, and gated behind license keys, so the code itself is
  the thing a buyer is paying not to be able to copy.
- The old tier is a Cython module (`loader_39_x86_64.so`) running a hand-ported
  JavaScript DES. I reversed it end to end.
- The key is hardcoded (`f30db728...`), the same eight bytes in every build.
  Recover it once and every payload that loader ever sealed falls open, so it
  protects nothing.
- I'm publishing the method and the lesson, not a decrypt script. All
  read-only, nothing farmed, nothing logged into.
- The newer tier of DRM fixed the mistake that made this one crackable: it
  moved the key off the box and onto a C2. That is the next post.

---

## Why I started pulling on these .so files

At the end of the last post I had a repo I couldn't read. Here's the part I
skipped over: qlk's own obfuscation was never the hard problem.

Every script is the same trick, base85 or XOR or a subtract cipher, then zlib,
then a marshalled code object handed straight to `exec()`. It runs in memory and
never writes a .pyc, so it stops you reading the source but not running it, and
anything you can run you can hook. After decoding these scripts I realised what
I had stumbled upon, a treasure trove of scripts that are used to defraud news
sites, ads, and local government websites, all
to make a little bit of cash. We will go into this in more detail in another
post.

Curious to see if this was just a single example of bad opsec, I started
searching the endpoints they were targeting. Boy they were everywhere: a KuWo
cash-withdrawal endpoint alone is in at least five other people's repos. And it
wasn't just the targets that matched: two of qlk's obfuscators are hand-rolled,
not off-the-shelf, and the same fingerprints turned up in another author's repo
in the same cluster. Same private toolchain, different authors. qlk wasn't a
one-off, it was one corner of a whole scene.

So I started reading through these repos. Most were more of the same: same
apps, same obfuscation, the odd file copied word for word from one account to
the next. Typical for a scene like this that people would be stealing others
scripts. But a few were built differently. They didn't contain any logic at
all. They imported a loader, pulled down a .so, and handed it an encrypted
string to run. And one of them, a plaintext one, had left the download URL
sitting right at the top of the file:

```python
DEBIAN_URL = 'https://raw.githubusercontent.com/wyourname/wool/master/others'
```

That was the repo. [wyourname/wool](https://github.com/wyourname/wool): zero stars, description 自用 ("personal
use"), quietly hosting the loaders a large portion of the scene was using
to protect their scripts.

---

## Why lock a wool script?

Before any of the reverse engineering, it is worth settling what the lock is
even for. A wool script automates a checkin, a lottery draw, a daily reading
task. It is not state secrets. So who is it hiding from, and why would anyone
pay to keep it sealed?

Because in this scene the script is the product. These things get sold and
rented. There are panels that meter access, license keys (卡密) that gate a
single run, resellers who never wrote a line of the code they sell or rent. The
moment the source is readable, a buyer copies it once and stops paying, or
undercuts the author by selling it on himself. Confidentiality is the whole
business model.

The checkin loop was never the part worth protecting. Anyone can write one. The
value is in the bypass underneath: the `h5st` signature JD's app demands, the
risk tokens, the shared pool of device IDs, the CAPTCHA solver, the Ruishu
fingerprint defeat. That is months of work against a target that keeps moving,
and it is exactly what a rival in the same scene wants to lift. Lock the file
and the exploit stays yours.

A loader that fetches its key from a server buys one more thing: an off switch.
Stop handing out the key, or flip a flag in a config, and every copy already
deployed goes dark at once. The author keeps a hand on a product he has already
sold.

There is a defensive (for the fraudsters) bonus too. An encrypted payload
sitting on GitHub is just a bunch of bits. JD cannot read it to build a
detection, a researcher cannot skim it for indicators, and there is nothing
legible to file a takedown against. The fraud code hides in plain sight, on a
CDN that will never take it down, since it doesnt even know its a fraud script.

And the whole scene runs on no trust. The operators do not even trust the
customers they sell to, and I guess they shouldn't. A later post is about one
author who quietly routes his buyers' harvested passwords back to his own
server. DRM is that same instinct pointed at the paying customer: hand them the
capability, never the code.

So that is the motive. The rest of this post is how well they actually pulled
it off, starting with the version that got it wrong.


---

## Wool repo overview

Now this wool repo is hella interesting, it's the basis of a bunch of different
script DRM techniques.

The repo has two branches, master and compatible, the latter untouched for
three years. Everything interesting is on master.

The first two things that stood out to me. First, a folder called
`encrypted_files_v2`, updated three weeks ago, full of .txt files that all open
with the same 12-character magic (`|(LTm_R7mUd@`) and then gibberish. Second, a
script/ directory containing common.py. A loader that subscribers actually run.
That file is readable, and it tells you the shape of the whole system: you hand
it a script name, it then figures out your Python version and arch, fetches the
right .so binary from the repo's others/ directory, loads it as a Python
extension module, and calls main(). From that point common.py is out of the
picture. Whatever happens next happens inside the binary.

I expected one loader. There are four of them in others/ and they don't all
work the same way: `loader` is an old Cython module, and `loader_v2`, `common`,
and `component` are Rust. The one `common.py` pulls by default is `common`.
It's all one product, carried from Python into Rust and grown since, which is
the tell that this system has a history.

This post is about the old one, the Cython loader, because it is the one that
opens up and tells me all its secrets. The other three are written in Rust, and
they are a harder story that gets its own post.



---

## Track A: Cython DES loader

The oldest loader, `loader_39_x86_64.so`, is a Cython compiled Python module,
so there's no source to read. You get a 369 KB shared object that exports
exactly one symbol, `PyInit_loader`, and keeps everything else to itself.
Import it, hand it an encrypted string, and it hands you back live code. That's
the entire product: the scripts ship as gibberish, the loader turns gibberish
into behaviour, and the step in between is the thing you're paying not to have
to trust.

So I would naturally start reaching for Ghidra, or radare2 here (or binary
ninja if I had more $$), but for this I didnt need to! Using `file` it
confirmed that it was an ELF 64-bit shared object (the exported `PyInit_loader`
symbol is what actually marks it a CPython extension module), I also used
`strings` to get out all the printable strings, and used `readelf` to give a
way the sections.

What gave it away was the DES. Not that it uses DES, plenty of things still do,
but that it isn't a crypto library's DES. It's someone's JavaScript DES,
hand-carried into Python. The fingerprints are everywhere: helper functions
named `to_signed32` and `unsigned_right_shift`, which only need to exist
because JavaScript's `>>>` behaves differently from Python's. And the key
schedule routine's docstring is written in Chinese but leaves the words
`JavaScript` and `key schedule` sitting right there in English; translated, it
says the schedule was restored from the JavaScript version. You don't write a
DES engine in Python for fun. You port one you found.

With the algorithm identified, the rest of the pipeline falls out of the
strings and the exports. The loader carries its own scrambled Base64 alphabet,
the standard one shuffled just enough that an off-the-shelf decoder gives you
garbage:

```
abcdefghijklmnoqprstuvwxyzABCDEFGHJIKLMNOPQRSTUVWXYZ0123456789~/
```

It's ordinary Base64 with the case blocks flipped so lowercase comes first, `p`
and `q` swapped, `I` and `J` swapped, and `~` standing in for `+`. Small
changes, enough to break a lazy decode. From there the chain is mechanical, and
every stage is one of the module's exported names:

```
CustomBase64.decode → split_data (peel IV) → DES-CBC → strip PKCS7
  → gzip decompress → marshal.loads → PyEval_EvalCode
```

`split_data` lifts the IV off the front, `des_crypt` runs the DES-CBC with that
JavaScript-ported schedule, the result un-gzips into marshalled bytecode, and
`PyEval_EvalCode` runs it in memory. The whole thing is right there. The only
piece the pipeline is missing is the key.

### The MD5 red herring

The strings get you this far, and then they set a trap, or I just made my own
trap.

Pull the symbols and `get_key()` is openly calling
`hashlib.md5(...).hexdigest()`. A few bytes away in the read only (RO section)
data sit two eight-character strings, `12345678` and `12345673`, and eight
characters is exactly the length of a single DES key. This is too good to be
true, and this follows the idea that the creator is just doing their best. The
story writes itself the key is `MD5("12345678")`, probably sliced to size. It's
a clean, satisfying answer, I believed this, and thought "Ah silly wool creator
you have left the key right here."

I was wrong. `MD5("12345678")` is `25d55ad283aa400af464c76d713c07ad`, which is
not the key.

The only way to figure this out was to stop reading and start running, testing
my own notes, and theories. The part the static tools can't do for you, and the
part a Cython .so makes trivial. It's a Python module, so I gave it a Python
interpreter: a matching CPython (3.9, the version it was built against), the
loader dropped beside it, imported. Then I just asked.

```python
  >>> import loader
  >>> loader.get_key()
  'f30db728b353376862dcddc6c618a12b'
```

There's the real DES key, truncated to its first eight bytes (`f30db728`) for
the single DES schedule. How `get_key()` actually arrives at it I have no idea.
But that's the entire point: I never needed to know. The loader runs the algo
itself on every call and hands back the answer, and because the whole point of
this loader is to get that key, I just needed to run it!

And the key is hardcoded. The same eight bytes in every build, not created per
user, not fetched from a server, just a constant the loader reads out of
itself.

### The embedded self-test

There is one more thing baked into the loader: a 536-character blob of that
same scrambled Base64, sitting in the read-only data at offset `0x4a4c0`. Run
it back through the pipeline above and it decrypts cleanly into a real code
object. It's a self-test, a sample the loader can unpack against itself to
prove the machinery still works, and it tells me something too. The decrypt
touched no network. For this tier the loader is the whole story: key,
algorithm, and a sample to run them on, all sealed in one file. Track B is
where the operator decides that was the mistake.


---

## Decryption

A note on what I am and am not publishing, because it matters here. The Track A
recipe is complete: the key is hardcoded, it's the same eight bytes for every
xxwppp payload (a sister cluster of repos on the same loader), and the
pipeline is seven well-known steps. Anyone who read this post could rebuild a
script that decrypts every one of those fraud payloads. That is the whole
problem with a hardcoded key. It buys no confidentiality at all, not against me
and not against the next person.

So I'm publishing the method and the lesson, not the loaded gun. You've seen
the algorithm, the alphabet, the pipeline, and the fact that the key is
`f30db728...`. What I'm holding back is the copy-paste, turn-key script that
takes a repo file in and prints runnable fraud code out. The method is the
interesting part and the part defenders need; the turn-key tool only helps the
next operator. Track B needs no such restraint, there's nothing to hold back,
because without the C2 key there is nothing to decrypt.

That tier is [the next post]({% post_url 2026-06-23-the-great-rust-wall %}),
the one where the operator finally put the key somewhere I couldn't reach
(like a high shelf).

---

## Resources

- [Cython](https://cython.org/), for how a compiled `.so` can still be a Python
  module you import and call, as long as you match the interpreter version.
- [DES](https://en.wikipedia.org/wiki/Data_Encryption_Standard), the cipher the
  loader runs, hand-ported out of a JavaScript implementation rather than taken
  from a crypto library.
- [Python's `marshal`](https://docs.python.org/3/library/marshal.html) and
  [`PyEval_EvalCode`](https://docs.python.org/3/c-api/veryhigh.html#c.PyEval_EvalCode),
  the last two steps of the Track A pipeline.
