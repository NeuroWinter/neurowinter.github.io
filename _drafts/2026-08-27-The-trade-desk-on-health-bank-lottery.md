---
title: "The Trade Desk is on your health portal, your bank, and the lottery"
heading: "The Trade Desk is on your health portal, your bank, and the lottery"
category: Security
description: Six of ten sensitive New Zealand sites hand a persistent cross-site identifier to two buy-side ad brokers, measured against IPP 3A.
---

You think you visited one website. You met 122 companies.

I went looking because of a talk. At BSides Brisbane,
[D8RH8R](https://www.linkedin.com/in/ryan-williams-4068351b8/) took apart SS7
signalling firewalls: seven ways a legal-but-unusual BER encoding makes the
firewall and the network element disagree about what a message says, so the
firewall fails to read the field it is supposed to be policing and passes the
query through. He closed by saying that was all old tech, and the interesting
unexplored surface now is ad tech. He gets the credit for the direction and none
of the blame for what I did with it.

I loaded New Zealand's most-visited sites in a real browser and recorded every
identifier handed to every third party, with full provenance back to the raw
request. Opening `1news.co.nz` introduces you to 122 distinct companies.
`nzherald`, 121. `stuff`, 103. Most of them you have never heard of, and none of
them you chose.

That is the ordinary web and it is bad enough. This post is about the part that
isn't ordinary.

## The same two ad brokers are on the sites that should know better

**The Trade Desk** and **Xandr** are demand-side platforms. Their entire business
is buying advertising inventory. They have no product for you, no account you
hold, no reason to know who you are. And each of them receives a persistent
cross-site identifier from six of the ten sensitive New Zealand sites I checked:

| Site                    | What it is        | Buy-side firm receiving a persistent ID |
| ----------------------- | ----------------- | --------------------------------------- |
| `managemyhealth.co.nz`  | patient portal    | The Trade Desk, Xandr                   |
| `mylotto.co.nz`         | national lottery  | The Trade Desk, Xandr                   |
| `westpac.co.nz`         | bank              | The Trade Desk, Xandr                   |
| `ccc.govt.nz`           | city council      | The Trade Desk, Xandr                   |
| `waikato.ac.nz`         | university        | The Trade Desk, Xandr                   |
| `auckland.ac.nz`        | university        | The Trade Desk, Xandr                   |

An identifier on its own is just a name. It matters when the same company
receives the name *and* the page it arrived on, because then it can write a row:
*this identifier belongs to someone on a health portal.* On `managemyhealth`, The
Trade Desk got exactly that pairing. These are firms that see you across most of
the web, so the visit doesn't sit alone. *Health-portal user* becomes an
attribute on the same profile built from everywhere else you go.

And the two brokers don't just receive the identifier: they reconcile it with
each other. Captured mid-handshake on the health portal, The Trade Desk hands its
ID to Xandr and asks for Xandr's in return:

```
https://match.adsrvr.org/track/cmf/appnexus?ttd=1&anid=$UID&ttd_tdid=b0171955-c02d-42f1-a215-b2274ee35e96
```

`match.adsrvr.org` is The Trade Desk; `appnexus` is Xandr's former name; `cmf` is
cookie-match-feed. The identifier is `ttd_tdid`: The Trade Desk's *cross-site*
identifier, the one built to follow you everywhere, not an auction-scoped token.

Be precise about the limits, because they matter. I visited public pages with no
account, and a crawler has no diagnosis and no bet to leak. That doesn't defuse
it: the sensitive fact isn't the page, it's the **domain**. And on my cold
profile the `ttd_tdid` was a fresh value on each site, so I *cannot* show the
same person linked across the health portal and the bank from this data. But
that is a floor, not a ceiling: a fresh browser is the one case where that
identifier *doesn't* persist. For a real visitor carrying a Trade Desk cookie, a
cross-site identifier is exactly what it is designed to be. What happens behind
a login, where a real patient's activity lives, is worse and is where a browser
can't follow.

On consent: these sends carry `gdpr=0` (an assertion that GDPR does not apply,
which for a New Zealander is correct) and an empty consent string. There is no
New Zealand signal in the request at all, because the ad-tech consent vocabulary
has no concept of New Zealand law. A NZ reader is described to the market in the
language of a regime that doesn't cover them, and no interaction of theirs governs
any of it.

This is what New Zealand's **IPP 3A** governs: collect personal information
directly from the person, unless an exception applies. Programmatic ad-tech never
collects directly: a persistent ID reaches these brokers *from the page*, not
from *you*, and they never show themselves. Across the whole corpus, **77 of 104
publishers** send at least one persistent identifier to a third party. As far as I
can find, nobody had measured the NZ surface against the NZ law before.

## The worked example: Temu is running the matching hub

The most legible single case is one you wouldn't expect. `temu.com` (the Chinese
shopping app) receives persistent identifiers on nine major NZ sites. The full
request URL is the whole story:

