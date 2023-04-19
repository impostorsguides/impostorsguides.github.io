

Next line of code is:

```
    else echo "rbenv: $*"
```

What does `$*` do?  This time, it's [O'Reilly to the rescue](https://web.archive.org/web/20230323072228/https://www.oreilly.com/library/view/learning-the-bash/1565923472/ch04s02.html){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/screenshot-25mar2023-1137am.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow - what does `$*` do?">
</p>

So `$*` expands to a single string containing all the arguments passed to the script.  We can verify that by writing our own simple script:

```
#!/usr/bin/env bash

echo "args passed in are: $*"
```

When we call it, we get:

```
$ ./foo bar baz

args passed in are: bar baz
```

No surprises here.

While we're at it, let's try a similar experiment that we did with `cat -`, but with the "else" case here.  Going back into my "foo" script, I make the following changes:

 - I add an identical `else` clause to our `foo` function, and
 - I replace the previous pipe invocation of `foo` with a new one that passes a string as a parameter:

```
#!/usr/bin/env bash

foo() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
  } >&2
  exit 1
}

foo "cannot find readlink - are you missing GNU coreutils?"
```

Running the script gives us:

```
$ ./foo

rbenv: cannot find readlink - are you missing GNU coreutils?
```

So it just concatenates "rbenv: " at the front of whatever error message you pass it.

So to sum up the "abort" function:

 - if you don't pass it any string as a param, it assumes you are piping in the error, and it reads from STDIN and prints the input to STDERR.  Otherwise...
 - It assumes that whatever param you passed is the error you want to output, and...
 - It prints THAT to STDERR.
 - Lastly, it terminates with a non-zero exit code.

We were lucky here, because the function we were studying is called throughout the file, and those usage examples were helpful (to me at least) in understanding how the function worked.  It's not always possible to use this strategy, but when it IS possible, it's a good tool for our toolbelt.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

[Next line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23){:target="_blank" rel="noopener"} is:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

Reading this line, I ask myself a few questions:

 - What does the `enable` command do?
 - What does its `-f` flag mean?
 - What are the command's positional arguments?
 - What does `2>/dev/null` do?
 - What kind of file extension is `.dylib`?  What does that imply about the contents of the file?

I'll try to answer these one-by-one.

I type both `man enable` and `help enable` in my terminal, but each time I see `No manual entry for enable`.

Luckily, [the first result](https://web.archive.org/web/20220529121055/https://ss64.com/bash/enable.html){:target="_blank" rel="noopener"} when I Google "enable command bash" looks like a good one, even if it's not part of the official docs:

<p style="text-align: center">
  <img src="/assets/images/enable-docs-12mar2023-157pm.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="Docs on the `enable` keyword">
</p>

This actually answers my first three questions:

 - What does the `enable` command do?
    - The `enable` command can take builtin shell commands (like `which`, `echo`, `alias`, etc.) and turn them on or off.
    - The link mentions that this could be useful if you have a script which shares the same name as a builtin command, and which is located in one of your $PATH directories.
    - Normally, the shell would check for builtin commands first, and only search in $PATH if no builtins were found.
    - You can ensure your shell won't find any builtin command by disabling the builtin using the `enable` command.
    - [Here's a link explaining more](https://web.archive.org/web/20230407091137/https://www.oreilly.com/library/view/bash-cookbook/0596526784/ch01s09.html){:target="_blank" rel="noopener"}, from O'Reilly's Bash Cookbook.

 - What does the `-f` flag do?
    - You would pass this flag if you want to change the source of your new command from its original source (the builtin) to a file whose path you specify after the `-f` flag.
    - In other words, you want to [monkey-patch](https://web.archive.org/web/20221229064458/https://stackoverflow.com/questions/394144/what-does-monkey-patching-exactly-mean-in-ruby){:target="_blank" rel="noopener"} the command (or even rebuild it entirely, from scratch).

 - What are the command's positional arguments?
    - In the case of our line of code, the first positional argument is the filepath containing the new version of the command we're over-riding.
    - The 2nd positional argument is the name of the command we're over-riding.

TODO- add experiment on using the `enable` command, possibly including the `-f` flag.

My 4th out of 5 questions was "What does `2>/dev/null` do?"

According to [StackOverflow](https://web.archive.org/web/20220801111727/https://askubuntu.com/questions/350208/what-does-2-dev-null-mean){:target="_blank" rel="noopener"}:

 - The `2>` tells the shell to take the output from file descriptor #2 (aka `stderr`) and send it to the destination specified after the `>` character.
 - Further, "`/dev/null` is the null device it takes any input you want and throws it away. It can be used to suppress any output."
 - So here we're suppressing any error which is output by the `enable` command, rather than showing it.

If I had to guess, I'd say we're doing that because this is part of an `if` check, and if the `enable` command fails, we don't want to see the error, we just want to move on and execute the code in the `else` block.

TODO- add experiment on using `/dev/null`.

Final question: what kind of file extension is `.dylib`, and what does that imply about the contents of the file?

I Googled "what is dylib extension" and read a few different results ([here](https://web.archive.org/web/20211023152003/https://fileinfo.com/extension/dylib){:target="_blank" rel="noopener"} and [here](https://web.archive.org/web/20211023142331/https://www.lifewire.com/dylib-file-2620908){:target="_blank" rel="noopener"}, in particular).  They tell me that:
 - "dylib" is a contraction of "dynamic library", and that this means it's a library of code which can be loaded on-the-fly (aka "dynamically").
 - Loading things dynamically (as opposed to eagerly, when the shell or the application which relies on it is first booted up) means you can wait until you actually need the library before loading it.
 - This, in turn, means you're not taking up memory with code that you're not actually using yet.

So to summarize:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

Means:

 - If we're successful in monkey-patching the `realpath` command with a new implementation which lives in the `rbenv-realpath.dylib` file, then do the thing inside the `if` block.
 - If we're *not* successful in doing that, ignore any `stderr` output rather than printing it to the screen.

Speaking of the `realpath` command- what does it normally do?

Typing `man realpath` into our terminal reveals the following:

```
REALPATH(1)                                                                       User Commands                                                                      REALPATH(1)

NAME
       realpath - print the resolved path

SYNOPSIS
       realpath [OPTION]... FILE...

DESCRIPTION
       Print the resolved absolute file name; all but the last component must exist
```

The phrase "print the resolved path" is confusing to me.  In what sense is the path that the user provides "resolved"?  What would "unresolved" mean?

I search for "what is realpath unix" and find [the internet equivalent of the same man page](https://web.archive.org/web/20220608150749/https://man7.org/linux/man-pages/man1/realpath.1.html){:target="_blank" rel="noopener"}.  But then I find [the `man(3)` page](https://web.archive.org/web/20220629161112/https://man7.org/linux/man-pages/man3/realpath.3.html){:target="_blank" rel="noopener"} for a *function* named `realpath`.  Among other things, it says:

> realpath() expands all symbolic links and resolves references to `/./`, `/../` and extra `/` characters in the null-terminated string named by `path` to produce a canonicalized absolute pathname.

OK, so the `realpath()` function takes something like `~/foo/../bar` and changes it to `/Users/myusername/bar`.  That must mean a path like...
```
~/Desktop/my-company/projects/..
```

...is an "unresolved" path, and calling `realpath` on that unresolved path would return...

```
/Users/myusername/Desktop/my-company
```

I quickly test this out in my terminal:

```
$ mkdir ~/foo
$ mkdir ~/bar
$ realpath ~/foo/../bar

/Users/myusername/bar
```

Side-note: I initially tried to run the `realpath` command first, without having created the directories, but I got `realpath: /Users/myusername/foo/../bar: No such file or directory`.  So it looks like the file or directory does actually have to exist in order for `realpath` to work.

So this `if` block overrides the existing `realpath` command, but only if the `"${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib` file exists.

This makes me wonder:
 - **Why** did the authors feel the need to override the existing `realpath` command?
 - Wouldn't it have been safer to just call their imported function something else?
- And what was wrong with the original `realpath`, anyway?

### Why over-ride `realpath`?

To answer question #1, I decide to search the repo's `git` history.

I start by running the following command in the terminal, in the home directory of the `rbenv` repo that I pulled down from Github:

```
$ git blame libexec/rbenv
```

I get the following output (click the image to expand):

<center style="margin-bottom: 3em">
  <a href="/assets/images/git-blame-output-12mar2023-213pm.png" target="_blank">
    <img src="/assets/images/git-blame-output-12mar2023-213pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

This output is organized into columns:

 - Column #1 is the SHA of the commit that added this line to the codebase.
 - Column #2 is the author of the commit.
 - Column #3 is the timestamp when the code was committed.
 - Column #4 is the line number in the file, and
 - Column #5 is the actual line of code itself.

The code I'm trying to research is on [line 23 of the file](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv#L23){:target="_blank" rel="noopener"}, so I scan down to the right line number based on the values in column #4, and I see the following:

```
6e02b944 (Mislav Marohnić   2015-10-26 15:53:20 +0100  23) if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
```

We can parse this line as follows:

 - The SHA of the commit we're looking for is 6e02b944.
 - The author of this code is someone named Mislav Marohnić.
 - This code was committed on Oct 26, 2015 at 15:53pm +0100 (aka Central European Standard Time, I think?).
 - `23)` is the line number of our code.
 - Everything after `23)` is just the original line of code itself.

If we were to run `git checkout 6e02b944`, we'd be telling git to roll all the way back to 2015, making this commit the latest one in our repo.

I plug this SHA into Github's search bar from within the repo's homepage, and I see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-459pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-459pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github search results">
  </a>
</p>

I click on the one commit that comes back, and see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-500pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-500pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github search results part 2">
  </a>
</p>

Clicking through once again, I see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-501pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-501pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github search results part 2">
  </a>
</p>


This shows us what the code was like before this commit, and what it was like after.  In this case, it's not super-helpful, because this commit changed the line of code but not in a way that makes clear what's going on.

Let's try a different strategy:

 - I'll roll back my local version of this repo to an earlier commit.
 - But that earlier commit will **not** be the one we're looking at now (i.e. `6e02b944`).
 - Instead, I'll use the commit *before* this commit.
 - If I then re-run `git blame` on this same line of code, **with that older commit checked-out via `git checkout <older_commit_sha>`**, I can see the diff and the SHA which led to **that change**.
 - Repeating this process as necessary, I will eventually get to the commit which introduced the monkey-patching of `realpath`, (hopefully) along with an explanation of why this was done.

I run `git checkout 6e02b944~`.  Note the single `~` at the end, which means "the commit just prior to `6e02b94`.  You can say "two commits prior" by running `git checkout 6e02b944~~`, or alternately `git checkout 6e02b944~2`.

From the last screenshot above, we can see that the old line of code was #15, so let's look for that line in the `git blame` output:

```
$ git checkout 6e02b944~

Note: switching to '6e02b944~'.
...

$ git blame libexec/rbenv
```

...results in:

```
6938692c (Andreas Johansson 2011-08-12 11:33:45 +0200   1) #!/usr/bin/env bash
6938692c (Andreas Johansson 2011-08-12 11:33:45 +0200   2) set -e
e3f72eba (Sam Stephenson    2013-01-25 12:02:11 -0600   3) export -n CDPATH
43624943 (Joshua Peek       2011-08-02 18:01:46 -0500   4)
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   5) if [ "$1" = "--debug" ]; then
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   6)   export RBENV_DEBUG=1
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   7)   shift
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   8) fi
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600   9)
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  10) if [ -n "$RBENV_DEBUG" ]; then
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  11)   export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] '
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  12)   set -x
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  13) fi
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600  14)
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  15) if enable -f "${0%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  16)   abs_dirname() {
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  17)     local path="$(realpath "$1")"
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  18)     echo "${path%/*}"
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  19)   }
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  20) else
```


The SHA is `5287e2eb`.  Let's again plug this into Github's search history:

When we click on the "Commits" section, we see:

<p style="text-align: center">
  <a href="/assets/images/searching-for-a-commit-12mar2023-444pm.png" target="_blank">
    <img src="/assets/images/searching-for-a-commit-12mar2023-444pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Searching for a commit in the Github repo">
  </a>
</p>

And when we click on the "Issues" section, we see:

<p style="text-align: center">
  <a href="/assets/images/searching-for-gh-issues-12mar2023-444pm.png" target="_blank">
    <img src="/assets/images/searching-for-gh-issues-12mar2023-444pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Searching for a commit in the Github repo">
  </a>
</p>

OK, so judging by the title of the issue, this change has something to do with making rbenv's performance faster.

Clicking on [the issue link](https://github.com/rbenv/rbenv/pull/528){:target="_blank" rel="noopener"} first, I see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-519pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-519pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github issue on speeding up rbenv by dynamically loading a compiled command">
  </a>
</p>

Looks like that's correct- the goal of this change was to address a bottleneck in rbenv's performance, i.e. "resolving paths to their absolute locations without symlinks".

To make sure this is the right change, I still think it's a good idea to look at [the Commit link](https://github.com/rbenv/rbenv/commit/5287e2ebf46b8636af653c1c61d4dc0dffd65796){:target="_blank" rel="noopener"} too:

<p style="text-align: center">
  <a href="/assets/images/gh-commit-for-issue-528.png" target="_blank">
    <img src="/assets/images/gh-commit-for-issue-528.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Code for Github issue on speeding up rbenv by dynamically loading a compiled command">
  </a>
</p>

Here we see that the original code only had one definition of the `abs_dirname` function.  This commit added a 2nd definition, as well as the `if/else` logic that checks if the `realpath` re-mapping is successful.  If that re-mapping fails, we use the old `abs_dirname` function as before.

I'm still not sure what the difference is between the old and new versions of `realpath`, but I think we can safely assume that the only difference is that it uses a faster algorithm, not that it actually has different output.  If there were such a difference, the dynamic library might well be unsafe to use as a substitute.

Great!  This makes way more sense now.  Before moving on, let's roll our local copy of the repo forward, back to the one we originally cloned.  The SHA for that commit is `c4395e58201966d9f90c12bd6b7342e389e7a4cb`.  If you don't have this SHA saved under a branch name yet, you'll have to do something like:

```
git checkout c4395e58201966d9f90c12bd6b7342e389e7a4cb
```

For the sake of convenience, I have that SHA checked out under the branch name `impostor`, so all I have to do is:

```
$ git co impostor
```

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
