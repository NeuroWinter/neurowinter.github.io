---
layout: post
category: Security
title: "The Trade Desk is on your health portal, your bank, and the lottery"
heading: "The Trade Desk is on your health portal, your bank, and the lottery"
category: Security
description: Loaded New Zealand's most visited sites in a real browser and logged every identifier handed to a third party. Two ad brokers with no consumer product turned up on a patient portal, a bank, the national lottery and a city council. Here is what that looks like on the wire, and what IPP 3A has to say about it.
---

## TLDR:

- Two buy-side ad brokers, **The Trade Desk** and **Xandr**, each receive a persistent cross-site identifier from **six of the ten** sensitive New Zealand sites I checked: a patient portal, a bank, the national lottery, a city council and two universities.
- On `managemyhealth.co.nz` the two of them swap identifiers with each other mid page. The cookie match request is in the post.
- Across the whole corpus, **77 of 104 publishers** send at least one persistent identifier to a third party.
- Every one of those requests carries `gdpr=0` and an empty consent string. The ad-tech consent vocabulary has no concept of New Zealand law at all, so no interaction of a NZ reader governs any of it.
- **IPP 3A came into force on 1 May 2026.** It requires an agency collecting your personal information from a source other than you to take reasonable steps to tell you who they are and what they took. As far as I can find, nobody had measured the NZ surface against it.
- `temu.com` runs cookie match pixels on nine major NZ sites. I could not show it links them server side, and I have left that failed escalation in the post.
- **This is not a breach finding.** Every party named here may have a lawful basis I cannot observe from a browser.

---

You think you visited one website. You met 122 companies.

