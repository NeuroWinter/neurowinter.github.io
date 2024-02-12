---
layout: post
category: git
title: "Aligning Dev Branch with Master: Techniques for Git Branch Reset"
heading: Reset Dev branch to Master
description: Quick and easy ways to reset your dev branch
---
# Summary

There are a few situations where you want to reset your develop/test branches back to main;

Breaking changes have been introduced into the dev/test branch.
There are merge conflicts in dev/test for a branch based off main.

# How to fix the problem

Like there are multiple ways that this problem occurs there are also multiple ways of fixing it.

## Merging main in dev

This is the easiest way to do this and allows you to view the changes prior to commiting them. However it does have a downside, you will still have all the history from the broken state, meaning that you dev branch history will diverge from your main branch. You can also run into merge conflicts here, which are never fun.

To do this just raise a PR from main into your dev branch, as you would when merging feature changes into main or test. You can then check the code changes, and verify that it is what you want.

## Hard resetting dev to main

For this process you will need to have write access to the dev branch.

This is a way to make sure that your dev branch has the exact same git log, and code as main does:

```bash
# First checkout main
git checkout main
git pull origin main

# Next delete your dev branch
git branch -D dev

# Now create a new dev branch from the main branch
git checkout -b dev

# Now you can push this new branch with the same history has main to remote
git push origin dev --force
```
