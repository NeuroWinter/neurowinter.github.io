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

A short primer, because the vocabulary is genuinely awful. When a page loads an
ad slot it does not load an ad. It runs an auction, in the few hundred
milliseconds before you see anything, and every bidder is software. The slots
are called **inventory** ie the different ad locations on the page. A **supply-side platform** works for the publisher and
sells inventory. A **demand-side platform**, or DSP, works for the advertiser
and buys it.

That naming is the worst part of the field, so it is worth stating clearly (or attempt to): the
advertiser is the one *demanding* inventory, so the firm bidding on the
advertiser's behalf is the **demand side** platform and is also called
**buy side**. Same thing. I use buy-side below because it is the clearer word
for what they are: buyers of ad locations. And for an auction to be worth running, the buyers
have to know who they are bidding on. That is what the identifiers are for. The more info the have the better it is for them. The advertisers will know they type of person you are the sites you visit your location etc etc. 

I loaded New Zealand's most visited sites in a real browser and recorded every
identifier handed to every third party, with full provenance back to the raw
request. Opening `1news.co.nz` introduces you to 122 distinct companies.
`nzherald`, 121. `stuff`, 103. Most of them you have never heard of, and none of
them you chose.

I expect a news site to load a hundred advertisers' worth of code. That is what
a free news site is, and it is bad enough. The sites below are the ones that surprised me.

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
patient-portal domain* On `managemyhealth`, The Trade Desk got exactly that pairing.
These are firms that see you across most of the web, so the visit doesn't sit
alone. A visit to a patient-portal domain becomes context that can be attached 
to the profile, potentially supporting a health-related inference on the same profile 
built from everywhere else you go. That is what the design is for: on their side, one value
arriving from a patient portal and again from `mylotto` is a single profile
carrying both facts.

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
from this data. A fresh browser is the one
case where that identifier *doesn't* persist. For a real visitor carrying a Trade
Desk cookie, a cross-site identifier is exactly what it is designed to be. What
happens behind a login, where a real patient's activity lives, is worse and is
where a browser can't follow.

On consent: these sends carry `gdpr=0` (an assertion that GDPR does not apply,
which for a New Zealander is correct) and an empty consent string. There is no
New Zealand signal in the request at all, because the ad-tech consent vocabulary
has no concept of New Zealand law. A NZ reader is described to the market in the
language of a regime that doesn't cover them, and no interaction of theirs governs
any of it.

This is where New Zealand's **IPP 3A** comes in, and it's worth being precise
about which principle does what. IPP 2 is the one that says collect personal
information from the person concerned, unless an exception applies. IPP 3A is
new and it points the other way: it came into force on 1 May 2026, and it says
that if you collect someone's personal information from a source other than
them, you have to take reasonable steps to make them aware of it. What you have
to tell them is spelled out: that you collected it, why, who else gets it, your
name and address, and how they can access and correct it.

Programmatic ad tech is indirect collection by construction. A persistent ID
reaches these brokers *from the page*, not from *you*. The OPC's guidance puts
the duty on the indirect collector, and says that where there's a chain of
disclosure and collection, every agency in that chain carries its own
obligation. The Trade Desk handing its ID to Xandr and taking Xandr's back is a
chain. Neither of them has ever shown itself to me.

One line in the OPC's guidance is hard to read any other way. There's an
exception for collections that wouldn't prejudice the person's interests, and
the guidance gives an example of when it does *not* apply: collecting data to
build profiles of individuals for targeted advertising.

Across the whole corpus, **77 of 104 publishers** send at least one persistent
identifier to a third party. IPP 3A only came into force on 1 May 2026. As
far as I can find, nobody had measured the NZ surface against it.

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
make it hold up with my test bench. The `adx_uid` is a different value on every site (a per-match
token, not a stable ID), and the only cookie Temu sets is Cloudflare's
bot-detection token, non-identifying by design, on fresh and warmed profiles
alike. So it stays here: **Temu runs the matching plumbing, consent empty, on nine
major NZ sites; whether it links that server-side, a browser can't see.** I'm
leaving the failed escalation in because the finding is more solid for it. However, I think if the test bench had browsed to more sites, maybe even signed into to temu it might have used that cookie. 

## Why you should trust the numbers: the cold browser lies

Almost every measurement of web tracking runs on a **fresh** browser (clean, no
history, no past sites logged into etc) because it's reproducible. But nobody browses like that. So I ran every site
twice: once fresh, once from a **warmed** profile carrying history, the way a real
browser is. However this was all just generated and not from "real" browsing. 

I expected the warmed browser to leak more. But nope it was the opposite. Same 95 publishers, matched
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

The cold browser has no cookie sync matches yet, so it runs every handshake from
scratch on every load: over counting exactly the sync traffic a real browser
already completed. I ran a second night with the arms reversed to rule out
time of day; the identifier gap reproduced to within one point (−25.7% one night,
−26.4% the other). Counted a different way (every identifier bearing field in the
whole run rather than just matched homepages), the same asymmetry holds: identity
down ~26%, page context down a fraction of that. **A fresh profile over counts
sync traffic and under counts established identity.**

I am not the first to notice the mechanism and it would be dishonest to pretend
otherwise. Englehardt and Narayanan flagged it in the
[1-million-site measurement](https://webtransparency.cs.princeton.edu/webcensus/)
back in 2016: stateful and stateless crawls diverge, and cookie syncing is
specifically one of the measurements where that divergence is material rather
than cosmetic. They dealt with it by seeding the profile with prior browsing.
OpenWPM's default has been stateful ever since, and
[stateless is the thing you opt into](https://github.com/openwpm/OpenWPM/blob/master/docs/Configuration.md#stateful-vs-stateless-crawls).

So the correction is a decade old. What I haven't found is anyone putting a
number on it. Applied work still runs stateless routinely, because a clean
profile per page is cheaper and trivially reproducible:
[this measurement of Indian news media](https://arxiv.org/pdf/2103.04442) ran
five stateless crawls across 1,387 URLs, and
[this one on hyper partisan sites](https://arxiv.org/pdf/2002.00934) states
plainly that its persona crawls are stateless. Neither is doing anything wrong.
But if you count identifier traffic that way, on a corpus like this one, the
figure is about a quarter high, and now there is at least one measurement of how
much.

## Limits

Browser measurement stops at the browser. I see the cookie match handshake, not
the server side table it may populate, and cookie syncing is built to link
somewhere I can't look. So for every recipient here, Temu included, I show the
plumbing exists and can't show what flows through it.

One synthetic reader, no accounts, one country, two nights. The replication kills
the *time of day* confound; it doesn't prove a logged in user or another country
looks the same.

Not a breach finding. I have no view of notice given elsewhere, processor
contracts, prior authorisation, or IPP 3A's exceptions. Every party may have a
lawful basis I can't observe. Two defences in particular are open and I can't
close either from a browser: whether a pseudonymous ad ID is personal
information about an identifiable individual at all, and whether notification is
reasonably practicable for an agency that holds no contact details for you.
What I'm reporting is a mechanism and its reach:
buy side ad brokers collecting persistent identifiers from New Zealand's health,
banking, government and education sites, measured against the principle that
applies. Someone with more authority than a browser and a weekend should look at
the rest.

Every number in this post rederives from the captured data. Each observation is
stored content addressed with its raw request, so `77 of 104`, the buy side table,
the `−26%`, the per-visit `ttd_tdid`, and the `gdpr=0` consent state are all
queries against the same evidence, not figures I eyeballed. If you're at the OPC,
or you run one of the sites named here and want the raw captures for your own
domain, get in touch.
