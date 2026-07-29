---
layout: post
category: Security
title: "Sixteen strangers and a shared obfuscator: mapping the wool scene"
heading: "Sixteen strangers and a shared obfuscator: mapping the wool scene"
description: "A 16 actor map of a Chinese reward farming scene, built out from a single GitHub repo over a weekend. The operators know GitHub is dangerous and scrub their history religiously, but they defend the page and forget the graph: the scrub itself is a trace, and the deobfuscator they all forked is a public register of who's in the scene."
---

## TLDR:

- What looked like 16 independent authors is one shared tool stack. Custom
  obfuscator helper variable names carry between accounts, four unrelated repos
  target the same obscure mini program, every Unicom bot pulls device IDs from
  the same Gitee file, and the git-history scrub recipe is published as a
  how-to on one of the operators' own blogs.
- These operators know GitHub is dangerous. One of them publishes a
  how to on wiping your commit history, and the scene treats the scrub
  as routine (we saw it in multiple places). It doesn't save them: trying to
  hide your tracks is itself a trace, and they guard the obvious surface (repo
  contents, secrets) while leaving the structural one (fork graphs, delete
  diffs) wide open. They defend the page, not the graph.
- The scene's shared JS deobfuscator, `smallfawn/decode_action`, has
  1,300+ forks. Every fork is a public git history of every script that
  operator ever needed decoded, and the fork list itself is a directory
  of who's in the scene. Nobody meant it to be a signal. It is one
  anyway, and it's how I found actors the toolchain fingerprint missed.
- Sixteen actors is what I mapped, not a complete census. Handle -> real person
  is always `(inferred)`. I mapped operators and infrastructure, not
  identities.

---

## Terms in this post

If you landed here mid-series,
[the hub post]({% post_url 2026-06-23-a-weekend-in-the-wool %}) has the
whole picture and the full glossary. The load-bearing ones:

- **OSINT**: mapping a scene from public artifacts only, not from
  touching anything live.
- **IOC**: indicator of compromise. Any specific thing (domain, key,
  filename, magic prefix, handle) unique enough to pivot on.
- **orphan-branch scrub**: `git checkout --orphan ... && push -f`.
  Rewrites a repo's whole history to erase a leaked secret. Also very
  obviously *the thing* that happened.
- **device-ID pool**: a shared list of spoofed device fingerprints. Every
  bot pulls from the same file, so every user of these scripts presents
  the same handful of "phones" to fraud detection.
- **ev2**: the sealed payload format from
  [part 2]({% post_url 2026-06-23-the-great-rust-wall %}). Opens with
  the 12-char magic `|(LTm_R7mUd@`. That magic is one of my pivots.

---

## What a shared cipher actually proves

I already knew this was a scene, and not just a few kids messing around.
[The first post]({% post_url 2026-06-23-a-weekend-in-the-wool %}) laid
the supply chain out end to end: operators writing the scripts,
wyourname renting DRM over the top, shared plumbing underneath, a
marketplace stitching it all together. What I didn't have yet was hard,
code-level proof of *who was tied to who*. "This looks like a supply
chain" is a structural hunch. I wanted a fingerprint, and proof.

Here's where the fingerprint turned up.

The `985Ming/qlk` repo has two hand rolled obfuscators. Not off the shelf, not
`jsjiami.com.v7`, not `sojson`, just private helpers with names like
`custom_subtract` and `xor_b85`. When youre rolling your own crypto you get to
name your own helpers, and names like those don't turn up in a normal Python
codebase by accident. Obiligtory "Don't roll your own crypto".

Then they turned up in `xxwppp/2025`.

`康师傅瓶盖1.3.py` uses the same subtract cipher. `王老吉签到1.0.py` uses
the same b85+XOR. Different account, different marketplace watermark,
same private crypto.

I want to be careful about what that does and doesn't buy me, because
this is exactly the spot where this kind of work fools people. It is
*not* proof that qlk and xxwppp are the same hands, and it isn't even
proof of who wrote either script. Remember what xxwppp does for a
living: they take other people's plaintext and run it through their own
obfuscation before reselling it. In a scene that sells obfuscation as a
service, the toolchain is the most-shared thing in it, not the least. A
matching cipher might mean "same author", or it might just mean "both
scripts went through the same laudnromat", and I can't split those apart
from the cipher alone.

