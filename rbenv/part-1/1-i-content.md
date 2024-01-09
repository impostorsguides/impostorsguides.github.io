We've walked through all the code in the shim file, and can explain what it does.  But there's an order-of-magnitude difference between knowing what a piece of code does, vs. knowing how and why it got to that point.  Reading the repo's git history is one way to reach that 2nd level of understanding.

I'm not proposing that we read the **entire** git history of this repo (although the more of it we read, the more context we'd have).  But we can read enough of it to answer the question we asked earlier, i.e. why there's a need for this `if`-block which takes up 2/3 of the code in the shim file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Here's our working knowledge of what the `if`-block does:

 - The first clause of the `case` statement (i.e. the `-e* | -- ) break ;;`) is a guard clause which bails out of the `for`-loop early.  If one of these two patterns is found, we can assume the remaining args don't matter for the purposes of the shim.
 - The clause which seems to be doing most of the heavy lifting is this one:

```
*/* )
    if [ -f "$arg" ]; then
      export RBENV_DIR="${arg%/*}"
      break
    fi
    ;;
```

- Any other arg is simply ignored by this `if`-block, since there is no `* )` default clause in the case statement.

The 2nd clause is only triggered if the arg includes a `/`.  For example, if it takes the form of `path/to/filename`.  We further know this case statement is concerned with filenames, because it performs the check `if [ -f "$arg" ]; then` to see if the arg corresponds to a file.

But why do we care whether we have a `path/to/` before `filename`?

