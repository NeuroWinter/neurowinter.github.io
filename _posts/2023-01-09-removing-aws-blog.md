---
layout: post
category: meta
title: "Switching from AWS to Simplify Blog Hosting: A Personal Journey"
heading: Why I Stopped Hosting my Blog on AWS
description: A story of how complicating my blog by hosting it under 2 TLDs was a bad idea, and why KISS is so important.
---

## Summary

I originally set up this blog as a place to document some of my findings and learnings while working in the tech industry. A place to put things that I found hard to find on Google, like my post on using [Typing NoReturn incorrectly](https://neurowinter.com/python/2021/11/12/noreturn-mistake/).

I then started using this as a place to play with things, for example I am hosting this blog both on GitHub Pages, and a static site on AWS using AWS S3.

In the process of doing this I started playing with Terraform, GitHub Actions and a few other things – and while it was fun and a good learning experience. I have since realized that it's not really a good practice or a smart idea.

### The Problem I made for myself

With one of the main principles of this blog for me being to document my findings and share them, so others would not have as much as a hard time as I did to find the solution. Deploying my site (at least in the way I did it) to two different domains failed in the 2nd part of that principle. 

While I am no SEO savant or really know that much about it, splitting your content to two different domains is always going to be a bad idea. All it does is split your traffic between two sites, and could potentially cause a fair amount of harm to your ranking on Google (if you care about that).  How many times have you asked yourself "now was that company name dot com or dot net ?" and end up googling it anyway to find it. That's what I was forcing people who read my posts to do every time. Did you find [NeuroWinter.com](https://NeuroWinter.com) or [NeuroWinter.dev](https://NeuroWinter.dev)? Both were hosting the exact same content. 


### How did I get here ?

I am a tinkerer at heart and when it comes to personal projects to don't exactly follow the "If it ain't broke don't fix it" mentality, I'm more of a "how can I practice this thing I learned in a low risk environment" kinda guy. So that leads me to doing all sorts of suboptimal things for the sake of practice but at the time I don't think they are suboptimal. 

I like to keep things simple to start off with, and then I always manage to find ways to complicate them, but given enough time I will always default to KISS (keep it simple stupid) and that is why I ended up removing the .dev domain all together.

First created my blog on GitHub Pages, as that took care of all the hard stuff for me. It made the act of having a blog super simple, all I had to do was check in new posts and bam they were live. However, I yearned to make it more complex, so to build a rod for my own back I bought NeuroWinter.dev, and started working on deploying the blog there. 

Since Jekyll creates a static site I thought the best place to self-host it would be using AWS S3 Static Sites. So I ended up finding a way to make it even more simple and used [CloudPossse terraform aws cloudfront s3 cdn](https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn) to do all the heavy lifting for me. My final terraform was that module, setting up the providers and a variables file, nice and easy. (I have skipped the part about setting up DNS as that is covered extensively elsewhere):

I then needed to find some GitHub Actions to run all this, and used the following adding my secrets to my GitHub repo:

```yaml
name: Deploy

on:
  push:
    branches:
      - main

jobs:
  Terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest
    steps:
    - name: Checkout Repo
      uses: actions/checkout@v2

    - name: Terraform Init
      run: cd tf && terraform init
      env:
        TF_ACTION_WORKING_DIR: './tf'
        AWS_ACCESS_KEY_ID:  ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY:  ${{ secrets.AWS_SECRET_ACCESS_KEY }}

    - name: Terraform validate
      run: cd tf && terraform validate
      env:
        TF_ACTION_WORKING_DIR: './tf'

    - name: Terraform Apply
      run: cd tf && terraform apply -auto-approve
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        TF_ACTION_WORKING_DIR: './tf'
        AWS_ACCESS_KEY_ID:  ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY:  ${{ secrets.AWS_SECRET_ACCESS_KEY }}

  Jekyll:
    needs: ['Terraform']
    name: Build and deploy Jekyll
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repo
        uses: actions/checkout@v2
      - name: Build
        uses: Ealenn/jekyll-build-action@v1
      - name: Sync output to S3
        run: |
          AWS_EC2_METADATA_DISABLED=true AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }} AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}  aws s3 sync ./_site/ s3://neurowinter-prod-personal-site-origin --delete
```

Once it was all in the main branch I pushed some changes, and it all worked, navigating to [NeuroWinter.dev](https://neurowinter.dev) showed me the exact same content as [NeuroWinter.com](https://neurowinter.com) ! 

### The Return to KISS

After a while of having the site hosted in two different TLD on the net I found my self reading about SEO (How I got here I am not sure…) and found that Google may penalize you if they detect duplicate content of different domains or even different pages! — (I was not able to find a definitive source on this, and it might just be rumors on the internet.). I really had just built a rod for my own back when it comes to search ranking. Most people are worried about others copying their content and posting it as their own, I on the other hand had posted my own content in multiple places! 

Now there are a few ways I could have fixed this:
* Add metadata to my .dev site to show that the .com was the canonical URL
* Remove the .dev domain
* Change the .dev domain to redirect to the .com domain
* Post different content on both .com and .dev

I found that the easiest and fastest way for me to rid myself of this problem was to just change the DNS records in .dev to redirect to .com. I did this manually for now, but knowing me I will try and complicate it and do it via terraform soon. Adding canonical seemed to fix the SEO issue, but did not solve a few other problems I started seeing, I was only seeing metrics for the .com domain, I wasn't sure which domain I had told people to go to, etc.

After removing all the GitHub actions, the Terraform and adding the redirect in AWS, the whole system felt a lot simpler, it wasn't broken in the first place, so why did I go ahead and try to fix it?

This was all a lesson to Keep It Simple Stupid.