What it *does* buy me is a signal, and that turns out to be the thing
worth having. Off the shelf obfuscators (`jsjiami.com.v7`, `sojson`)
mark nothing, everyone on earth runs those. A hand rolled
`custom_subtract` that shows up in no normal Python codebase is the
opposite: it only ever circulates *inside* this circle, so wherever it
turns up, that repo is inside the circle too. It doesn't tell me who is
who. It tells me these accounts are all pulling from one shared tool
stack, which is the entire idea.

Everything past this point is me pulling on that thread. And the two moves that
did most of the work from here are both opsec own-goals: the traces these
operators left *while trying to cover them*, and the GitHub surfaces they never
thought to hide. They know the platform is dangerous. One of them, as you'll
soon see, publishes a guide to scrubbing your repo. But the risk they're
defending against is "someone reads my code", not "the platform's own structure
is a ledger". They defend the page. They don't defend the graph.

---

## The shared toolchain

Once you know to look for it, the fingerprints pile up fast:

- **The custom obfuscators.** `custom_subtract` and `xor_b85` tie qlk ↔
  xxwppp.
- **`kozbs.com`.** A niche WeChat mini-program (植白说) with obscure
  integral shop endpoints, scripted by *four* independent authors:
  qlk, Xx1aoy1, MCdasheng, KingJin. When a target this small shows up
  four times, someone posted it in a private chat and the script
  propagated.
- **`integralapi.kuwo.cn`.** KuWo Music is in every primary farming repo
  I looked at. Same `/v1/getWithdraw` endpoint across five of them.
  Shared exploit, not five independent discoveries.
- **`script.345yun.cn`.** xxwppp's marketplace watermark travels with
  sold scripts into sembrono's and Xx1aoy1's repos. Distribution, not
  authorship. And the marketplace itself is a script laundering step:
  someone writes a plaintext script (KingJin, leafTheFish), xxwppp
  obfuscates it, watermarks it, resells it, aggregators re-host it
  under their own names. Provenance is a mess by design.
- **The shared device-ID pool.** Every decrypted Unicom script pulls
  from the *same* file:

  ```
  https://gitee.com/kele2233/genxin/raw/master/ydid.json
  ```

  Every bot, across every operator's install, presents the same handful of
  device IDs to China Unicom's fraud detection. Which means the whole scene is
  easier to catch than any single operator running their own pool would be.
  Nobody wants to be the one who burns an afternoon generating a fresh pool,
  though, so they all just inherit `kele2233`'s. Who I guess will generate more
  if this set gets burnt

There's a live remote execution thread running through this too, and
it's worth flagging before I move on. Three xxwppp scripts
(`联通云手机.py`, `联通云盘.py`, `白鲸鱼旧衣服.py`) do this on every run:

```python
execute_code(main)   # pulls fresh code from git.365676.xyz
```

Every user of those scripts is running whatever `git.365676.xyz`
decides to serve that day. Silent auto update dressed up as a design
choice, and whoever controls that CDN (wyourname, from the DRM post)
can push arbitrary Python to every install without so much as a version
bump. Nobody's checking, and nobody ever does.

Two operators can both ship `猫猫阅读.py`. Only one of them has the
`custom_subtract` helper that matches the tool stack that account has
been shipping for two years. That is the whole reason the fingerprint
pivots above can place a repo inside the circle, in a scene where the
scripts themselves get laundered a couple of hops before you ever read
them.

---

## Git history was the highest payoff move

That's the first of the two own goals, and it's the one they actually
try to defend. Hiding your tracks leaves a trace. A deletion isn't a
disappearance, it's an event: git records that something was removed,
roughly when, and usually what, and all of it stays public long after
the thing itself is gone. A scrub is a diff.

Which is exactly why git history was the highest payoff move for me. People
only bother scrubbing what matters, so the deletions double as a map of where
the good stuff was. And sometimes the scrub does more than point: the act of
removing something can drag a load bearing fact from "probably" to "definitely"
on its own. Two examples.

### `HASL1`: how a scrub converts "probably real" into "definitely real"

From [the smallfawn post]({% post_url 2026-06-29-farming-the-farmers %})
the credential relay backend is `8.141.174.247:3000`. A skeptical reader
should be asking whether that IP is a real backend or just a placeholder
someone forgot to fill in. The git history settles it, and it settles it
because smallfawn made the exact mistake everyone in this scene makes.