In [the "How It Works" section](https://web.archive.org/web/20230408051543/https://github.com/rbenv/rbenv#how-it-works){:target="_blank" rel="noopener"} of the README file, we see that if you pass the `ruby` command a filename to run, RBENV will look for a file named `.ruby-version` in the same directory as that of the filename you pass.  This is true *even if that directory is not the one you're in now*.  That's important, because that 2nd directory may have its own `.ruby-version` file, possibly containing a different Ruby version from the one you're currently using.

Putting these pieces together, my hypothesis is that this clause handles the situation where you're running a Ruby file from a different directory than the one you're in, and this directory may have its own (potentially different) Ruby version.

Let's find the PR which added the `if`-block, and see if it confirms our theory.

### Quick note- `.ruby-version` vs. `.rbenv-version`

As mentioned, RBENV sometimes uses on a file called `.ruby-version` to do its job.  However, when we dig into the history of the `if`-block, we'll be looking at an earlier version of RBENV in which it instead used a file called `.rbenv-version`.  This file performed the same function, but [per this comment thread](https://github.com/rbenv/rbenv/pull/302#issuecomment-11785236){:target="_blank" rel="noopener"}, the filename made it harder for folks who used RBENV to collaborate with folks who used other Ruby version managers.  Because of this, the core team subsequently switched from using `.rbenv-version` to `.ruby-version`.  So if you see me referring to both filenames and get confused, just know that they had the same purpose.

## Using git and Github to find where a change was introduced

In order to find this PR, we need to know it's SHA, which is a unique identifier that git uses to refer to a specific commit.  Once we have this, we can plug it into Github's search bar and pull up our PR.

Normally we could just use `git blame <filename>` to get this SHA directly from the line of code in our file.  But if we try that here, we see the following:

```
$ which ruby

/Users/myusername/.rbenv/shims/ruby

$ git blame /Users/myusername/.rbenv/shims/ruby

fatal: no such path 'shims/ruby' in HEAD
```

 That's because the shim files are included in the `.gitignore` file for `~/.rbenv`, meaning they're not part of a git repo (and hence don't have their own SHA).  We can confirm this by looking at RBENV's [`.gitignore` file](https://git-scm.com/docs/gitignore){:target="_blank" rel="noopener"}:

```
$ vim ~/.rbenv/.gitignore

  1 /plugins
  2 /shims                # this is how we know our `ruby` shim isn't part of RBENV's git repository
  3 /version
  4 /versions
  5 /sources
  6 /cache
  7 /libexec/*.dylib
  8 /src/Makefile
  9 /src/*.o
 10 /gems
```

RBENV doesn't track the contents of the `shims/` directory because each user's machine will have a different set of Ruby gems installed, meaning the filenames inside each user's `shims/` directory will be different.

However, since the shims all have the same exact code, I'd bet that there's a "shim factory" somewhere in the RBENV codebase, which auto-generates a new file whenever a new gem is installed.

We can search the RBENV codebase for the code from the `if`-block, but first we need to pick which line of code to search for.  I pick a line which I suspect will not be too common in the codebase, giving us a high signal-to-noise ratio in the search results.  Then I use [the `ag` tool](https://github.com/ggreer/the_silver_searcher){:target="_blank" rel="noopener"} to find its location:

<center>
  <a target="_blank" href="/assets/images/ag-program-equals.png">
    <img src="/assets/images/ag-program-equals.png" width="90%" alt="searching or the shim code">
  </a>
</center>

Looks like there is only one search result, in a file named `libexec/rbenv-rehash`, and it looks a lot like our original line of code.  Let's have a closer look at that file:


<center>
  <a target="_blank" href="/assets/images/create-prototype-shim.png">
    <img src="/assets/images/create-prototype-shim.png" width="90%" alt="the 'create-prototype-shim' method in rbenv-rehash">
  </a>
</center>

It lives inside a function called `create_prototype_shim`.  That sounds a lot like the "shim factory" we hypothesized!

Now that we know where in the RBENV codebase the `if`-block comes from, let's look at the git history for **that** file.  I copy the filepath for `rbenv-rehash` and run `git blame` on it (docs on this command [here](https://web.archive.org/web/20230327142152/https://git-scm.com/docs/git-blame){:target="_blank" rel="noopener"}):

```
$ git blame libexec/rbenv-rehash
```

I've highlighted the results we care about below:

<center>
  <a target="_blank" href="/assets/images/screenshot-9apr2023-124pm.png">
    <img src="/assets/images/screenshot-9apr2023-124pm.png" width="100%" alt="output of the `git blame` command for the `libexec/rbenv-rehash` file">
  </a>
</center>

This is a lot of info.  Let's break down what we're looking at, using line 64 as an example:

 - `283e67b5`- this is the first 8 characters of the SHA that we're looking for.  This is what we'll plug into Github's search box.
 - `libexec/rbenv-rehash`- this is the filename we're looking at, in the form of `path/to/filename` relative to our current directory.
 - `(Sam Stephenson`- this is the name of the person who authored the commit.  This is where the command `git blame` gets its name- we want to know "who to blame" (or [praise](https://github.com/ansman/git-praise){:target="_blank" rel="noopener"}, as the case may be).
 - `2012-12-27 13:41:55 -0600`- this is the full timestamp for when the code was committed to the repository.
 - `64)`- this is the line number of the code in the file itself.
 - `program="\${0##*/}"`- finally, this is the line of code itself.

As I mentioned, what we care about is the left-most column.  It contains the first 8 characters of the commit's unique identifier (also called a SHA) which introduced each line of code.  This isn't the full SHA, just a snippet, but it's almost certainly long enough to make any collisions with other commits unlikely.

Notice that the SHA (`283e67b5`) is the same for the entire `if`-block.  That's lucky for us- it means that this code was all added to the repo at the same time, and gives me more confidence that this is the SHA we want.  If there were many different SHAs, each with different commit dates, it would be more of a slog to search each one until we found the PR we want.

I open my web browser and go to Github, where I paste the SHA value I copied from `git blame` into the search bar on the top-left and select "In this repository":

<center>
  <a target="_blank" href="/assets/images/searching-github-for-sha.png">
    <img src="/assets/images/searching-github-for-sha.png" width="90%" alt="output of the `git blame` command for the `libexec/rbenv-rehash` file" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Github says "we couldn't find any code..."...

<center>
  <a target="_blank" href="/assets/images/screenshot-12apr2023-1024am.png">
    <img src="/assets/images/screenshot-12apr2023-1024am.png" width="90%" alt="output of the `git blame` command for the `libexec/rbenv-rehash` file" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

...but that message is irrelevant for us.  We're not looking for **code**; we're looking for a **PR**.  And on the left-hand side, we can see that Github did find one issue and one commit containing this SHA.  That makes me cautiously optimistic- it means we won't have to wade through too many commits to get where we're going.

I right click on each section to open them in new tabs.  First the commit results:

<center>
  <a target="_blank" href="/assets/images/git-commit-history-for-sha.png">
    <img src="/assets/images/git-commit-history-for-sha.png" width="90%" alt="Github's results for the commit history containing our SHA" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

Reconstructing the commit message (which was truncated due to its length), we can see at the top that the commit message for this commit was:

```
When the ruby shim is invoked with a script, set RBENV_DIR to the script's dirname
```

This sounds similar to our hypothesis.  Let's also check [the issue link](https://github.com/rbenv/rbenv/pull/299){:target="_blank" rel="noopener"}:


<center>
  <a target="_blank" href="/assets/images/rbenv-issue-page.png">
    <img src="/assets/images/rbenv-issue-page.png" width="90%" alt="The newer Github issue related to the PR which introduced this if-block." style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The description says `This branch adjusts the behavior of the ruby shim, when invoked with the path to a Ruby script as an argument, to set RBENV_DIR to the directory of the given script.  It should, in effect, remove the need for the ruby-local-exec shebang line.`  That sounds pretty close to what we hypothesized.

## One Last Thing

Before closing the browser tab, I notice the following at the end of the PR:

> See previous discussion at [#298](https://github.com/rbenv/rbenv/pull/298){:target="_blank" rel="noopener"}

Out of curiosity I read through that PR.  Among other things, it contains a conversation which stands out to me:

<center>
  <a target="_blank" href="/assets/images/screenshot-10apr2023-1057am.png">
    <img src="/assets/images/screenshot-10apr2023-1057am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

<center>
  <a target="_blank" href="/assets/images/screenshot-10apr2023-1059am.png">
    <img src="/assets/images/screenshot-10apr2023-1059am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

<center>
  <a target="_blank" href="/assets/images/screenshot-13apr2023-1135am.png">
    <img src="/assets/images/screenshot-13apr2023-1135am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

In this conversation, the core team comes to an agreement that RBENV should use `.rbenv-version` to pull the right Ruby version, **and** that the `.rbenv-version` file used should be local to the file that is being executed.

I get the impression that, at the time this conversation took place, this was not yet how RBENV worked in practice.  If that's true, this could represent another reason why the `if`-block was an improvement over the previous version of the shim.  Let's try to reproduce this behavior, for educational purposes.

### Experiment: did the introduction of the `if`-block change how we derive the Ruby version?

My plan is to create two directories with different local Ruby versions, as well as a 3rd Ruby version set globally (i.e. for all other directories except for these two new ones) to avoid conflicts with the versions in these 2 directories.  Then I'll test which version of Ruby is picked up by RBENV inside each directory.

First, I make sure that the version of RBENV that I'm running matches the last of the commits in the PR which added the `if`-block:

<center>
  <a target="_blank" href="/assets/images/screenshot-19apr2023-1005am.png">
    <img src="/assets/images/screenshot-19apr2023-1005am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

```
$ cd ~/.rbenv
$ git co 339e331f1dcdbbe3659981968e081492817023ed
$ git co -b just-after-if-block
```

In the 3rd step above, I check out a new `git` branch with a descriptive name so that I can quickly hop back to this version of the code if I need to.

Next, I delete and re-create all the shims in RBENV's `shims/` directory, to make sure my shim code matches my current version of RBENV:

```
$ rm -rf shims/*
$ rbenv rehash
```

I verify that the `ruby` shim looks the way I expect:

```
$ cat `which ruby`
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
exec rbenv exec "$program" "$@"
```

Good, we see the `if`-block.

Next, I `cd` into my main working directory and, from there, install a global Ruby version with a specific number:

```
$ cd ~/Workspace/OpenSource
$ rbenv install 3.1.0
$ rbenv global 3.1.0
```

I do this because I want to avoid a situation where my `.rbenv-version` file contains the same version number as the global version number, which could make it confusing as to what the source of the version number was.

Next, I make two sibling directories, named `foo/` and `bar/`, each containing a `.rbenv-version` file with a version number that is **different from** my global Ruby version:

```
$ mkdir bar

$ echo "2.7.5" > bar/.rbenv-version

$ mkdir foo

$ echo "3.0.0" > foo/.rbenv-version
```

I then create two files named `foo/foo.rb` and `bar/bar.rb`.  The 2 files do the same thing- they simply print the version of Ruby that the interpreter is using:

```
$ echo "puts RUBY_VERSION" > foo/foo.rb
$ echo "puts RUBY_VERSION" > bar/bar.rb
```

I `cd` into `bar/` and run `bar.rb`:

```
$ cd bar/
$ ruby bar.rb

2.7.5
```

Then, **while still inside `bar/`**, I run `foo/foo.rb`:

```
$ ruby ../foo/foo.rb

3.0.0
```

This is what I'd expect based on reading the core team's PR conversation: each file uses the Ruby version pinned by its respective `.rbenv-version` file, regardless of where I am when I run it.

Next, I check out the version of the RBENV code just **before** the `if`-block was introduced:

<center>
  <a target="_blank" href="/assets/images/screenshot-19apr2023-1009am.png">
    <img src="/assets/images/screenshot-19apr2023-1009am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

```
$ cd ~/.rbenv
$ git co 6c1fb9ffd062ff04607d2e0f486067eaf6e48d1e~
$ git co just-before-if-block
```

Once again, I delete and re-build my shims:

```
$ rm -r shims/*
$ rbenv rehash
```

I verify that my `ruby` shim no longer has the `if`-block:

```
$ cat `which ruby`

#!/usr/bin/env bash
set -e
export RBENV_ROOT="/Users/myusername/.rbenv"
exec rbenv exec "${0##*/}" "$@"
```

We see the `if`-block is gone.  That's what we want.

Now, back in my `bar/` directory, I re-run both `bar.rb` and `../foo/foo.rb`:

```
$ cd ~/Workspace/OpenSource/bar

$ ruby bar.rb

2.7.5

$ ruby ../foo/foo.rb

2.7.5
```

With the `if`-block removed, we now see that the Ruby version for `foo` does **not** reflect the version number specified in its `.rbenv-version` file if we run `foo.rb` from within the `bar/` directory.

But if we `cd` from `bar/` into its sibling `foo/` and run `foo.rb`, it changes back to the version we expect, `3.0.0`:

```
$ cd ../foo
$ ruby foo.rb

3.0.0
```

So we can see that one of the things that the `if`-block does is help pin the Ruby version of a file we run based on the `.rbenv-version` file in the same directory.  Judging by [the conversation in the PR](https://github.com/rbenv/rbenv/pull/298#issuecomment-11699902){:target="_blank" rel="noopener"}, this seems to be what the core team intended.  On a personal level, it's also what I as a user would expect the behavior to be, so I can understand why they did what they did.

Before moving on, I make sure to clean up the mess I made:

```
$ cd ~/.rbenv

$ git co master

$ git branch -D just-before-if-block

$ git branch -D just-after-if-block

$ rm -r shims/*

$ rbenv rehash
```
