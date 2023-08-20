"The most effective debugging tool is still careful thought, coupled with judiciously placed print statements." — Brian Kernighan, [<u>Unix for Beginners</u>](https://web.archive.org/web/20220122011437/https://wolfram.schneider.org/bsd/7thEdManVol2/beginners/beginners.pdf){:target="_blank" rel="noopener"}.

## Disclaimer

This is NOT an official guide to RBENV's codebase.  It is not written by any member of the RBENV core team, and is not endorsed by them in any way.  It is simply the educated guesses of a journeyman engineer who wants to attain mastery by reading open-source code.

## Background

What's the first thing that happens when you type `bundle install` into the terminal and hit "Enter"?

This is the question which set me off on this entire project.

For those unfamiliar with this command, it comes from the [Bundler library](https://bundler.io/){:target="_blank" rel="noopener"}.  Bundler provides "a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed", according to its website.  Professionally, I work on a large Rails codebase with many contributors, and `bundle install` is one of the most common commands I find myself typing in that codebase.

I was frustrated that I didn't know how this command worked under-the-hood.  Since I'm a big believer that ["The best way to learn something is to explain it to someone else"](https://ideas.time.com/2011/11/30/the-protege-effect/){:target="_blank" rel="noopener"}, I decided to blog about what I was learning, as I learned it.

**The bad news is, I didn't learn about `bundle` as part of this deep-dive.**  I intend to repeat this process with the `bundle` command in a future post.

The good news is, I ended up learning about the Ruby version manager known as RBENV, a.k.a. the code which gets executed **before my machine even reaches the `bundle` command**.  (If you use RBENV as your Ruby version manager, the same can be said about your machine.)  Along the way, I learned a lot about `bash` scripting and the command line.

Here's how I did it.

## Caveats & Warnings

In this walk-through, I go on a **ton** of side quests, basically whenever I encounter a concept I'm not familiar with.  If you're looking for a linear A-to-Z storyline, this may not be the guide for you.

Also note that this is a beta version of the journal I kept during this journey, and likely has errors.  If you spot something that I got wrong, let me know at `impostorsguides at gmail dot com`, or at the Twitter link at the top of the page.

## Getting Started

First thing’s first- we need to install RBENV on your machine.  I’m writing this tutorial on a Macbook, and I’ll be using Mac-specific installation instructions and commands throughout.  I’d love it if someone were to map this guide to a Windows machine, so that users of that OS could get help with their impostor syndrome as well.

[The RBENV README file](https://github.com/rbenv/rbenv){:target="_blank" rel="noopener"} contains our installation instructions.  The first thing we’ll do is run “brew install rbenv ruby-build” in our terminal:

```
$ brew install rbenv ruby-build
```

This should install RBENV into your `~/.rbenv` directory.

Next, navigate into this directory via `cd ~/.rbenv`.  We want to make sure that we’re all looking at the same code, which means looking at the same git commit.  So we’ll create a new branch, separate from your `master“` or `main` branch, and point that branch to the commit that I used when I started writing this guide (that commit SHA is `c4395e58201966d9f90c12bd6b7342e389e7a4cb`).  I called my new branch `impostorsguides`, but you can call it whatever is easiest for you to remember:

```
$ git checkout -b impostorsguides
$ git reset --hard c4395e58201966d9f90c12bd6b7342e389e7a4cb
```

The link to this SHA of the RBENV codebase can be found [here](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb){:target="_blank" rel="noopener"}.

Now that we’ve installed RBENV and are pointing to the right version, let’s move on.