Three consecutive commits:

- **2024-11-10**: first commit ships
  `"key": "HASL1", "server": "http://8.141.174.247:3000"`.
- **2024-11-11**: scrubbed. Both replaced with placeholders
  (`KEY`, `APIURL`).
- **2024-11-12**: server address quietly re added, key left as `卡密`
  (Access Code, literally the Chinese placeholder).

You don't scrub a value and then re add a placeholder. `HASL1` was a
working shared secret that sat in public for about a day, and the IP it
sat next to is the real backend. Left completely alone it would have
read as a credible IP next to a suspiciously literal key. The act of
scrubbing it is what converted "probably real" into "definitely real".
They told me by trying not to.

### qltrojan's May 2024 wool affiliation

Two scripts, `bilibili_play.py` and `qimao.py`, both created 2024-05-07
and deleted 2024-05-12. Both downloaded `.so` files from
`files.doudoudou.top` **and** `files.doudoudou.fun`. That five-day window
pins qltrojan's wool affiliation to at least early May 2024, confirms
`.fun` was a live loader CDN alongside `.top`, and shows a deliberate
scrub of exactly the most obvious DRM-dependency evidence, one week in.

Someone looked at those two files, thought "I should get rid of those",
and did. But they left enough of the surrounding tree in place that the
affiliation is still inferable from the launcher scripts they kept,
which is how I noticed the deletion in the first place.

---

## They wrote the how-to themselves

This is the one I want to highlight, because it's the finding that made me
crack up.

Once you clock smallfawn, qltrojan, and leafTheFish (who wiped their
entire GitHub account) all pulling the same `orphan-branch; push -f`
move, you start wondering where they all learned it. Turns out you
don't have to wonder. One of them just publishes it.

Actor 14 (xiaobaiweinuli, persona `星霜`/xingshuang) has a blog. On
that blog is a post literally titled *"删除github中的提交历史记录的
操作步骤"*, "steps to delete github commit history." It walks through
the exact recipe:

```
git checkout --orphan latest_branch
git add -A
git commit -am "message"
git branch -D main
git branch -m main
git push -f origin main
```

This is the same recipe smallfawn used on `HASL1`. It's the same recipe
qltrojan used to nuke `bilibili_play.py`. It's what leafTheFish would have run
before nuking their whole account. The scrub is a scene rite of passage, and
the how to is documented as exactly that: not a buried private-group post, a
public blog with a permalink you can bookmark, and an author you can identify.

Xingshuang is a hobbyist, not a load-bearing operator. They run a wool
fork and a Qinglong panel off their home LAN. But the fact that *they*
are the one publishing the recipe is the interesting part: the tradecraft
isn't secret, it's common knowledge, taught operator to operator, with
the Chinese language security community around it writing the
walk throughs.

Which is the whole point, for my purposes. These operators are not
naive about GitHub. They know history is forever, they've got a shared
drill, and run book for wiping it, they treat the scrub as basic hygiene. So a
scrub isn't a slip. It's a decision, made by someone who knew the platform
remembers and acted on it. And a decision is signal in a way an accident never
is: when I find one, I'm not looking at someone who forgot, I'm looking at the
exact spot someone decided was worth hiding. `HASL1` is that. qltrojan's
deleted loaders are that. The delete points at the thing.

Nice bit of OPSEC irony to close on, the blog whose entire reason for existing
is "delete your git history" is a walking counterexample to itself. Its other
pages leak enough about their author's own identity and self hosted stack to
unwind precisely the anonymity the how to is meant to buy. They'll teach you
how to erase your tracks on a site that plainly doesn't take its own advice.
I'm not printing the specifics, doxing this person provides no value, but
that's the finding in one line: the tradecraft and the self own live on the
same domain.

---

## The tool that doubles as a register

Somebody in this scene built a JS deobfuscator that runs on GitHub
Actions, and I'll say up front it's a genuinely nice bit of kit. Fork
`smallfawn/decode_action`, push an obfuscated script to `input.js`, and
the CI pipeline hands you back the cleartext in `output.js`, right there
in your own repo. It eats jsjiami v5/v6/v7, obfuscator.io, sojson,
jjencode, jsconfuser, awsc for breakfast. Everything the scene throws around.
693 stars, 1,300+ forks. Free serverless decode infrastructure running on
GitHub's own compute, and I mean that as a compliment.

