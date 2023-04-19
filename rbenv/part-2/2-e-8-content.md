

Next few lines of code:

```
if [ -z "${RBENV_ROOT}" ]; then
  RBENV_ROOT="${HOME}/.rbenv"
else
  RBENV_ROOT="${RBENV_ROOT%/}"
fi
export RBENV_ROOT
```

We've seen the `-z` flag for `[` before- it checks whether a value has a length of zero.

So if the RBENV_ROOT variable has not been set, then we set it equal to "${HOME}/.rbenv", i.e. the ".rbenv" hidden directory located as a subdir of our UNIX home directory.  If it *has* been set, then we just trim off any trailing "/" character.  Then we export it as a environment variable.

The purpose of this code seems to be ensuring that `RBENV_ROOT` is set to some value, whether it's the value that the user specified or the default value.

TODO: add info on the `HOME` environment variable- where it's set, etc.

TODO: add info on `RBENV_ROOT` from the README file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
if [ -z "${RBENV_DIR}" ]; then
  RBENV_DIR="$PWD"
else
...
fi
export RBENV_DIR
```

Let's examine everything *except* the code inside the `else` block, which we'll look at next.

This block of code is similar to the block before it.  We check if a variable has not yet been set (in this case, `RBENV_DIR` instead of `RBENV_ROOT`).  If it's not yet set, then we set it equal to the current working directory.  Once we've exited the `if/else` block, we export `RBENV_DIR` as an environment variable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Now the code inside the `else` block:

```
  [[ $RBENV_DIR == /* ]] || RBENV_DIR="$PWD/$RBENV_DIR"
  cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"
  RBENV_DIR="$PWD"
  cd "$OLDPWD"
```

The first line of code tries to execute one piece of code (`[[ $RBENV_DIR == /* ]]`), and if that fails, executes a 2nd piece (`RBENV_DIR="$PWD/$RBENV_DIR"`).  The first command it tries is a pattern-match, [according to StackExchange](https://web.archive.org/web/20220628171954/https://unix.stackexchange.com/questions/72039/whats-the-difference-between-single-and-double-equal-signs-in-shell-compari){:target="_blank" rel="noopener"}:

> `[[ $a == $b ]]` is not comparison, it's pattern matching.

The particular pattern that we're matching against returns true if `$RBENV_DIR` **starts with** the `/` character.

Hypothesizing that we're checking to see if `$RBENV_DIR` is a string that represents an absolute path, I write the following test script:

```
#!/usr/bin/env bash

foo='/foo/bar/baz'

if [[ "$foo" == /* ]]; then
  echo "True"
else
  echo "False"
fi
```

I get `True` when I run this script, and `False` when I remove the leading `/` char.  So we can confidently say that this first line of code appends the absolute path to the current working directory to the front of `RBENV_DIR`, if that variable doesn't start with a `/`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next block of code is:

```
cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"
RBENV_DIR="$PWD"
cd "$OLDPWD"
```

Here we're attempting to `cd` into our latest version of `$RBENV_DIR`, sending any error message to `/dev/null`, and aborting with a helpful error message if that `cd` attempt fails.  We then set the value of `RBENV_DIR` to the value of `$PWD` (the directory we're currently in), before `cd`ing into `OLDPWD`, an environment variable [that `bash` maintains ](https://web.archive.org/web/20220127091111/https://riptutorial.com/bash/example/16875/-oldpwd){:target="_blank" rel="noopener"} which comes with `bash` and which stores the directory we were in prior to our current one:

```
$ cd /home/user

$ mkdir directory

$ echo $PWD

/home/user

$ cd directory

$ echo $PWD

/home/user/directory

$ echo $OLDPWD

/home/user
```

I'm honestly not sure why we're doing this.  Assuming we've reached this line of code, that means we've just `cd`'ed into our current location using the same value of `$RBENV_DIR` that we currently have.  So (to me) this just seems like setting the variable's value to the value it already contains.  Given the previous `cd` command succeeded, when would the value of `$PWD` be anything different from the current value of `RBENV_DIR`?

After submitting [this PR](https://github.com/rbenv/rbenv/pull/1493){:target="_blank" rel="noopener"}, I discovered the answer.  This sequence of code is doing two things:

 - It ensures that the value we store in `RBENV_DIR` is a valid directory, by attempting to `cd` into it and aborting if this fails.
 - It [normalizes](https://web.archive.org/web/20220619163902/https://www.linux.com/training-tutorials/normalizing-path-names-bash/){:target="_blank" rel="noopener"} the value of `RBENV_DIR`, "...remov(ing) unneeded /./ and ../dir sequences."

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
export RBENV_DIR
```
Here we just make the result of our `RBENV_DIR` setting into an environment variable, so that it's available elsewhere in the codebase.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
[ -n "$RBENV_ORIG_PATH" ] || export RBENV_ORIG_PATH="$PATH"
```

Here we check if `$RBENV_ORIG_PATH` has been set yet.  If not, we set it equal to our current path and export it as an environment variable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
shopt -s nullglob
```

I've never seen the `shopt` command before.  I try looking up the docs on my machine, but I get `No manual entry for shopt` for `man` and `shopt not found` for `help`.

I try Google, and [the first result](https://web.archive.org/web/20220815163336/https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html){:target="_blank" rel="noopener"} is from GNU.org, which says:

```
shopt

shopt [-pqsu] [-o] [optname ...]

Toggle the values of settings controlling optional shell behavior.

...

-s

Enable (set) each optname.
```

[The next Google result](https://web.archive.org/web/20220714115608/https://www.computerhope.com/unix/bash/shopt.htm){:target="_blank" rel="noopener"}, from ComputerHope.com, adds the following:

> On Unix-like operating systems, shopt is a builtin command of the Bash shell that enables or disables options for the current shell session.

It adds that the job of the `-s` flag is:

> If optnames are specified, set those options. If no optnames are specified, list all options that are currently set.

The option name that we're passing is `nullglob`.  Further down, in the descriptions of the various options, I see the following entry for `nullglob`:

> If set, bash allows patterns which match no files to expand to a null string, rather than themselves.

Lastly, [StackExchange](https://unix.stackexchange.com/a/504591/142469){:target="_blank" rel="noopener"} has an example of what would happen before and after `nullglob` is set:

> Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.
>
> ```
> $ echo my*file
> my*file
> $ shopt -s nullglob
> $ echo my*file
>
> $
> ```

This code sets a shell option so that we can change the way we pattern-match against files.  In particular, if a pattern doesn't match any files, it will expand to nothing.  This indicates that we'll be attempting to match files against a pattern in the near future.

To figure out why we're doing this, I dig into the git history using my `git blame / git checkout` dance again.  There's only one issue and one commit.  [Here's the issue](https://github.com/rbenv/rbenv/pull/102){:target="_blank" rel="noopener"} with its description:

> The purpose of this branch is to provide a way to install self-contained plugin bundles into the $RBENV_ROOT/plugins directory without any additional configuration. These plugin bundles make use of existing conventions for providing rbenv commands and hooking into core commands.
>
> ...
>
> Say you have a plugin named foo. It provides an `rbenv foo` command and hooks into the `rbenv exec` and `rbenv which` core commands. Its plugin bundle directory structure would be as follows:
>
>```
>foo/
>  bin/
>    rbenv-foo
>  etc/
>    rbenv.d/
>      exec/
>        foo.bash
>      which/
>        foo.bash
>```
>
> When the plugin bundle directory is installed into `~/.rbenv/plugins`, the `rbenv` command will automatically add `~/.rbenv/plugins/foo/bin` to `$PATH` and `~/.rbenv/plugins/foo/etc/rbenv.d/exec:~/.rbenv/plugins/foo/etc/rbenv.d/which` to `$RBENV_HOOK_PATH`.

I think this clarifies not only the `shopt` line, but the next few lines after that, which we'll look at next.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
