---
layout: post
category: Security
title: "Forging the government's lottery: China's civic apps run on a shared reward backend with no real secret"
heading: "Forging the government's lottery: China's civic apps run on a shared reward backend with no real secret"
description: "Dozens of Chinese city, civic and state-media apps run their points-and-lottery campaigns on a handful of shared B2B SaaS backends. The signing that protects them uses a public salt and a key the server hands you on request. Here's the multi-tenant exposure — and why it's the more important story than any one app."
---

## TLDR:

- The civic apps in this scene are not bespoke. The city app and the
  state media apps are mostly just thin skins over a handful of B2B
  "interactive marketing" SaaS providers eg **tmuyun (天目云), aihoge, jinhua
  (金华云), and Duiba (兑吧)**. They are separated only by a `client_id`.
- The signing that is supposed to make their reward campaigns unforgeable has
  **no real secret**. The GET signature uses a **public salt**, and the login
  HMAC key is **served to you on request** by an init endpoint, and every input is
  attacker known, and eaisly mapable.
- The campaigns these tenants run eg daily sign-in bonus, read an article for
  points, quiz/"study" completion, sweepstakes draws, are all forgeable self
  serve. And the same shared signing scheme also guards the account and
  member endpoints, so the same forgery plausibly reaches the **citizen
  PII** behind every tenant city, though I never exercised that half.
- Cash-out is to **Alipay** (`phone&password&支付宝姓名&支付宝账号`).
- The part that makes this more than commercial fraud: **state-media loyalty
  farming** on the same shared base above, and on separate infra
  (`bjsfxh.com` + `luckystarpay.com`) **Beijing government quizzes
  auto-answered by an LLM** (Xunfei Spark) for cash lottery. Inflating
  engagement on state content and gaming a government reward program is a scary
  thing to do in China...
- It's not just one operator. The same base SaaS turns up in unrelated farmers'
  scripts across at least two Zhejiang prefectures and into Guangdong. The
  providers, not any one farmer, are the only real concentrated attack surface.
- This was all found via the public GitHub repos, I did not hit any endpoint,
  nor run any of the scripts, I merly read them.

---

## Terms in this post

If you landed here mid-series,
[the hub post]({% post_url 2026-06-23-a-weekend-in-the-wool %}) has the whole
ecosystem overview and the full glossary. The load-bearing terms for this
one:

- **wool / 薅羊毛** — Chinese reward-farming. Running scripts on a schedule
  (typically via Qinglong, a cron-job webui) to drain loyalty points,
  coupons, and lottery payouts out of apps, then cashing out. The whole
  scene this series is mapping.
- **script / wool script** — the actual code the farmers run. Usually
  Python or JavaScript, one file per targeted app. It logs in, hits the
  app's reward endpoints, and pockets the payout. In this post the ones I
  read are all **plaintext** — no DRM, no loader, so I can read them line
  by line.
- **farmer / operator** — the person writing and running wool scripts.
  This post leans mostly on **qltrojan** (`@xzxxn777`), a farmer whose
  civic-app scripts I could read straight through.
- **SaaS (multi-tenant)** — one backend serving many branded apps,
  separated only by a `client_id`. The whole story turns on this.
- **client_id / tenant_id** — the per-app identifiers. Swap them and
  you're talking to a different city on the same backend.
- **signing salt / HMAC** — the "secret" that's *meant* to make requests
  unforgeable. Here the salt is public and the key is served on request.
- **ddddocr** — an open-source deep-learning OCR that solves the slider
  and image CAPTCHAs these campaigns use.
- **Duiba (兑吧) / tmuyun (天目云) / aihoge / jinhua (金华云)** — the
  shared civic-marketing SaaS providers this post is about.
- **Alipay cash-out** — sweepstakes winnings paid to a real Alipay
  account, stored in the farming script's config.
- **ev2** — the sealed-payload format from
  [the Rust wall post]({% post_url 2026-06-23-the-great-rust-wall %}) — the
  DRM-tier scripts I could *not* decrypt. Shows up once in "Where it stops":
  one ev2 payload lines up with a civic app on this SaaS, most don't.

---

## Background: the civic app that didn't look special