It works. Which is exactly why the scene adopted it wholesale.

Here's the part nobody stopped to think about, and it's the second half
of the story. The scrub is what they do to the page. The fork list is
the graph they forgot was public.

Two things fall out of it. First, every time an operator decodes a
script through their fork, that transaction is a public git commit in
*their* fork. Every input, every output, every timestamp. The tool that
unhides the scene's scripts is also a **public timeline of which
operator needed which script decoded on which day.** Second, and this
is the one that actually grew the map: the fork list is a directory.
1,300+ forks is 1,300+ accounts that reached for this tool, and walking
it is how I turned up actors who never showed in the helper name
fingerprint at all. The toolchain ties together the people you already
have. The fork list hands you the ones you don't. Most of the extended
cluster in the closing section came from walking forks, not from
grepping helpers.

Three concrete fork profiles:

- **aini1351.** Fork history reads as a tidy tooling progression, not
  idle curiosity. August 2025: JD `const_id` anti-fraud token
  generators. October 2025: qltrojan's civic lottery scripts
  (`DaChao.js` on 2025-10-08, `WangChao.js` on 2025-10-19, the
  tmuyun/aihoge civic SaaS scripts from
  [post 4]({% post_url 2026-07-16-forging-the-government-lottery %})).
  May 2026: `今平湖` (another tmuyun civic app). June 2026: Panda
  Earn. That's not a hobbyist decoding one script for fun. That's an
  operator working through targets one at a time and leaving the
  cleartext of every single one of them sitting public in their own
  repo.

- **XiaoGe-LiBai.** Not just a decode_action user. Also writes their
  own Loon MITM plugins intercepting SF Express tokens
  (`ccsp-egmas.sf-express.com`), Kuaishou `salt`/`cookie`/`kaw`
  parameters (`api3.gifshow.com`, `az4-api.ksapisrv.com`), and
  Domino's Pizza China auth tokens (`game.dominos.com.cn`). The
  decode_action fork is just one tool in a full farming operator's
  stack, sitting alongside a JD cookie-pool manager (`svjdck` fork)
  and a custom Dockerfile. Their fork is basically a receipts drawer
  left open.

- **ACSDSZ.** The outlier, and the one I keep thinking about. Not a
  farming operator at all, but a full AI-autonomous reverse
  engineering pipeline. mitmproxy + Frida + jadx + apktool + a Qdrant
  vector memory + a Claude-based agent (they call the framework
  "Hermes"), all wired together over MCP servers. The docs claim they
  reversed Douyin's live room signing chain and Zhihu's `x-zse-96`
  (JSVMP + SM4 + bit-shuffle) in about 4.5 hours, at a Claude cost of
  ~¥24 (about 6NZD). Whether those specific reverses landed clean
  isn't really the point. What the setup *represents* is. The next
  generation of this exact attack surface doesn't look like a person
  hand coding exploit scripts. It looks like an agent chewing on the
  problem overnight and filing the results into a vector DB by morning.
  Reversing new signing schemes is getting cheap, and that should
  bother more people than it does.

  ACSDSZ also committed a live LLM API key and a live Qdrant API key straight
  to the public repo. Both `(verified)` at time of analysis. I've described the
  finding rather than reprinting the strings, for obvious reasons.

Three forks, three profiles, one deobfuscator. The whole scene reached
for the same tool because it's free CI. Not one of them noticed they'd
also all signed the same public receipt.

---

## The other half of the scene: iOS IAP crackers

Two operators run the iOS half on the same substrate but a completely
different attack surface.

**MCdasheng**: ~80 QuantumultX scripts, half rehosted IAP crackers,
half original farming. Runs a polished BoxJs subscription. Their
`kuwo.cookie.js` MITMs a KuWo cookie on iOS and shoves it into
Qinglong via OpenAPI. iOS captures, Qinglong farms. That cookie.js +
Qinglong handoff is the bridge that stitches this half of the scene to
the other.

**Yu9191**: 375 files, the largest iOS collection in the scene. A
GitHub Actions workflow commits `"update onetoken {ISO8601}"` every six
hours. `onetoken` is a subscription-validity marker, and a 6-hour commit
cadence at that scale isn't a hobby, it's a paid product with a customer
base big enough to justify the churn.

