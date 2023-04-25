[Next line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23){:target="_blank" rel="noopener"} is:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

So that I don't forget, I write down a few questions I have at this point:

 - What does the `enable` command do?
 - What does its `-f` flag mean?
 - What are the command's positional arguments?
 - What kind of file extension is `.dylib`?  What does that imply about the contents of the file?
 - What does `2>/dev/null` do?

I'll try to answer these one-by-one.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

I start by typing both `man enable` and `help enable` in my terminal, but each time I see `No manual entry for enable`.

Luckily, [the first result](https://web.archive.org/web/20220529121055/https://ss64.com/bash/enable.html){:target="_blank" rel="noopener"} when I Google "enable command bash" looks like a good one, even if it's not part of the official docs:

<p style="text-align: center">
  <img src="/assets/images/enable-docs-12mar2023-157pm.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="Docs on the `enable` keyword">
</p>

This actually answers my first three questions:

 - What does the `enable` command do?
    - The `enable` command can take builtin shell commands (like `which`, `echo`, `alias`, etc.) and turn them on or off.
    - The link mentions that this could be useful if you have a script which shares the same name as a builtin command, and which is located in one of your `PATH` directories.
    - Normally, the shell would check for builtin commands first, and only search in `PATH` if no builtins were found.
    - You can ensure your shell won't find any builtin command by disabling the builtin using the `enable` command.
    - [Here's a link explaining more](https://web.archive.org/web/20230407091137/https://www.oreilly.com/library/view/bash-cookbook/0596526784/ch01s09.html){:target="_blank" rel="noopener"}, from O'Reilly's Bash Cookbook.

 - What does the `-f` flag do?
    - You would pass this flag if you want to change the source of your new command from its original source (the builtin) to a file whose path you specify after the `-f` flag.
    - In other words, you want to replace the builtin command with your home-made version.

 - What are the command's positional arguments?
    - In the case of our line of code, the first positional argument is the filepath containing the new version of the command we're over-riding.
    - The 2nd positional argument is the name of the command we're over-riding.

Out of curiosity, I tried to see if I could simply write a script and use it to overwrite a known-valid builtin.

### Experiment- trying to over-write a builtin with `enable -f`

I write a simple `bash` script called `./foo`, which just prints out "Hello world":

```
#!/usr/bin/env bash

echo "Hello world"
```

I `chmod +x` the script so that it's executable, and I try using it to overwrite the `ls` command:

```
$ chmod + x ./foo

$ enable -f ./foo ls
```

Unfortunately, I get the following error:

```
bash: enable: cannot open shared object ./foo: dlopen(./foo, 0x0001):
tried: './foo' (relative path not allowed in hardened program),
'/System/Volumes/Preboot/Cryptexes/OS./foo' (no such file), '/usr/lib/./foo'
(no such file, not in dyld cache)
```

The phrase `relative path not allowed in hardened program` stands out to me.  I try replacing `./foo` with `$(pwd)/foo`:

```
$ enable -f $(pwd)/foo ls

bash: enable: cannot open shared object /Users/myusername/Workspace/OpenSource/foo:
dlopen(/Users/myusername/Workspace/OpenSource/foo, 0x0001):
tried: '/Users/myusername/Workspace/OpenSource/foo' (not a mach-o file),
'/System/Volumes/Preboot/Cryptexes/OS/Users/myusername/Workspace/OpenSource/foo'
(no such file), '/Users/myusername/Workspace/OpenSource/foo' (not a mach-o file)
```

The error `not a mach-o file` tells me that I've tried to pass `enable` a file format that it doesn't expect.  I just passed a simple `bash` script, but it looks like it expects something called [a "mach-o file"](https://web.archive.org/web/20230314194621/https://en.wikipedia.org/wiki/Mach-O){:target="_blank" rel="noopener"}:

> Mach-O, short for Mach object file format, is a file format for executables, object code, shared libraries, dynamically-loaded code, and core dumps.

More details from [Apple's website](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html){:target="_blank" rel="noopener"}:

> Mach-O is the native executable format of binaries in OS X and is the preferred format for shipping code.

At this point, I want to say that my experiment was a temporary failure.  For now, it's enough to say that:

 - this `if`-clause is true if the `enable -f` command succeeds.
 - This, in turn, will only happen if the `libexec/rbenv-realpath.dylib` file exists and is in the right format.
 - I happen to know from already reading the entire codebase that this file will be generated if the user has run `make` in [RBENV's `src/` directory](https://github.com/rbenv/rbenv/tree/c4395e58201966d9f90c12bd6b7342e389e7a4cb/src){:target="_blank" rel="noopener"}.

 I'll try this experiment again later, when I read through that directory.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

My 4th out of 5 questions was "What does `2>/dev/null` do?"

According to [StackOverflow](https://web.archive.org/web/20220801111727/https://askubuntu.com/questions/350208/what-does-2-dev-null-mean){:target="_blank" rel="noopener"}:

 - The `2>` tells the shell to take the output from file descriptor #2 (aka `stderr`) and send it to the destination specified after the `>` character.
 - Further, `/dev/null` is the null device.  It's a special file on your UNIX-based OS which takes any input you want and throws it away.
 - So here we're suppressing any error which is output by the `enable` command, rather than showing it.

If I had to guess, I'd say we're doing that because this is part of an `if` check, and if the `enable` command fails, we don't want to see the error, we just want to move on and execute the code in the `else` block.

### Experiment- `/dev/null`

Directly in my terminal, I type the following:

```
$ echo "Hello world"

Hello world
```

As expected, we see "Hello world" printed to the screen.  Next, I redirect the output which would normally go to `stdout`, and into `/dev/null`:

```
$ echo "Hello world" > /dev/null

$
```

This time, no output appeared.

To check whether I'm able to print `/dev/null` and see the output which I redirected there, I do the following:

```
$ cat /dev/null

$
```

No output in that file.  So it looks like `/dev/null` really is the black hole we thought it was.

## Dynamic Libraries

Final question: what kind of file extension is `.dylib`, and what does that imply about the contents of the file?

I Googled "what is dylib extension" and read a few different results ([here](https://web.archive.org/web/20211023152003/https://fileinfo.com/extension/dylib){:target="_blank" rel="noopener"} and [here](https://web.archive.org/web/20211023142331/https://www.lifewire.com/dylib-file-2620908){:target="_blank" rel="noopener"}, in particular).  They tell me that:
 - "dylib" is a contraction of "dynamic library", and that this means it's a library of code which can be loaded at runtime (aka "dynamically", aka "while the program is running").
 - Loading things dynamically (as opposed to eagerly, when the shell or the application which relies on it is first booted up) means you can wait until you actually need the library before loading it.
 - This, in turn, means you're not taking up memory with code that you don't yet know you need.

So to summarize:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

Means:

 - If we're successful in replacing the `realpath` command with a new implementation which lives in the `libexec/rbenv-realpath.dylib` file, then do the thing inside the `if` block.
 - If we're *not* successful in doing that:
    - ignore any `stderr` output rather than printing it to the screen, and
    - do the thing inside the `else` block.

## The `realpath` command

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

To answer question #1, I decide to search the repo's `git` history.  I do the `git blame` dance that we used earlier, when researching the `if`-block in the shim file.  I have to go through a few rounds of that, but eventually I find the SHA I want is is `5287e2eb`.  I plug this into Github's search history and see the following:

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

We still don't know **why** the dynamic library version of `realpath` is faster than the old version, but I think we can safely assume that the only difference is that it uses a faster algorithm, not that it actually has different output.  If there were such a difference, the dynamic library might well be unsafe to use as a true "apples-to-apples" substitute.

Let's move on.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