This one started with a qltrojan script, the same gov app farmer (`@xzxxn777`)
from the last posts pointed at a city app. 西施眼 (Zhuji), 掌上武义 (Wuyi),
今日越城 (Shaoxing): small regional civic apps, the sorta thing a local government
stands up for citizen engagement, training, and surveys. Sign in daily, read
some articles, earn a few points, maybe win a lottery draw. Nothing that should
have caught my eye, honestly, this is super common these days, think of those
daily bonuses on mobile games. I only opened the first one because it was a
government app and I wanted to see what a Chinese city was actually running
under the hood, and why some app farmer was interested in it. If they saw
something, maybe I should be looking too!

Then I opened the second one and something felt off. Same `/api/account/init`.
Same `/web/init?client_id=`. Same `/api/user_mumber/sign` (No that is not a
Neuro mispelling). Same `/api/zbtxz/login`. Different city, different
`client_id`, different `xsb_<region>` code, and otherwise the same script. So I
opened a third. Same again.. I am starting to see the theme here.

These weren't bespoke apps. They were tenants. Once you see that, the
interesting target stops being any one civic app and becomes the handful of
SaaS providers they all sit on. That's the moment this stopped being a farmer
story and became a SaaS story.

---

## The providers (the real subject)

There are four B2B "interactive-marketing" SaaS providers doing the heavy
lifting across the farmed apps, and each one is multi-tenant. You can see it in
the endpoint surface: byte-identical across every tenant script I read, only
the `client_id` and `xsb_<region>` codes changing between them. Which makes
sense, every prefecture in China isn't standing up its own bespoke in house
points and lottery stack, they're all buying it from the same handful of
vendors.

| Provider | Role | Hosts |
|---|---|---|
| **tmuyun / 天目云** | Account + media-content engagement (the shared base) | `passport.tmuyun.com` (SSO), `vapp.tmuyun.com` |
| **aihoge** | Activity SaaS — sweepstakes / news / member | `m.aihoge.com`, `xingyun.aihoge.com` |
| **cloud.jinhua / 金华云** | Quiz/"study" + wheel sweepstakes | `op-api.cloud.jinhua.com.cn` |
| **Duiba / 兑吧** | Third-party lottery/prize SaaS | `*.activity-42.m.duiba.com.cn` |

Each farmed app chains a few of these providers together. `YueCheng.js` (越城)
does account + content on **tmuyun**, then a quiz on **jinhua**, then the
lottery draw on **Duiba**. `DaChao.js` (大潮, Guangdong) does the whole account
content activity stack on **aihoge**. `TongLu.js` (桐庐) rides tmuyun then a
separate PHP style lottery engine. And that's four distinct sweepstakes engines
across five scripts, which is how I know these are four separate providers
being stitched together, not one big vendor with multiple product lines.

---

## One `client_id` to rule them: the multi-tenant model

Here's the thesis, and it comes in two halves.

First: `tmuyun.com` and `aihoge.com` are running the **same base software**.
Not similar, not same functionality, but the same.

Every one of these lines up between them:

- The account endpoints: `/api/account/init`, `/web/init?client_id=`,
  `/api/zbtxz/login`.
- The member endpoints: `/api/user_mumber/*` (yes, same typo on both).
- The content endpoints: `/api/article/*`.
- The `zbtxz` SSO path itself, which is not a generic name.
- The signing salt (same short string, hardcoded, identical on both).
- The `xsb_<region>` tenant code scheme.

That's no coincidence, and it's not two vendors happening to both use the same
conventions. Two teams or companies dont both call their endpoint
`/api/user_mumber/` with the same typo. So the honest options are: one vendor
running two clouds, one vendor selling a license, or a shared white label SDK.
Which of those it actually is, I can't tell.

Second half, and this is the point of the post. Whichever of those it is, the
consequence is the same: each provider serves many cities through one
`client_id` keyed campaign API. So the exposure is the **provider**, not the
app. Reach one provider's activity API, map it out and figure out how to game
it, and you can game all of their clients.

The plaintext scripts alone name ten civic tenants across three Zhejiang
prefectures and one Guangdong prefecture, and the `xsb_<region>` naming
scheme means there might be many more `xsb_<something>` tenants I never saw a
script for. And this is the same shape as the commercial brand case: one
Weimob endpoint (`xapi.weimob.com`) fronts 100+ retail brands through tenant
IDs the same way, and the same farmers hit it with the same playbook.