The `zbs.js` script targeting `kozbs.com` shows up on MCdasheng's iOS
side too, which makes it the *fourth* independent hit on that one
mini-program. Shared targets don't even respect the Android/iOS divide.

---

## The dead ends

Not every pivot pays off, and being straight up about the ones that didn't is
the only thing that keeps you from fooling yourself about the ones that did.

- **HAR library.** `wjf0214/qd-templates` is a 656-star repo of captured
  `.har` sign-in sessions. I got excited: if a wool subscriber ever
  caught their own `common.so` phoning home, that traffic could be
  sitting right there in a public HAR. So I grepped the whole tree for
  every IOC I had: `doudoudou`, `365676`, `wyourname`, `1.94.146`,
  `encData`, `VToken`. Zero hits. Different ecosystem entirely (QD
  signin, forum bots, VPN dashboards). No overlap. Nice idea, no fruit.
- **`passerby-b/didi_fruit`**: listed in `Yiov/wool` as an
  encrypted script source. 404 by the time I got there.
- **`gitlab.radish.today/root/script`**: self hosted GitLab
  referenced by Meituan scripts. Unreachable. Dead infra, or it was
  IP blocking me, and I couldn't tell which from the outside.
- **The `181.94.146.238` false positive.** A hit on
  `bermanboris/blocklist-ipsets` that turned out to be `181.94.146.238`,
  not `1.94.146.238`. One stray `1` in the wrong place. Caught it before
  it made it into any notes, but the lesson's worth keeping: substring
  matching on IPs is not always correct, and you want proper regex boundaries
  the moment the corpus gets this big.

---

## The cast

Sixteen actors after dedup (handles that turned out to be one operator are
merged). Every row is a handle, not a name: I'm mapping accounts, not the
people behind them.

| # | Handle | Role | One distinguishing fact |
|---|--------|------|-------------------------|
| 1 | **wyourname** | Wool DRM operator | Only tier-2 DRM (Rust + C2-held AES key). The wall I never got past. |
| 2 | 985Ming (大大鸣) | Script author | The seed. `985Ming/qlk` (292★) started the map. Custom `xor_b85` / `custom_subtract`. |
| 3 | xxwppp | Commercial distributor | `script.345yun.cn` watermark. Sells obfuscated versions of others' plaintext. |
| 4 | KingJin (`KingJin-web`) | Operational farmer | Working Ruishu bypass; concurrent multi-account with remote credential DB. |
| 5 | MCdasheng | iOS IAP + farmer | BoxJs subscription; MITM cookie capture bridges iOS into Qinglong. |
| 6 | Yu9191 | iOS subscription op | 375 files, `onetoken` 6-hour commit pipeline. Largest iOS collection. |
| 7 | Xx1aoy1 | Aggregator | Sources from xxwppp; delete-if-banned operational hygiene visible in commit log. |
| 8 | **smallfawn** | Toolsmith + credential theft | 152 repos, 3,176-star script collection, `decode_action` deobfuscator, plus the JD-login theft from post #3. |
| 9 | qltrojan (`xzxxn777`) | Wool affiliate | Direct wool subscriber since May 2024. Authors the civic-SaaS scripts from [post 4]({% post_url 2026-07-16-forging-the-government-lottery %}). |
| 10 | Aellyt | Wool subscriber | Unicom specialist; also runs a *second* DRM platform (`yphd`, Nuitka-packed) covered in [post 2]({% post_url 2026-06-23-the-great-rust-wall %}). |
| 11 | sembrono | Aggregator | Holds the plaintext original of a script wyourname later encrypted, same source. |
| 12 | aiimix7811 | Wool subscriber | Small footprint (6 scripts), downloads `.so` from `files.doudoudou.top`. |
| 13 | **wd210010** | **CLEAN `(verified)`** | Bilibili daily check-in only; forked `decode_action` but no fraud. Named so the roster isn't a smear. |
| 14 | xiaobaiweinuli (`星霜`) | Hobbyist + tradecraft | Runs a wool fork, publishes the scrub recipe on their blog. |
| 15 | MQapple | Intermediate fork | Between wyourname and xiaobaiweinuli in the wool fork chain. No original content. |
| 16 | leafTheFish | Independent T1 author | 40+ scripts, DeathNote repo. GitHub account now wiped; scripts survive in forks. |

