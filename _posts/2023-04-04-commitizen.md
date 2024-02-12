---
layout: post
category: git
title: "Enhance Git Commit Quality with Commitizen: A Guide for Developers"
heading: "How to improve your Git commits with Commitizen"
description: "This Blog post discusses the benefits of using Commitizen a CLI tool that helps in the writing of meaningful Git commit messages and follows the Conventional Commits specification."
---
# Summary

Commitizen is a CLI tool that can be used to help communicate changes made in
commits to both future you and other team members. The goal of this is to stop
all those commit messages of "WIP" or "fixing stuff".

There have been countless times when I know that a change in file X has causes
this issue, but I have no way of knowing which commit did it. So I end up
spending far too long looking through all the commits to find the right one.

Commitizen also aids a team in using [Semantic Versioning](https://semver.org/)
as it helps you automatically up version numbers based on changes.

# Why

Why do we need yet another tool in our workflow, don't we have enough? 

Git commit messages are a very under-utilized tool in the programming workflow,
a lot of us will make a tonne of changes to all sorts of files, and then commit
them all under a single commit. This leads to very difficult rollbacks, as you
need to roll back all of them. This practice also leads to unhelpful commit
messages, as the larger a change is, the harder it is to succinctly describe
what is going on. Leading to terrible messages like "WIP". Not only do these
commit messages provide 0 value and seem useless, they are also a hindrance.
When it comes to Code Review, you need to be able to explain your changes
succinctly to the reviewer, other than sitting down and having a chat with the
reviewer this can be difficult.  This is where good commit messages come in and
Conventional Commits.

Conventional commits is a super easy specification to follow, it is basically a
set of rules that help you to create meaningful commit messages. You can read
more about it, and the full specification,
[here](https://www.conventionalcommits.org/en/v1.0.0/#summary).

# How

Now while the above are all reasons that you should write better commits, we
often say that we will follow these practices, but end up falling back into our
old ways. We need a way to ensure that we follow what we have defined as best
practice. Here is where Commitizen comes in! 

One way to change process is to make it as easy as possible. Commitizen is a
super easy to use tool that will help you right good commit messages. E.g.:
```bash
❯ neurowinter.github.io (fix-working-in-aws-blog) ✘ cz c
? Select the type of change you are committing refactor: A code change that neither fixes a bug nor adds a feature
? What is the scope of this change? (class or file name): (press [enter] to skip)
 _posts/2023-01-09-removing-aws-blog.md
? Write a short and imperative summary of the code changes: (lower case and no period)
 change wording for paragraph
? Provide additional contextual information about the code changes: (press [enter] to skip)
 
? Is this a BREAKING CHANGE? Correlates with MAJOR in SemVer No
? Footer. Information about Breaking Changes and reference issues that this commit closes: (press [enter] to skip)
```

Once you have added the code you want to commit (remember you should keep your
commits as small as possible) you can then run `cz c` to create a nice git log
entry to allow your fellow contributors to better understand your changes.
Having to write something about what has changed forces you to keep your
commits small, as when you have committed a lot of changes, you will struggle
to describe the exact changes. Continue this process for some time, and it will
help you not only keep your git log looking nice, but it will also help you
keep your commits small.

Now that you have made some commits, you can view your git log in all of its glory:
```bash
❯ neurowinter.github.io (commentizen-blog-post) ✘ git log | head -n 50
commit 5f8aeca4cafd413aa2e906f704a791308fbd796c
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Wed Jan 18 08:19:14 2023 +1300

    refactor(_posts/2023-01-09-removing-aws-blog.md): change wording for paragraph (#35)

commit 4abd7843baa6c93eed2fe8f516b544220e226906
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Mon Jan 9 08:36:30 2023 +1300

    fix(_posts/2023-01-09-removing-aws-blog.md): fixed link to NoReturn post (#34)

commit 50aee760139bf92020cd66fae353bdabe4637db7
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Mon Jan 9 08:31:06 2023 +1300

    Add link in aws blog (#33)
    
    * fix(_posts/2023-01-09-removing-aws-blog.md): added link to my python no return post
    
    * fix(_posts/2023-01-09-removing-aws-blog.md): added links to both .dev and .com sites

commit e7a79025a151b9aab3b2539ea6457fc0b15a9f71
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Mon Jan 9 08:18:03 2023 +1300

    fix(_posts/2023-01-09-removing-aws-blog.md): fixed wording in description (#32)

commit 50e04dd96a117abfa8a9e8977b0c5f35664a3507
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Sat Jan 7 20:15:35 2023 +1300

    feat(_posts/2023-01-09-removing-aws-blog.md): added post about why i stopped hosting at aws (#31)

commit 5fc12519cf0f139013c368515c53f30cd0c8a19b
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Fri Jan 6 21:56:47 2023 +1300

    build(tf/main.tf): updated to tf v1.3.6 (#30)

commit b918485ead4fea41c7e4e1db13ddaaf6f75e8105
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Fri Jan 6 17:05:46 2023 +1300

    feat(_config.yml): added linkedin link to socials for seo (#29)

[...]

```
Now that does look a lot nicer than 
```bash
commit 6d08107ccd08f6b85140f8e77d9ea9a2bf6f5ef6
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Fri Oct 2 09:27:58 2020 +1300

    Show description on home page

commit 63d8f7740971e84e3d3522e7ef43dd25de3c5ceb
Author: NeuroWinter <devatneurowinterdotcom>
Date:   Fri Oct 2 09:25:59 2020 +1300

    Add basic config settings
```

We haven't even gotten into the awesome version bumping features, custom templates and a range of other amazing customizations you can do. That will be for another day, I hope that this very basic overview has piqued your interest in Commitizen, and hope that you will start using it in your future projects, and if you do, be sure to check out the [GitHubActions](https://commitizen-tools.github.io/commitizen/tutorials/github_actions/) or [GitLab CI](https://commitizen-tools.github.io/commitizen/tutorials/gitlab_ci/) integrations.

So to finalize, here are a few of the benefits of using Commentizen:
* Helps keep your commits small.
* Helps really describe what is going on in your commits.
* The git log is now a valuable resource.
* Aids in reverting changes (since you know what each commit does and is kept small).
* Helps with Semantic Versioning.
