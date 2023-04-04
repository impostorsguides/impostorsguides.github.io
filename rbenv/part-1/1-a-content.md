(Note: this walk-through is based on RBENV version `1.2.0-46-g52acbdf`.  You'll likely need to install that version if you want to follow along on your own machine.  The git SHA for the code I'm analyzing is `c4395e58201966d9f90c12bd6b7342e389e7a4cb`, and you can find the Github repo for this version [here](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb){:target="_blank" rel="noopener"}.)

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

## What's the first thing that happens when you type `bundle install` into the terminal and hit "Enter"?

This is the question which set me off on this entire project.

For those unfamiliar with this command, it comes from the [Bundler library](https://bundler.io/).  Bundler provides "a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed", according to its website.  `bundle install` is one of the most common commands we find ourselves typing in Ruby.

I was frustrated that I didn't know how this command worked under-the-hood.  Since I'm a big believer that ["The best way to learn something is to explain it to someone else"](https://ideas.time.com/2011/11/30/the-protege-effect/), I decided to go down the rabbit hole.

**The bad news is, I didn't learn about `bundle` as part of this deep-dive.**  Note that I intend to repeat this process with the `bundle` command in a future post.

The good news is, I ended up learning about the Ruby version manager known as RBENV, a.k.a. the code which gets executed **before we even get to `bundle`**.  Along the way, I learned a lot about `bash` scripting and the command line.

Here's how I did it.

## Caveats & Warnings

In this walk-through, I go on a **ton** of side quests, basically whenever I encounter a concept I'm not familiar with.  If you're looking for a linear A-to-Z storyline, this may not be the guide for you.

Also note that this is a beta version of the journal I kept during this journey, and likely has errors.  If you spot something that I got wrong, let me know at `impostorsguides at gmail dot com`, or at the Twitter link at the top of the page.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

I'll start by finding the code that gets executed when running the `bundle` command.  To do that, I'll use the `which` UNIX command.  In [my terminal](https://archive.ph/Q6aPI), I'll type:

```
$ which bundle

~/.rbenv/shims/bundle
```

Here we see that file containing the `bundle` command's logic lives in a subdirectory of a directory called `.rbenv`.

## Dotfiles and dot directories

The directory's name begins with a `.` because it's meant to be hidden from the `ls` command (unless you run `ls -a` instead of just `ls`).  In UNIX, there's [a convention](https://archive.ph/9l8sE) whereby the names of files and directories which are meant to be hidden from view by default are prefixed with a dot.  [Techopedia says that](https://archive.ph/msXQy) "They are created frequently by various system or application utilities. Hidden files are helpful in preventing accidental deletion of important data."

That last sentence catches my attention- "Hidden files are helpful in preventing accidental deletion of important data."  I've actually never explicitly tested that statement before.  Let's do so now.

### Experiment- do hidden files get deleted when running `rm`?

I create a temporary directory named `foo/`, and create two files inside of it- a hidden one named `.bar` and a regular one named `baz`:

```
$ mkdir foo

$ touch foo/.bar

$ touch foo/baz

$ ls -la foo

total 0
drwxr-xr-x   4 myusername  staff  128 Mar  8 10:39 .
drwxr-xr-x  15 myusername  staff  480 Mar  8 10:39 ..
-rw-r--r--   1 myusername  staff    0 Mar  8 10:39 .bar
-rw-r--r--   1 myusername  staff    0 Mar  8 10:39 baz
```

Then I run `rm foo/*.  I see the following:

```
$ rm foo/*

zsh: sure you want to delete the only file in /Users/myusername/Workspace/OpenSource/foo [yn]? y
```

Lastly, I re-run `ls -la foo` and see the following:

```
$ ls -la foo

total 0
drwxr-xr-x   3 myusername  staff   96 Mar  8 10:40 .
drwxr-xr-x  15 myusername  staff  480 Mar  8 10:39 ..
-rw-r--r--   1 myusername  staff    0 Mar  8 10:39 .bar
```

So yes, it appears that making files hidden with a `.` prefix can prevent them from being accidentally deleted!

Back to  `.rbenv/`.  This hidden directory houses the logic for my Ruby version manager, which is called [RBENV](https://github.com/rbenv/rbenv).  Not everyone uses RBENV; other people use [rvm](https://rvm.io/), [chruby](https://github.com/postmodern/chruby), [asdf](https://asdf-vm.com/), or other programs.

RBENV lets me switch between Ruby versions without too much hassle.  This is a useful ability, because I have multiple Ruby codebases installed on my machine right now, and they all depend on different versions of Ruby.

### Experiments

We just did our first of many experiments.  Sometimes these experiments will help us construct hypotheses of how we think code might work, and then test whether those hypotheses are correct.  Other times, they're just ways that we can prove to ourselves that what we read on StackOverflow or some random person's blog post is actually correct.

Either way, I've found them to be a good habit to develop as I write this post.

## The pain that version managers solve

If we have multiple versions of Ruby installed, that means there are multiple programs installed on our machine which respond to the `ruby` command in our terminal.  Without a Ruby version manager to help us switch between versions, our OS will just pick the first of these programs that it finds.

If we're lucky, the "first version it finds" will be the Ruby version that our program expects.  If we're **not** lucky, it will be a version which doesn't have the methods, classes, etc. that we need (which would cause an error if our program tries to invoke those methods or classes).

A Ruby version manager like RBENV ensures that every time we run a Ruby file, we're using the version that this file depends on.

## So what's the difference between Bundler and RBENV?

But wait.  A minute ago, we said:

> Bundler provides “a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed.”

This... sounds a lot like what I just said RBENV does.  So what's the difference between RBENV and Bundler?  Why do I need both?

[Bundler is a dependency management tool.](https://archive.ph/rNRwU#selection-1911.0-1911.16)  It helps you manage the versions of the gems (i.e. the libraries) in your Ruby project.  RBENV, on the other hand, manages the versions of Ruby you have installed in your system.  It also maintains separate directories for each of the gems you have installed **for each version of Ruby**.  But RBENV doesn't actually manage the gem versions for any particular Ruby project you may have installed.  That's Bundler's job.

More info can be found [here](https://archive.ph/pmhuY), in this excellent summary from Honeybadger.io.

## Shims

Earlier, I made the claim that:

> A Ruby version manager like RBENV ensures that every time we run a Ruby file, we're using the version that this file depends on.

RBENV accomplishes the above task by **intercepting** the command you're running, deciding which Ruby version to use based on the information available to it (more on that later), and then passing the command you entered to the correct Ruby interpreter based on that version.  The file which performs this interception is known as a "shim".  Programs that act as shims are meant to be transparent, meaning that you think you're talking to the program you invoked (say, `bundle` if we're running `bundle install`), but the whole time you're really talking to the shim.  Similarly, `bundle` thinks it's talking to you, not to a shim.

To quote [RBENV's README file](https://archive.ph/VGriC#how-it-works):

<p style="text-align: center">
  <img src="/assets/images/rbenv-how-it-works-readme.png" width="70%" alt="'How It Works' section from RBENV's README file"  style="border: 1px solid black; padding: 0.5em">
</p>

The file whose path we discovered earlier (`~/.rbenv/shims/bundle`) is the shim file for the Bundler gem's `bundle` command.

## The code for the shim file

Let's take a look at the shim's code.  I type the following into my terminal:

```
$ cat ~/.rbenv/shims/bundle
```

And what I see is:

```
#!/usr/bin/env bash
set -e
[ -n "$RBENV_DEBUG" ] && set -x

program="${0##*/}"
if [ "$program" = "ruby" ]; then
  for arg; do
    case "$arg" in
    -e* | -- ) break ;;
    */* )
      if [ -f "$arg" ]; then
        export RBENV_DIR="${arg%/*}"
        break
      fi
      ;;
    esac
  done
fi

export RBENV_ROOT="/Users/myusername/.rbenv"
exec "/Users/myusername/.rbenv/bin/rbenv" exec "$program" "$@"
```

Yikes!  That's a spicy meatball.

We'll need the balance of this post to explain it all in detail, but the important thing to remember is that the above code does NOT come from the `bundle` command itself, but rather RBENV's *shim* of the `bundle` command.  In fact, if we were to inspect other files in the `~/.rbenv/shims/` folder, we'd see they look *exactly* the same!  The following files all contain exactly the same code as the above:

 - `~/.rbenv/shims/rails`
 - `~/.rbenv/shims/ruby`
 - `~/.rbenv/shims/gem`

Let's break down the code line-by-line, and we'll see why all these files can have the same exact code, yet execute drastically programs.