Attribution note: proxy affiliate codes don't imply shared identity.
985Ming uses `ipzan.com?pid=8ghr872u8`, KingJin uses
`gzsk5.com/?invitation=hnking2`. Different codes, different providers.
Handles are real accounts *for the tooling*, but a handle is not a
human. I did not doxx anyone.

---

## Platform scope

Between them the 16 actors target 130+ distinct platforms: music,
video, novels, telecom, banks, FMCG brands, and, the part that made me
worried in
[the civic post]({% post_url 2026-07-16-forging-the-government-lottery %}),
government and civic apps. Beijing 96156 social-services quizzes, a whole pile
of Zhejiang prefecture civic apps sharing tenant SaaS backends, and
`user.youth.cn` (China Youth Daily's reading app, whose withdrawal binary I
reverse-engineered out of the wool `compatible` branch).

---

## What I'd do differently next time

Three things that would have saved me a good chunk of time, if I were
starting this over on a fresh scene.

I spent most of the first day reading scripts, convinced that behaviour would
tell me who wrote what. It won't. It didn't. Scripts in a scene like this get
laundered: someone writes it plaintext, someone else obfuscates and resells it,
an aggregator re-hosts the obfuscated copy under their own name, and by the
time you're squinting at it at 3am you're two hops downstream of whoever actually
wrote it. What genuinely ties the accounts together is the plumbing, the
private helper function name, the specific URL for a device ID JSON, the exact
CDN domain buried in an `execute_code()` call. The behaviour gets copied
everywhere. The private plumbing only moves inside the circle. I should have
grepped for helper names before I read a single line of logic.

I also very nearly missed the scrub story, because I read the current
state of every config file and moved straight on. The `HASL1` finding
wasn't in the current `config.json` at all, it was in a commit from
2024-11-10 that survived exactly one day. A config that goes "credible
value → placeholder → wait, half the credible value just came back" is
quietly telling you where the real backend lives. Scrubbing is louder
than not scrubbing. Read the sequence, not the state.

And the decode_action fork thing, I did find it, just far too late to
work it properly. If I'd walked those forks on day one instead of day
three, I'd have had aini1351's entire target timeline in hand before I
was even done mapping qltrojan. Any tool in a scene that works by "fork
this repo, push your input, GitHub Actions writes the output back" is a
public log of what every one of its users needed processed and when.
Wallet checkers, jsvmp deobfuscators, sign-in frameworks, all of them.
The scene adopts them because they're free CI. Nobody notices the
receipt.

---

## Where it stops

Sixteen actors is what I *mapped*, not everyone in this scene. The engagement
was a weekend that ran long and a few days after to write these posts, and the
pivots happened to converge on a contiguous group after dedup. Extended
profiles out in the decode_action network (Ecalose, Rosylusi, Charles-Hello,
shufflewzc, ACSDSZ) I've noted but not fully worked.

Proxy affiliate codes don't imply shared identity. Cross repo overlap on
obfuscators, keys, or device-ID pools shows **shared source or toolchain**, not
necessarily one operator behind two accounts. I want that line to hold even
when the overlap is tempting.

`wd210010` is `(verified)` clean. If you're reading this and you know
that handle, please don't lump them in with the fraud actors, their
entire footprint is a Bilibili daily check-in and a `decode_action`
fork. That's the whole story.

ACSDSZ committed real credentials; that part is `(verified)` straight
from the repo history. Republishing the strings would be dumb, so I
haven't.

Fork git histories are `(verified)` from `--depth=1` clones plus
unshallow fetches. Commit author emails don't always line up with GitHub
usernames, so where I've matched a fork operator to a specific script
set I'm confident, and where I've matched by fuzzy heuristic, that's
flagged `(inferred)`.

---

## Resources

- [The hub post]({% post_url 2026-06-23-a-weekend-in-the-wool %}): ecosystem overview + glossary.
- [Post 1: the Cython DRM I cracked]({% post_url 2026-06-23-the-wool-drm %}).
- [Post 2: the Rust wall I didn't]({% post_url 2026-06-23-the-great-rust-wall %}).
- [Post 3: smallfawn farming the farmers]({% post_url 2026-06-29-farming-the-farmers %}).
- [Post 4: forging the government's lottery]({% post_url 2026-07-16-forging-the-government-lottery %}).
