## Getting Started

First thing's first- we need to install RBENV on your machine.  I'm writing this tutorial on a Macbook, and I'll be using Mac-specific installation instructions and commands throughout.  I'd love it if someone were to map this guide to a Windows machine, so that users of that OS could get help with their impostor syndrome as well.

[The RBENV README file](https://github.com/rbenv/rbenv){:target="_blank" rel="noopener"} contains our installation instructions.  The first thing we'll do is run "brew install rbenv ruby-build" in our terminal:

```
$ brew install rbenv ruby-build
```

This should install RBENV into your `~/.rbenv` directory.

Next, navigate into this directory via `cd ~/.rbenv`.  We want to make sure that we're all looking at the same code, which means looking at the same git commit.  So we'll create a new branch, separate from your `master"` or `main` branch, and point that branch to the commit that I used when I started writing this guide (that commit SHA is `c4395e58201966d9f90c12bd6b7342e389e7a4cb`).  I called my new branch `impostorsguides`, but you can call it whatever is easiest for you to remember:

```
$ git checkout -b impostorsguides
$ git reset --hard c4395e58201966d9f90c12bd6b7342e389e7a4cb
```

The link to this SHA of the RBENV codebase can be found [here](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb){:target="_blank" rel="noopener"}.

Now that we've installed RBENV and are pointing to the right version, let's move on.
