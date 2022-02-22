---
layout: post
category: python
title: Stop being asked for your ssh key password
description: How to set up a password protected ssh key and automatically add it to you ssh-agent.
---

### Introduction

I have been using ssh keys to access my GitHub and GitLab for a while now, but
one thing that has always annoyed me was how if I have a password on my ssh key
I need to re-enter my password each time I use it.

Now, I hear you ask why I would want to have a password on my ssh keys. Well, I
can be a bit paranoid sometimes. The reason is that if someone somehow gains
access to my computer, they would have access to everything if I don't have a
password. Adding an ssh key password is just another stop-gap between being
completely owned and not.

### How to generate a secure ssh key.

I am sure you have all seen this [Generating a new SSH
key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent),
so I won't go over it here. The only difference is that we will be entering a
passphrase when prompted, as opposed to leaving it blank.


Now that we have a passphrase protected ssh key, we can add it to our GitHub
account following these instructions: [Adding a new SSH key to your GitHub
account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)

We want to add our newly created ssh key into our ssh config file.  I like to
separate my personal GitHub accounts, and my work GitHub accounts, so I have
added the following into my `~/.ssh/config` file:

```
Host gh_personal
    HostName github.com
    User git
    AddKeysToAgent yes
    IdentityFile ~/.ssh/personal-github
```

Once you have this set up you can test that it all works by cloning a repo this
should prompt you for a password, but then after that you should not be asked
for the password again:

```
git clone git@github.com:torvalds/linux.git
```

The main thing that was added was the `AddKeysToAgent yes` line. What this does
it that it will add the keys to the ssh-agent that is currently running,
meaning that you will not need to enter your password again and again, more
info can be found here: https://man.openbsd.org/ssh_config.5#AddKeysToAgent