Civic is just a worse version of that pattern: the tenants are cities and
government programs, and what sits behind the campaigns is citizen PII and
public trust, not coupon budgets.

---

## It's not one operator

If this were one farmer, it would be a smaller story. It isn't. The
**tmuyun** base turns up in scripts from operators with no connection to
qltrojan:

- **Taizhou (台州)**: `passport.tmuyun.com` in Sembrono's scripts, and the
  same base farmed by the **爱仙居 (仙居县)** author (Telegram `t.me/fxmbb`,
  invite codes handed out publicly).
- **Guangdong**: aihoge running the identical base for 大潮 (潮汕).

So the shared base spans at least two Zhejiang prefectures and reaches into
Guangdong, farmed by multiple independent operators. That's the tell that
the **provider** is the attack surface, not any one farmer. The
concentration is in the SaaS, and every tenant inherits its weaknesses.

> **Reach beyond the cast:** qltrojan's civic suite travels further than
> the operators I mapped. A fork of `smallfawn/decode_action` surfaced a
> full mirror of it on a subscriber's iOS device (`bhlzjy/Surge`), and
> `zjk2017/ArcadiaScript` redistributes the same civic scripts to its own
> community. Full distribution map is in the cast and tradecraft post.

---

## The signing scheme, reconstructed: why it isn't a secret

The campaign requests are signed two ways, and neither one carries a
real per client secret.

**The GET signature** is a SHA-256 over a fixed field order:

```
signature = SHA256( path && sessionId && uuid && time && salt && tenantId )
```

- `path` is the URL with the query stripped, `time` is `Date.now()`, `uuid`
  is a random v4. All attacker known.
- `salt` is a short static string, and yup this is **public**, hardcoded
  identically in every farmer's plaintext script. And here it is: `FR*r!isE5W`

**The login signature** is an `HMAC-SHA256`. This is the one that should
have been a real secret, and it's the one where the design gives itself
away:

- The HMAC key is called `signature_key`, and the client doesn't ship with
  it. Instead, the client asks for it: `GET /web/init?client_id=<id>` and
  the server hands the key back in the response. Every call to a fresh
  `client_id` gets served its own HMAC key on request.
