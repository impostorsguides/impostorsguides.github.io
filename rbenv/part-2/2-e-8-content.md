

Next few lines of code:

```
if [ -z "${RBENV_ROOT}" ]; then
  RBENV_ROOT="${HOME}/.rbenv"
else
  RBENV_ROOT="${RBENV_ROOT%/}"
fi
export RBENV_ROOT
```

## Setting `RBENV_ROOT`

We've seen the `-z` flag for the `[` command before- it checks whether a value has a length of zero.

So if the `RBENV_ROOT` variable has not been set, then we set it equal to `${HOME}/.rbenv`, i.e. the `.rbenv` hidden directory located as a subdir of our UNIX home directory.  If it *has* been set, then we just trim off any trailing "/" character.  Then we export it as a environment variable.

The purpose of this code seems to be ensuring that `RBENV_ROOT` is set to some value, whether it's the value that the user specified or the default value.

What does `$RBENV_ROOT` do?  According to [the "Environment Variables" section](https://github.com/rbenv/rbenv#environment-variables){:target="_blank" rel="noopener"} of the README, it:

> Defines the directory under which Ruby versions and shims reside.

And what does `$HOME` do?  This resolves to the root directory of a particular user (specifically, you) in your `bash` terminal.  When you see me type `~/Workspace/OpenSource` in some of the example code, the `~` (aka tilde) character expands to `"$HOME"`, or `/Users/myusername`.

## Setting `RBENV_DIR`

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
```

The code`[[ $RBENV_DIR == /* ]]` is an attempt to [pattern-match](https://web.archive.org/web/20220628171954/https://unix.stackexchange.com/questions/72039/whats-the-difference-between-single-and-double-equal-signs-in-shell-compari){:target="_blank" rel="noopener"}, **not** an equality check.  The particular pattern that we're matching against returns true if `$RBENV_DIR` starts with the `/` character.  If the pattern does **not** match, we set `RBENV_DIR` equal to `"$PWD/$RBENV_DIR"`.

Since a leading `/` in a filepath means we're dealing with an absolute path, this means we're checking to see if `$RBENV_DIR` is a string that represents an absolute path.  And since `"$PWD"` is always an absolute path pointing to our current directory, this line of code means that:

 - We check whether `RBENV_DIR` is an absolute path.
 - If it isn't, we update its value to be prefixed with the absolute path to our current directory.

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

This sequence of code is doing two things:

 - It ensures that the value we store in `RBENV_DIR` is a valid directory, by attempting to `cd` into it and aborting if this fails.
 - It [normalizes](https://web.archive.org/web/20220619163902/https://www.linux.com/training-tutorials/normalizing-path-names-bash/){:target="_blank" rel="noopener"} the value of `RBENV_DIR`, "...remov(ing) unneeded /./ and ../dir sequences."

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
export RBENV_DIR
```
Here we just make the result of our `RBENV_DIR` setting into an environment variable, so that it's available elsewhere in the codebase.

## Setting `RBENV_ORIG_PATH`

Next line of code is:

```
[ -n "$RBENV_ORIG_PATH" ] || export RBENV_ORIG_PATH="$PATH"
```

Here we check if `$RBENV_ORIG_PATH` has been set already.  If not, we set it equal to our current path and export it as an environment variable.

Nothing too special there.  Let's move on.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

