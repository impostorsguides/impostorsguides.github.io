
Link to the code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init){:target="_blank" rel="noopener" }.

## Setup

The first few lines of code are:

```
#!/usr/bin/env bash
# Summary: Configure the shell environment for rbenv
# Usage: eval "$(rbenv init - [--no-rehash] [<shell>])"

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

We see the following:

 - Our shebang, which tells UNIX to interpret the code using Bash.
 - "Summary" and "Usage" comments.  These comments are actually used to print the output of the `rbenv-help` command, as we'll see when we read through that command's code.
 - The `set -e` command, which as we know, tells the shell to stop execution and exit immediately if an error is raised.
 - The last line checks if the `$RBENV_DEBUG` env var is set, and if it is, we turn on `xtrace` mode so that the filename and line of code are printed for each line of code that is executed.

 We'll encounter this code throughout most if not all of the command files.  We'll breeze through future instances of this setup step very quickly.

## Completions Code

Next block of code is:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo -
  echo --no-rehash
  echo bash
  echo fish
  echo ksh
  echo zsh
  exit
fi
```

The first line is a comment which tells us the intention of this code.

The next line is a test which checks whether the first argument to `init` is the string "--complete".  If it is, it just `echo`'s some strings to the screen and then exits.  These strings correspond to the valid arguments that `rbenv init` accepts.

I'm able to reproduce this by running a simple `rbenv init --complete` in my terminal:

```
$ rbenv init --complete

-
--no-rehash
bash
fish
ksh
zsh
```

These arguments correspond to the 4 shells that RBENV supports (Bash, `fish`, `ksh`, and `zsh`), plus the `-` argument and the `--no-rehash` argument, both of which we'll examine later in this file.

## The 'print' and 'no_rehash' variables

Next block of code:

```
print=""
no_rehash=""
for args in "$@"
do
...
done
```
Pretty straightforward.  We're declaring two variables (`print` and `no_rehash`), setting them to empty strings, then iterating over each arg in the list of args sent to `rbenv init`.

Inside the `for` loop, we see:

```
  if [ "$args" = "-" ]; then
    print=1
    shift
  fi

  if [ "$args" = "--no-rehash" ]; then
    no_rehash=1
    shift
  fi
```
For each of the args, we check whether the arg is equal to either the "-" string or the "--no-rehash" string.  If the first condition is true, we set the "print" variable equal to 1.  If the 2nd condition is true, we set the "no_rehash" variable equal to 1.  Otherwise, they remain empty strings.

These variables will be used later in the file.

## Specifying The User's Shell

Next lines of code:

```
shell="$1"
if [ -z "$shell" ]; then
  shell="$(ps -p "$PPID" -o 'args=' 2>/dev/null || true)"
  shell="${shell%% *}"
  shell="${shell##-}"
  shell="${shell:-$SHELL}"
  shell="${shell##*/}"
  shell="${shell%%-*}"
fi
```

We grab the 1st argument, and we store it in a variable named `shell`.  The value we store may be the original value of `"$1"` or a new one, depending on whether `shift` was called in the previous `for` loop.

If that argument was empty, we assume that the user didn't manually specify which shell they're using.  In that case, we set it for them.  We run the command `ps -p "$PPID" -o 'args='`, and then progressively whittle down the value of this output, until we get to just the name of the user's shell.

To see in detail what happens here, I add a bunch of `echo` statements to [this `if`-block](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L35-L42){:target="_blank" rel="noopener" }, so that it looks like this:

```
shell="$1"
>&2 echo "initial shell: $shell"                           # I added this line
if [ -z "$shell" ]; then
  shell="$(ps -p "$PPID" -o 'args=' 2>/dev/null || true)"
  >&2 echo "shell1: $shell"                                # I added this line
  shell="${shell%% *}"
  >&2 echo "shell2: $shell"                                # I added this line
  shell="${shell##-}"
  >&2 echo "shell3: $shell"                                # I added this line
  shell="${shell:-$SHELL}"
  >&2 echo "shell4: $shell"                                # I added this line
  shell="${shell##*/}"
  >&2 echo "shell5: $shell"                                # I added this line
  shell="${shell%%-*}"
  >&2 echo "shell6: $shell"                                # I added this line
fi
```

Since the code I edited is the code for my actual RBENV installation (i.e. it's located at `~/.rbenv/libexec/rbenv-init`), and since I have `eval "$(rbenv init -)"` included in my `~/.zshrc` file, I know that these `echo` statements will be executed if I open a new ZSH tab.

When I do so, I get:

```
Last login: Fri May  5 12:54:42 on ttys020
initial shell:
shell1: -zsh
shell2: -zsh
shell3: zsh
shell4: zsh
shell5: zsh
shell6: zsh
$
```

Since I didn't pass `zsh` to the code `eval "$(rbenv init -)"` in my ZSH config file, we see that the value of `initial shell` is empty, and the remaining `echo` statements for `shell1`, `shell2`, etc. are executed.

If I open `~/.zshrc` and change `eval "$(rbenv init - )"` to `eval "$(rbenv init - zsh)"`, and open another new terminal tab, I see:

```
Last login: Fri May  5 12:55:03 on ttys020
initial shell: zsh
$
```

Since `shell="$1"` stores the string `zsh` (as proven by `initial shell: zsh`), the condition check `if [ -z "$shell" ];` returns false, and the code inside the `if`-block is not executed.

On my machine, the final value of `"$shell"` was known by the time we hit the third parameter expansion (i.e. the value that was `echo`'ed for `shell3`).  This might not be true on everyone's machine, however.  Hence this series of parameter expansions inside that `if`-block, whose purpose is to handle output for `$(ps -p "$PPID" -o 'args=' 2>/dev/null || true)` **regardless of the machine** on which the code is run.

Let's remove the `echo` statements we just added, and move on to the next line of code.

## Grabbing the Root Dir

```
root="${0%/*}/.."
```

In a bash script, both `$0` and `${0}` resolve to the name of the file that's being run.  Adding `%/*` just trims off everything from the final `/` character to the end of the string.  Let's echo a few relevant values to see what we're working with:

```
root="${0%/*}/.."

echo "arg 0 pre-expansion: ${0}" >&2
echo "arg 0 post-expansion: ${0%/*}" >&2
echo "root: $root" >&2
```

Opening a new tab, we see:

```
arg 0 pre-expansion: /Users/myusername/.rbenv/libexec/rbenv-init
arg 0 post-expansion: /Users/myusername/.rbenv/libexec
root: /Users/myusername/.rbenv/libexec/..
```

We see the `rbenv-init` file, its parent directory, and the final value of `$root`.  The name "root" makes sense, because it's the root directory of RBENV.

This variable isn't used until later, when we look for a file whose job is to enable [tab completion](https://web.archive.org/web/20230330150603/https://en.wikipedia.org/wiki/Command-line_completion){:target="_blank" rel="noopener" } in the terminal.  We can ignore `root` for now.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's move on.
