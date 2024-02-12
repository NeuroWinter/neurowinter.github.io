---
layout: post
category: git
title: "Setting Up GitHub SSH Keys for Specific Repositories: A Step-by-Step Guide"
heading: How to set GitHub SSH key for a particular repo
description: How to set a particular SSH key for a repo when using multiple GitHub accounts on a single machine.
---
# Summary

I often have multiple GitHub accounts on a single computer, for a range of different reasons; personal account, side project accounts, work accounts etc. and I often run into the issue of having access denied when trying to clone or push commits. 

After I had followed all the instructions here https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account to add multiple ssh keys to my system and tested them I was still getting access denied errors on my GitHub repos that were not my work ones.

# The Fix

After spending FAR too long Googing this issue and getting nowhere I found this Stack Overflow answer: https://stackoverflow.com/a/59074070 I tried adding ` --config core.sshCommand="ssh -i ~/location/to/private_ssh_key"` to the end of my git clone command, and it worked! I was able to clone my personal GitHub repos. 

Now I still had the issue of pushing commits to that repo, I was still getting the following error: 
```bash
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```
Even after trying to add the same `--config` to the git push command I was getting that error, I thought I was stuck again. Then I realized that it must be a git config setting, and found it https://git-scm.com/docs/git-config#Documentation/git-config.txt-coresshCommand

Finally, ran:
```bash
git config core.sshCommand "ssh -i ~/.ssh/[PERSONAL_KEY] -F /dev/null"
```
And I was able to push my commits.

However, after pushing my changes I found that I was still pushing as my work user, so my commits were being signed as my work GitHub account, not exactly what I wanted. But this is an easy fix too, just run:
```bash
git config user.email "[PERSONAL_GITHUB_EMAIL_ADDRESS]"
```

Now all of your commits will be signed as the right user too!