- The password in the login body *is* encrypted, RSA-1024 under a
  hardcoded public key. But that's transport encryption, so nobody on the
  wire can read the password. It's not authentication, and it doesn't
  stop the caller from forging the signature. Also RSA-1024 has been considered too weak for
  [over a decade](https://en.wikipedia.org/wiki/Key_size#Asymmetric_algorithm_key_lengths) —
  NIST disallowed it for new keys after 2013 (see
  [SP 800-131A](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-131Ar2.pdf)),
  and current guidance is a minimum of 2048 bits. Not the load bearing
  bit of the story here, but a tell about how much thought went into
  any of this.

One honest caveat on the init-endpoint claim: I know the client calls
`/web/init` *before* login, because that's what the plaintext scripts
do — it's the bootstrap step that gets you the key you then need for the
login signature. What I haven't verified is that the endpoint accepts a
request from an entirely fresh caller with no prior state at all. I
never made that call. If it turns out to have some invisible gating (IP
allowlist, referer check, an app-token cookie set by an earlier
handshake I haven't found), the forgery story tightens by exactly that
much. My read is that it doesn't, because the scripts don't carry any
such state and the flow makes no sense otherwise, but that's an
inference, not something I proved on the wire.

Put together: for any `client_id`, ask the init endpoint for the key, take
the public salt, and you can forge every signature the campaign API expects.
Nothing has to be *compromised*, the design hands you everything. The
`getParams`/`getBody` code that produces these signatures is sitting in
plaintext in every farmer's script and it's byte-identical across all five,
so I'm confident it's the real thing and not one operator's misreading.

For completeness, here's the rest of the fingerprint. aihoge layers a
second SHA-256 salt on top of the base one for its member signature
(`/memberhy/tm/signature`): `KO>N<O5&3^L1#YH0H1#G91*2H`. And the login-body
RSA-1024 pubkey — the one that gives you transport encryption on the
password but no authentication of the caller — is this:

```
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQD6XO7e9YeAOs+cFqwa7ETJ
+WXizPqQeXv68i5vqw9pFREsrqiBTRcg7wB0RIp3rJkDpaeVJLsZqYm5TW7F
Wx/iOiXFc+zCPvaKZric2dXCw27EvlH5rq+zwIPDAJHGAfnn1nmQH7wR3PCa
tEIb8pz5GFlTHMlluw4ZYmnOwg+thwIDAQAB
```

None of these are secrets in any meaningful sense. They're in five
plaintext GitHub repos already, they've been there for months, and anyone
who wanted them has already got them. Holding them here would only hide
the shape of the problem from the people who need to see it — the
vendors, the tenants embedding this SaaS, and anyone else running the
same "public salt plus served key" design and wondering if it's fine.
It isn't.

---

## What gets farmed, and the cash-out

The campaign actions are mundane loyalty mechanics, automated end to end:
read for points (with a hardcoded dwell time the script isn't even
pretending to read the article), like and share tasks, daily sign in,
quiz/"study" completion, and the sweepstakes draw. Points and prizes
convert to cash, paid straight to an Alipay account the script carries in
its config (`phone&password&支付宝姓名&支付宝账号`).

The CAPTCHA in front of the draws is solved with `ddddocr` and the
operators runs their own instance of it, which is a nice touch. The exact
dwell constant, the slider-CAPTCHA bypass, and the point encryption trick
are in the attack mechanics post (soon come).

---

## State media, and a government quiz answered by an LLM

Everything above is broken engineering. Weimob has the same problem for
coupon budgets. The reason to care about this one specifically is what
sits behind the tenants. Two branches lift it out of "commercial fraud"
and into something I think matters more.

### Manufactured engagement on state content

The first branch is **state media**. The same account and content mechanics are
as follows: read this article, stay N seconds, like, share, run against
state media apps like Qingdao's `appnews.qingdaonews.com`. The farming here
isn't just points theft. It's **manufactured engagement on state content**, at
whatever scale the operator wants.

Engagement metrics on state media aren't just a vanity number like the reshares
on my bsky posts. They feed a feedback loop that impact real decisions. Which
story got promoted this week, which topic gets more resource next quarter,
which framing an editor was rewarded for,  which propaganda line "landed" and
which one didn't, what the population of that prefecture are interested in.
Those decisions are made against numbers, and those numbers are supposed to
represent what actual citizens actually read, and interact with.

If the top read article for a week is inflated by a Qinglong cron running
a `read_time=5938` GET against a headless news API, then the editors
optimising to that column are optimising toward a bot's taste in
articles. The propaganda effectiveness read out is measuring the wrong
population. The scripts don't know or care what's in the article. They
just report having read it. Any decision made downstream of "which
articles are performing" is now, in part, being made about scripts.

However while the scripts dont care, they can be made to care, if an operator
wants to inflate particular articles they can, they can drive engagement
towards something they care about, or bad publicity article of their
competitor, etc.

This isn't a hypothetical harm. It's the harm the platform's *own*
metrics are supposed to prevent, and this one signing scheme lets any
farmer with a `client_id` become a plausible reader at whatever scale
they want.

### The government reward program answered by an LLM

The second branch: Three qltrojan scripts target **Beijing municipal
social-services programs**: 北京社服 96156, 北京社服活动, and 北京趣味多
(`bjhb` / `bjsfcks` / `bjqwdcks` env vars, `sfapi.bjsfxh.com` +
`qw-api.bjsfxh.com`, prizes vended by `ylapi.luckystarpay.com`). These run
civic education knowledge quizzes, questions about municipal services,
community participation, that sorta thing, with a cash lottery entries as the
reward for participation. The point of the program is to get citizens to
learn the material.

The script does not learn the material. It reads the current question off
the API, wraps it in one line, and asks an LLM for the answer. Then it
submits the answer, moves to the next question, and at the end of the
quiz it claims the lottery draw. Five exams per activity, twenty
questions each, one letter back per question. The whole loop is around a
hundred and fifty lines of Python.

The LLM is **Xunfei Spark**, iFlytek's flagship model
(`spark-api-open.xf-yun.com`) which is a Chinese national-champion AI product,
some of whose corporate structure sits inside the state ecosystem, meaning that
it might be trained on these quizzes themselves! The farmer's script even points
buyers at the official Spark signup portal in a comment on line 2, "get your
own API key here."

The system prompt is *"你是知识渊博的助理"* — "you are a knowledgeable
assistant." The user message is `f"{question}；请给出答案，只要字母"` —
"give the answer, only the letter." The model is set to `"lite"`, the
cheapest tier in the family. And because Spark sometimes wraps its
answer in extra prose, the script backs itself with a regex:

```python
match = re.search(r'[A-D]', result)
```

Grab the first uppercase A–D you see and submit it. The comment on the
line above reads *"使用正则表达式提取第一个大写字母，答题专用"* — "use
regex to extract the first uppercase letter, quiz-specific." The
operator wrote the helper and labelled it as the quiz-answering path.

So: a Chinese municipal civic-education reward program, whose whole point
is teaching a bit of civic knowledge, is being answered by a cheap Chinese
LLM operated by a state aligned AI vendor, for cash paid out of a lottery
platform, on behalf of ten plus accounts per operator on cron. Nobody in
that chain is doing what they think theyre doing. The program thinks
it's teaching residents. The AI vendor thinks it's selling an assistant.
The lottery platform thinks it's rewarding engaged citizens. Only the
farmer is being honest about what's happening. Doing this to a government
reward program in China is, and I say this carefully, a scary thing to
do.

---

## Where it stops

The honest limits, because they matter more here than usual.

Whether tmuyun and aihoge are one vendor, a license, or a shared white-label
SDK is unknown.

The links from the sealed **ev2** payloads (the DRM story from
[part 1]({% post_url 2026-06-23-the-wool-drm %}) and
[part 2]({% post_url 2026-06-23-the-great-rust-wall %})) into these civic
providers are low-confidence. The one strong twin is ev2 `yuecheng` ↔
今日越城, whose plaintext qltrojan client (`YueCheng.js`) is an exact
match. I do **not** claim the other ev2 scripts run on these providers,
and where I've named specific state-media outlets from filenames alone
(`xinhuamm`, `xiangshan`, `yongpai`) those are guesses. `yongpai` in
particular had its old endpoint inventory disproven once already; I'm
being careful with it.

And the whole signing story is reconstructed from the farmers' plaintext
twin scripts. Not from an account, not from touching the live APIs. I
never logged in, and the "the member data behind the campaigns" claim
follows from the account APIs sharing the forgeable signing scheme — it's
an inference from the code, not something I exercised.

---

## IOCs

SaaS fingerprint and hosts below. Salts, RSA pubkey, and field orders are
all in the post — they're already in five plaintext GitHub repos, and
holding them here helps nobody. I'm still not shipping a turn-key signer,
because "you can read the recipe" and "here's a bag of pre-mixed
ingredients pointed at production" are not the same thing.

| Indicator | Role |
|---|---|
| `passport.tmuyun.com`, `vapp.tmuyun.com`, `app.tmuyun.com` | tmuyun account/content SaaS |
| `m.aihoge.com`, `xingyun.aihoge.com` | aihoge activity SaaS |
| `op-api.cloud.jinhua.com.cn`, `op-h5.cloud.jinhua.com.cn` | jinhua quiz/wheel SaaS |
| `*.activity-42.m.duiba.com.cn` | Duiba lottery SaaS |
| SSO path `/api/zbtxz/`, `xsb_<region>` codes, `X-DEVICE-SIGN: xsb_*` | tmuyun/aihoge shared-base fingerprint |
| GET-sign field order `path&&sessionId&&uuid&&time&&salt&&tenantId`; salt `FR*r!isE5W` | forgeable signature (tmuyun/aihoge shared) |
| aihoge member-signature salt `KO>N<O5&3^L1#YH0H1#G91*2H` | aihoge `/memberhy/tm/signature` |
| RSA-1024 login pubkey `MIGfMA0...AQAB` | transport encryption on `password`, not auth |
| `GET /web/init?client_id=` serves `signature_key` | HMAC key served openly |
| `sfapi.bjsfxh.com`, `qw-api.bjsfxh.com`, `ylapi.luckystarpay.com` | Beijing 96156 gov quiz + lottery |
| `spark-api-open.xf-yun.com` | Xunfei Spark LLM — auto-answers gov quizzes |
| `appnews.qingdaonews.com` | state-media engagement farming |
| `ddddocr.xzxxn7.live`, `@xzxxn777` | qltrojan OCR solver + operator handle |
