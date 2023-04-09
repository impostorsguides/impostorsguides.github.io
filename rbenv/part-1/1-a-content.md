"The most effective debugging tool is still careful thought, coupled with judiciously placed print statements." — Brian Kernighan, [<u>Unix for Beginners</u>](https://wolfram.schneider.org/bsd/7thEdManVol2/beginners/beginners.pdf){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

(Note: this walk-through is based on RBENV version `1.2.0-46-g52acbdf`.  You'll likely need to install that version if you want to follow along on your own machine.  The git SHA for the code I'm analyzing is `c4395e58201966d9f90c12bd6b7342e389e7a4cb`, and you can find the Github repo for this version [here](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb){:target="_blank" rel="noopener"}.)

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

## What's the first thing that happens when you type `bundle install` into the terminal and hit "Enter"?

This is the question which set me off on this entire project.

For those unfamiliar with this command, it comes from the [Bundler library](https://bundler.io/){:target="_blank" rel="noopener"}.  Bundler provides "a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed", according to its website.  `bundle install` is one of the most common commands we find ourselves typing in Ruby.

I was frustrated that I didn't know how this command worked under-the-hood.  Since I'm a big believer that ["The best way to learn something is to explain it to someone else"](https://ideas.time.com/2011/11/30/the-protege-effect/){:target="_blank" rel="noopener"}, I decided to go down the rabbit hole.

**The bad news is, I didn't learn about `bundle` as part of this deep-dive.**  Note that I intend to repeat this process with the `bundle` command in a future post.

The good news is, I ended up learning about the Ruby version manager known as RBENV, a.k.a. the code which gets executed **before we even get to `bundle`**.  Along the way, I learned a lot about `bash` scripting and the command line.

Here's how I did it.

## Caveats & Warnings

In this walk-through, I go on a **ton** of side quests, basically whenever I encounter a concept I'm not familiar with.  If you're looking for a linear A-to-Z storyline, this may not be the guide for you.

Also note that this is a beta version of the journal I kept during this journey, and likely has errors.  If you spot something that I got wrong, let me know at `impostorsguides at gmail dot com`, or at the Twitter link at the top of the page.
