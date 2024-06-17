---
layout: post
category: Books
title: "The Phoenix Project: Fiction that is close to reality"
heading: "The Phoenix Project: Fiction that is close to reality"
description: A fictional story that resonates mirrors the reality of many organizations.
---

[The Phoenix Project](https://itrevolution.com/product/the-phoenix-project/) is a book centred around Bill, who is thrust into the role of VP of IT in a traditional company known for blaming IT for all problems. The story follows Bill as he is mentored by Eric, a board member, and not only fixes the current state of IT but also creates a new course of action that improves everyone's lives. At the core of Eric's teachings are "The Three Ways," essential for a successful business. While this concept is central, I found other themes more relatable, and the Three Ways provide a framework to address these issues.

I found the book incredibly relatable for many reasons. There have been countless times when I've seen a manager arbitrarily set a release date without consulting the dev team or anyone else. This situation mirrors what Bill experienced with Chris, the head of Dev, and Sarah, the SVP of Retail Operations.

The book covers many topics in its 35 chapters, and I will try to distil what resonated most with me from it:

- Transfer learning
- The Three Ways
- Us vs. Them
- Human centric design
- Communication is Key


## Transfer learning

Throughout the book, characters frequently draw parallels between their work and other industries. Eric, a key advocate of this approach, applies manufacturing industry lessons to IT, which is central to his 'Three Ways' philosophy.

There are a range of different learnings from other industries, such as  the ["Theory of Constraints"](https://en.wikipedia.org/wiki/Theory_of_constraints), [“Kanban”](https://mag.toyota.co.uk/kanban-toyota-production-system/), [“Lean”](https://en.wikipedia.org/wiki/Lean_manufacturing) and "Standardisation of work and automation" which were all mentioned at least at a high level in the book. These concepts were all taken from manufacturing. There were also mentions of the [ "Critical Path Method"](https://en.wikipedia.org/wiki/Critical_path_method) which was first introduced in construction, and Failure Mode and Effects Analysis which was taken from healthcare. I might go into each of these in more detail in another blog post, but to me, at the heart of this is: why solve problems that have already been fixed in other industries? You don't need to reinvent the wheel. More often than not, your issue is not unique. We have hundreds of years of experience in various other environments; learn how they solved the issues and see if you can apply the same solutions. 


## The Three Ways

There are countless blog posts and articles that detail the Three Ways, and for a more in depth look at them, I would highly recommend reading Natalia Rossingol's article here: [The Phoenix Project: 10 Minute Summary](https://www.runn.io/blog/the-phoenix-project-summary). But I will outline the basic concept of these here for reference.

### The First Way

At the core of the First Way is the ability to create an overall effective machine, and to do that, you must have a holistic view of the pipeline of work. To achieve this, Bill utilized some transfer learning from manufacturing (as mentioned above)—now one of the many tools in the agile practitioner's belt.

### The Second Way

I believe the essence of the Second Way is "Release early, Release Often" or RERO for short. Tighten the feedback loop, and ensure that what you are working on will solve the problem that needs to be solved. What good is a solution to a problem a customer is no longer facing?

### The Third Way

A constant tension toward improvement is vital for a good workplace environment and culture, and also great for business. Tension toward a better way of working is very important. Time spent improving your system is one of the best ways you can spend your time, as if you are not making things better, then you are almost always making things worse.  This is what I think the Third Way is all about, constant improvement. This is also a topic that is talked about a lot in a range of tech books and is one of the 12 pillars of the Toyota Production System: [Kaizen](https://mag.toyota.co.uk/kaizen-toyota-production-system/)


## Us vs. Them

This theme is common not only in the book but also in my professional experience. I have seen engineers outright disagree with good ideas from management simply because they are from management. I have also seen engineers put up roadblocks with the intention of protecting themselves from management, which in the end, stifles any experimentation, fast feature development, and communication flow between the two core business teams. To me, this is a common occurrence in a toxic workplace, and it originates both from management and from the engineering team. We should not be seen as two teams battling against each other, but as one team, creating a better business.

There is a persistent tension between management and technical teams, as well as within different tech departments. In many organisations with multiple teams, it is common to pass a support ticket to another tech team, and blame them for the issue, rather than addressing it. Tickets would get passed from sysops to networking, to project, over to security, then back to networking and start the cycle all over again with sysops. All the while, the customer has an issue. This scenario is prevalent in The Phoenix Project, with infighting between Dev and IT, and there is the common theme of Sarah, and her mission to break up the company. However, once the teams started seeing the core metrics and goals for the company as a whole and identifying the most important aspects of IT for each business unit, they began working together rather than against each other.

Gaining insight into the impact of their work also helped immensely when it comes to the IT/Dev teams' view of the other business units. One of the things that helped the most, however, was to stop VPs and other higher-ups from bypassing the process and getting their work in as the highest priority. As stated several times in the book, the VPs, and management would have their favourite engineer whom they would often call personally to get something done. Not only did this mean that the change was not properly recorded, but it also meant that the engineer's entire day and priority list were affected, they were context switching, and trying to get both jobs done as fast as possible. To me, at least, this breeds contempt. Bill had multiple attempts at trying to fix this, and I am not sure that they fully explained the final solution to it in real terms, but they did fix it somehow.


## Human Centric Design

Another core principle that resonated with me throughout the book is the human nature of all that we do in the tech industry. All of our users are humans, from our internal teams to our external customers, and we need to have this in our minds when we are designing things, and when we are working on our software. From a business point of view, this really came to light when the team went around to all the business owners to ask what really mattered to them. This was all kicked off by John when he organized a meeting with Dick to find out the CFO's goals and measures of success. This simple act of finding out what matters to people made the tech team realize just how much they can make their coworkers' lives miserable if they mess things up. For example, Ron (VP of Manufacturing Sales) and while this might seem obvious, knowing just how badly it messes up the sales team's day is important. We as engineers are here to make sure that everyone can do their job as quickly and effectively as possible, and we don't want to make their lives any more miserable.

I have fallen into this problem myself multiple times. I can get caught up in the technicalities of things, focusing only on the interesting problem and novel ways to solve it, but at the end of the day, the thing that matters the most is not that fancy idea, but ensuring that the human on the other end of the feature is happy. What we work on should not negatively impact our user. I really think finding out what a bad day looks like for people is an amazing tool that lets you gain a deeper insight into what you do and how your job is important. It can also fill you with a great deal of pride when you improve others' working lives.


## Communication is Key

The book highlights several critical incidents rooted in poor communication. For instance, in Chapter 3, a major payroll outage forces the team to work late into the night. Unbeknownst to them, changes had been made to a timekeeping system the day before. This lack of communication led to wasted hours chasing false leads, causing further issues. Had the changes been properly communicated, many problems could have been avoided.

The book also has a running theme of broken trust between the business and the IT department. At the root of this were the points I have discussed earlier in this post. One thing that comes out of this broken trust was an onslaught of political issues as well. Sarah was one of the main proponents of these issues, and I think a lot of people would do the same. Sarah was an opportunist; she saw that there was a sector of the business that was causing a lot of grief. So she aligned herself with anything but what she saw as the losing team, working on removing the underperforming team from the company. I think she believed she was doing the right thing for the company, and if it wasn't for Eric and Bill, it might have been the best thing for the company. 


## Closing Notes

Overall, I found this book incredibly relatable. It distilled many core experiences in working in a toxic workplace, especially one where there is no ownership and no feeling of value. These workplaces often don't last too long before the business fails or something big happens to fix the culture. In this case, I am glad that Bill was able to turn the sinking ship around. As I stated in the transfer learning section, the issues you are facing are not normally unique. Read this book and learn how someone else has solved similar issues and apply them to your situation. While this book does not provide a concrete process or "action items," the philosophy behind the book is the important lesson here.