I went looking because of a talk. At BSides Brisbane,
[D8RH8R](https://www.linkedin.com/in/ryan-williams-4068351b8/) took apart SS7
signalling firewalls: seven ways a legal-but-unusual BER encoding makes the
firewall and the network element disagree about what a message says, so the
firewall passes a query it should have blocked. He closed by saying that was all
old tech, and the interesting unexplored surface now is ad tech. He gets the
credit for the direction and none of the blame for what I did with it.

A short primer, because the vocabulary is genuinely awful. When a page loads an
ad slot it does not load an ad. It runs an auction, in the few hundred
milliseconds before you see anything, and every bidder is software. The slots
are called **inventory** ie the different ad locations on the page. A
**supply-side platform** works for the publisher and sells inventory. A
**demand-side platform**, or DSP, works for the advertiser and buys it.

That naming is the worst part of the field, so it is worth stating clearly (or
attempt to): the advertiser is the one *demanding* inventory, so the firm
bidding on the advertiser's behalf is the **demand side** platform and is also
called **buy side**. Same thing. I use buy-side below because it is the clearer
word for what they are: buyers of ad locations. And for an auction to be worth
running, the buyers have to know who they are bidding on. That is what the
identifiers are for. The more info the have the better it is for them. The
advertisers will know they type of person you are the sites you visit your
location etc etc.

I loaded New Zealand's most visited sites in a real browser and recorded every
identifier handed to every third party, with full provenance back to the raw
request. Opening `1news.co.nz` introduces you to 122 distinct companies.
`nzherald`, 121. `stuff`, 103. Most of them you have never heard of, and none of
them you chose.

One note on those counts before you compare them to anyone else's. I ran every
site twice, once on a fresh profile and once on a warmed one carrying history,
and the fresh profile produced about 26% more identifier bearing requests, which
will be turned into its own post eventually.


I expect a news site to load a hundred advertisers' worth of code. That is what
a free news site is, and it is bad enough. The sites below are the ones that
surprised me.

## The same two ad brokers are on the sites that should know better

**The Trade Desk** and **Xandr** are buy-side platforms. Their entire business
is bidding on ad slots for advertisers. They have no product for you, no account
you hold, no reason to know who you are. And each of them receives a persistent
cross-site identifier from six of the ten sensitive New Zealand sites I checked:

| Site                   | What it is       | Buy-side firm receiving a persistent ID |
| ---------------------- | ---------------- | --------------------------------------- |
| `managemyhealth.co.nz` | patient portal   | The Trade Desk, Xandr                   |
| `mylotto.co.nz`        | national lottery | The Trade Desk, Xandr                   |
| `westpac.co.nz`        | bank             | The Trade Desk, Xandr                   |
| `ccc.govt.nz`          | city council     | The Trade Desk, Xandr                   |
| `waikato.ac.nz`        | university       | The Trade Desk, Xandr                   |
| `auckland.ac.nz`       | university       | The Trade Desk, Xandr                   |

An identifier on its own is just a random string assigned to you. It starts
mattering when the same company receives the string *and* the page it arrived
on, because then it can write a row: *this identifier was observed visiting a
patient-portal domain*. On `managemyhealth`, The Trade Desk got exactly that
pairing. These are firms that see you across most of the web, so the visit
doesn't sit alone. That is what the design is for: on their side, one value
arriving from a patient portal and again from `mylotto` is a single profile
carrying both, which is the kind of context that supports a health-related
inference.

And the two brokers don't just receive the identifier: they reconcile it with
each other. Captured mid-handshake on the health portal, The Trade Desk hands its
ID to Xandr and asks for Xandr's in return:

```
https://match.adsrvr.org/track/cmf/appnexus?ttd=1&anid=$UID&ttd_tdid=b0171955-c02d-42f1-a215-b2274ee35e96
```

`match.adsrvr.org` is The Trade Desk; `appnexus` is Xandr's former name; `cmf` is
cookie-match-feed. The identifier is `ttd_tdid`: The Trade Desk's *cross-site*
identifier, the one built to follow you everywhere. That word is doing the work.
An auction-scoped token is a receipt for one ad sale and is meaningless an hour
later. A cross-site identifier is a name, and it is built to still mean you
tomorrow, on a different site.

I should be honest about the limits here, because they matter. I visited public
pages with no account, and a crawler has no diagnosis to leak and no lottery
ticket. That doesn't defuse it: the sensitive fact isn't the page, it's the
**domain**. And on my cold profile the `ttd_tdid` was a fresh value on each site,
so I *cannot* show the same person linked across the health portal and the bank
from this data. A fresh browser is the one case where that identifier *doesn't*
persist. For a real visitor carrying a Trade Desk cookie, a cross-site identifier
is exactly what it is designed to be. What happens behind a login, where a real
patient's activity lives, is worse and is where a browser can't follow.

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
make it hold up with my test bench. The `adx_uid` is a different value on every
site (a per-match token, not a stable ID), and the only cookie Temu sets is
Cloudflare's bot-detection token, non-identifying by design, on fresh and warmed
profiles alike. So it stays here: **Temu runs the matching plumbing, consent
empty, on nine major NZ sites; whether it links that server-side, a browser can't
see.** I'm leaving the failed escalation in because the finding is more solid for
it. However, I think if the test bench had browsed to more sites, maybe even
signed into to temu it might have used that cookie.

## The law it runs into

On consent: these sends carry `gdpr=0` (an assertion that GDPR does not apply,
which for a New Zealander is correct) and an empty consent string. There is no
New Zealand signal in the request at all, because the ad-tech consent vocabulary
has no concept of New Zealand law. A NZ reader is described to the market in the
language of a regime that doesn't cover them, and no interaction of theirs governs
any of it. That doesn't prove nobody was told anything. It shows that if a New
Zealand notice governs this collection, the auction transaction carries no sign
of it.

This is where New Zealand's **IPP 3A** comes in, and it's worth being precise
about which principle does what. IPP 2 is the one that says collect personal
information from the person concerned, unless an exception applies. IPP 3A is
new and it points the other way: it came into force on 1 May 2026, and it says
that if you collect someone's personal information from a source other than
them, you have to take reasonable steps to make them aware of it. What you have
to tell them is spelled out: that you collected it, why, who else gets it, your
name and address, and how they can access and correct it.

Programmatic ad tech looks like indirect collection by design. The request leaves
your browser, but nothing in it is something you handed the broker: the
publisher's ad stack builds it and fires it. Whether that counts as indirect
collection for the purposes of IPP 3A hasn't been tested. If it does, the OPC's
guidance puts the duty on the indirect collector, and says that where there's a
chain of disclosure and collection, every agency in that chain carries its own
obligation. The Trade Desk handing its ID to Xandr and taking Xandr's back is a
chain. Neither of them has ever shown itself to me.

One line in the OPC's guidance is hard to read any other way. There's an
exception for collections that wouldn't prejudice the person's interests, and
the guidance gives an example of when it does *not* apply: collecting data to
build profiles of individuals for targeted advertising.

Across the whole corpus, **77 of 104 publishers** send at least one persistent
identifier to a third party. As far as I can find, nobody had measured the NZ
surface against it.

## Limits

Not a breach finding. I have no view of notice given elsewhere, processor
contracts, prior authorisation, or IPP 3A's exceptions. Every party may have a
lawful basis I can't observe. Two defences in particular are open and I can't
close either from a browser: whether a pseudonymous ad ID is personal
information about an identifiable individual at all, and whether notification is
reasonably practicable for an agency that holds no contact details for you.
What I'm reporting is a mechanism and its reach: buy side ad brokers collecting
persistent identifiers from New Zealand's health, banking, government and
education sites, measured against the principle that applies. Someone with more
authority than a browser and a weekend should look at the rest.

Every number in this post rederives from the captured data. Each observation is
stored content addressed with its raw request, so `77 of 104`, the buy side table,
the `−26%`, the per-visit `ttd_tdid`, and the `gdpr=0` consent state are all
queries against the same evidence, not figures I eyeballed. If you're at the OPC,
or you run one of the sites named here and want the raw captures for your own
domain, get in touch.

