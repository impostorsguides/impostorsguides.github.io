---
layout: default
title: Chapter 0 (Storytelling Structure)
permalink: /chapter-0-storytelling/
---

# Chapter 0 (Storytelling Structure)

To begin this project, I set out to answer the following questions:

 - Why is managing my Ruby version even important?  Why should people care?
 - Why is it useful to know how RBENV works?
 - How does RBENV deliver on its promise to manage my Ruby version?

## Why is managing my Ruby version even important?  Why should people care?

Because different codebases on your machine will run on different versions of the same languages.  One Rails app might use Ruby v2.7.5, while another has already upgraded to v3.0.0.  If you don’t use a Ruby version manager, then the only alternative is to use the version of Ruby which shipped with your laptop.

If you insist on not using a version manager, then every time you want to switch from working on one app to working on the other, you have to upgrade / downgrade your system Ruby version.  That is, shall we say, impractical.  Using a version manager makes this switching process as easy as a few keystrokes.

[This article](https://web.archive.org/web/20220809210326/https://launchschool.com/books/core_ruby_tools/read/ruby_version_managers) sums it up nicely:

![image tooltip here](/assets/images/why_use_a_version_manager.png)

In my experience, version managers are one of the more widely-used tools in my toolbelt.  If I want to understand my tools at a deep level, there are certainly much worse places to start.

## Why is it useful to know how RBENV works?

RBENV affects which version of Ruby you use when you execute many commands.  The choice of which Ruby version you use is one of the first (if not *the* first) choices you make when executing a program.  Everything else that happens downstream is affected by this choice.  So knowing how RBENV performs its duties can give us intuition into how the programs we develop are running (or, in the case of bugs, not running).

In addition, because RBENV is such a widely-used tool, its code has been written and reviewed by some of the world’s leading engineers and developers.  By reading the code (and the PRs which merged the code), we can learn a lot and become better engineers ourselves.

## How does RBENV deliver on its promise to manage my Ruby version?

This is the question that we’ll spend the remainder of the project answering.
