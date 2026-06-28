---
layout: post
category: Security
title: "A weekend in the wool: mapping a Chinese reward-farming underground from one GitHub repo"
heading: "A weekend in the wool: mapping a Chinese reward-farming underground from one GitHub repo"
description: "A weekend that started with a grep.app search for leaked password prefixes and ended in a 16-actor Chinese reward-farming (薅羊毛) ecosystem: its script DRM, its C2, its credential theft, and the civic apps it targets."
---

## TLDR:

- A friend's grep.app link and a hunt for leaked password prefixes turned one 292-star GitHub repo (`985Ming/qlk`) into a map of a Chinese reward-farming (薅羊毛) underground: 16 actors, 26 repos, 60+ targeted platforms.
- Reward farming here means running scripts on a schedule, via Qinglong (a cron-job webui), to drain loyalty points, coupons, and lottery payouts from apps, then cashing out on Xianyu or Pinduoduo.
- It runs like a supply chain: operators write the scripts, one operator (wyourname) rents out script DRM to protect them, shared plumbing (NiuPanel, obfuscators, OCR, device-ID pools) hides the bots, and a WXPusher ping tells the operator when money lands.
- The targets are broad: music, video, novels, telecom, and banks, plus civic and government apps and state media.
- The ugly part: in at least one case the tooling robs its own users. smallfawn sells a JD.com login tool wired to exfiltrate the buyer's logins, plaintext passwords included, to a server they control.
- Where it stops: the modern scripts are sealed behind wyourname's C2, which is dark (404s, `status: false`). I mapped 49 of them and decrypted none. Everything I cracked is the older, weaker tier.
- All read-only. I didn't farm an account or log into anything, and anything live went to the vendors first.

---

## How it all started:

Recently a friend shared a link to [grep.app](https://grep.app), a super fast GitHub search tool.
I started hunting for known password and API key prefixes. One of them landed
me on this repo: https://github.com/985Ming/qlk.

This is a repo of ~99 obfuscated python and js scripts, with the description:

Original Chinese:
```
青龙脚本库 2025年新本；脚本q群1025838653
```

English translation:
```
Qinglong Script Library – New scripts for 2025; Script QQ Group: 1025838653
```

This really piqued my interest, what on earth have I just stumbled upon (rip
StumbleUpon 2002 - 2018)

Well after cloning the whole repo I realised that I couldn't read or understand
any of it, so now I have to, there goes my weekend.


---

## What on earth is Qinglong?

This was about all I had to go off to figure out what was going on. Turns out
this is a program used by wool farmers to run scripts
on a regular basis. Think of this like a webui for cron jobs: https://github.com/whyour/qinglong

This is a common tool for people who do "wool", or reward farming in English.
They run Qinglong as their orchestration server. Submit a script, set a
cadence, and it fires. qlk was a pile of exactly those scripts.

This turns out to be a full on ecosystem of rewards farming -> monetization ->
cashout chains.


---

## The 黑灰产 or black/grey industry of 薅羊毛

Where there is money to be made, someone will find a way to exploit it. I went
in expecting a few people swapping scripts. I came out the other side with 16
actors, 26 repos, and 60+ targeted platforms.

As part of this there is an entire structure that is built around this, and the
more I pulled on the thread the less it looked like a few people swapping scripts
and the more it looked like an actual supply chain. Roughly, it stacks up like this:

- **The operators** — the people writing and running the scripts. Two camps: the
  reward farmers (985Ming, xxwppp, KingJin, smallfawn and friends) going after
  Chinese loyalty and points programs, and a separate crowd cracking iOS in-app
  purchases (MCdasheng, Yu9191). Different targets, same playbook.
- **A protection layer** (protecting the scripts) — qlk's own obfuscation came
  apart easily, and that turned out to be the easy tier. One operator, wyourname,
  runs the industrial version: DRM as a service, encrypted `.so` loaders plus a
  C2 server that hands out the decryption key per machine. The other authors rent
  it so their scripts can't just be lifted straight off GitHub. That tier is the
  one that actually stopped me. At least this is what I think is happening.
- **The plumbing** — Qinglong to run everything, plus a from-scratch clone called
  NiuPanel, obfuscators to hide the scripts, a shared deobfuscator to unhide them,
  OCR services to solve CAPTCHAs, and shared device-ID pools so every bot looks like
  a real phone.
- **The targets** — those 60+ platforms. Music, video, novels, telecom, banks... and
  more uncomfortably, civic and government apps and even state media.
- **Cashout** — points become vouchers become cash, resold on Xianyu or Pinduoduo, or
  lottery wins paid straight out to Alipay.

The whole thing is really just one pipeline: the scripts -> Qinglong runs
them on a schedule -> they hammer the target apps -> points and coupons ->
resold or cashed out -> a WXPusher notification pings the operator to say the
money landed. Distribution sits over the top of all of it: GitHub, Telegram, QQ
groups, and a marketplace at script.345yun.cn.

And here's the bit that made me really worried, and realised that this really
is not just some skids: in at least one case the tooling steals from the people
using it. One of the most capable operators, smallfawn, sells a JD.com login
tool to other farmers that's quietly wired to send the harvested logins,
plaintext passwords included, three times a day back to a server they control.
They are, quite literally, farming the farmers.

I should be straight up about where this all ends, because it's the part that's
most of the work and least of the fun: the modern scripts are sealed behind that
wyourname C2, and the key server is effectively dark, it 404s, and a `status:
false` flag gates the handout. And even getting that far, the loader geolocates
you and POSTs a fingerprint of your machine to a box in Shanghai first, so I'd be
handing my own setup straight to them. So I mapped 49 of them and decrypted
exactly... none. Everything I did manage to crack is the older, weaker tier.

Over the next few posts I'll pull each layer apart, so stay tuned for:

1. **[The DRM, part 1]({% post_url 2026-06-23-the-wool-drm %})**: wyourname's
   old Cython loader, and how I reversed it end to end. The key was baked into
   the binary, so it protected nothing.
2. **[The DRM, part 2]({% post_url 2026-06-23-the-great-rust-wall %})**: the
   current Rust tier, where the key lives on a C2 and never on your machine, and
   how far I got without ever breaking it.
3. **[Farming the farmers]({% post_url 2026-06-29-farming-the-farmers %})**:
   smallfawn's JD.com login tool, quietly wired to rob the people who buy it.
4. **The civic angle**: how government, civic, and state-media apps got dragged
   into all this.
5. **The attack mechanics**: the handful of tricks that show up again and again
   across 60+ platforms.
6. **The cast**: the 16 actors, and how I mapped the whole bloody thing from
   one random repo.

All of it was read-only, I didn't farm a single account or log into anything,
and anything live went to the vendors first.