```
https://www.temu.com/api/adx/cm/pixel-opera?adx_uid=75c07d23...&gdpr=&gdpr_consent=&us_privacy=&redir=https%3A%2F%2Ft.oa.opera.com%2Fsync%3Fvendor%3D60369...
```

`cm` is cookie-match: the mechanism two ad companies use to agree that their
separate IDs for you are the same person. These are Temu's own match pixels, one
per partner, receiving IDs from Google AdX, Smaato and Outbrain and redirecting
onward to sync them. Consent fields present and blank.

The sensational version is "Temu tracks one reader across nine sites." I couldn't
make it stand up. The `adx_uid` is a different value on every site (a per-match
token, not a stable ID), and the only cookie Temu sets is Cloudflare's
bot-detection token, non-identifying by design, on fresh and warmed profiles
alike. So it stays here: **Temu runs the matching plumbing, consent empty, on nine
major NZ sites; whether it links that server-side, a browser can't see.** I'm
leaving the failed escalation in because the finding is more solid for it.

## Why you should trust the numbers: the cold browser lies

Almost every measurement of web tracking runs on a **fresh** browser (clean, no
history) because it's reproducible. Nobody browses like that. So I ran every site
twice: once fresh, once from a **warmed** profile carrying history, the way a real
browser is.

I expected the warmed browser to leak more. Opposite. Same 95 publishers, matched
across both arms, counting requests on pages that appeared in both runs:

| Metric                      |  Fresh | Warmed | Change |
| --------------------------- | -----: | -----: | -----: |
| Identifier-bearing requests | 27,163 | 19,999 | **−26%** |
| Distinct recipients         |    714 |    616 |   −14% |
| Page-URL disclosures        | 14,726 | 14,647 |  −0.5% |

That last row is the control, and it's the one that matters. *What you're reading*
went out at essentially the same rate on both arms, while identifier traffic fell
a quarter. The warmed browser loaded the same pages and reported the same
content; it isn't that it did less. It did the same amount of everything except
identity.

The cold browser has no cookie-sync matches yet, so it runs every handshake from
scratch on every load: over-counting exactly the sync traffic a real browser
already completed. I ran a second night with the arms reversed to rule out
time-of-day; the identifier gap reproduced to within a point (−25.7% one night,
−26.4% the other). Counted a different way (every identifier-bearing field in the
whole run rather than just matched homepages), the same asymmetry holds: identity
down ~26%, page context down a fraction of that. **A fresh profile over-counts
sync traffic and under-counts established identity. That is what most privacy
studies run on.**

## Limits

Browser measurement stops at the browser. I see the cookie-match handshake, not
the server-side table it may populate. Cookie-syncing is built to link somewhere
I can't look. So for every recipient here, Temu included, I show the plumbing
exists and can't show what flows through it once it leaves the browser.

One synthetic reader, no accounts, one country, two nights. The replication kills
the *time-of-day* confound; it doesn't prove a logged-in user or another country
looks the same. Where I found "no persistent identifier," that's a floor: a
first-time visitor with no relationship is where linkage is least likely; a
logged-in user is plausibly worse and invisible to me.

Not a breach finding. I have no view of notice given elsewhere, processor
contracts, prior authorisation, or IPP 3A's exceptions. Every party may have a
lawful basis I can't observe. What I'm reporting is a mechanism and its reach:
buy-side ad brokers collecting persistent identifiers from New Zealand's health,
banking, government and education sites, measured against the principle that
applies. Someone with more authority than a browser and a weekend should look at
the rest.

Every number in this post re-derives from the captured data. Each observation is
stored content-addressed with its raw request, so `77 of 104`, the buy-side table,
the `−26%`, the per-visit `ttd_tdid`, and the `gdpr=0` consent state are all
queries against the same evidence, not figures I eyeballed. If you're at the OPC,
or you run one of the sites named here and want the raw captures for your own
domain, get in touch.
