Next few lines of code:

```
command="$1"
case "$command" in
...
esac
```

Here's where we get to the meat of this file.  We're grabbing the first argument sent to the `rbenv` command, and we're deciding what to do with it via a `case` statement.  Everything else we've done in this file, from loading plugins to setting up helper functions like `abort`, has led us to this point.  The internals of that case statement will dictate how RBENV responds to the command the user has entered.

Let's take each branch of the `case` statement in turn:

## Typing `rbenv` with no arguments

```
"" )
  { rbenv---version
    rbenv-help
  } | abort
  ;;
```


The `"" )` syntax represents our first case in the case statement.  This branch of the case statement will execute if `$command` matches the empty string (i.e. if the user just types `rbenv` by itself, with no args).

In that event, we call the `rbenv—version` and `rbenv-help` scripts.  The output of those commands is piped to the `abort` function, which will send the output to `stderr`.  It also returns a non-zero exit code, which implies that passing `""` to `rbenv` is a non-happy path.  We can assume this is also true any time we see the `abort` function.

If we go into our terminal and type `rbenv` with no args, we see this happen:

```
$ rbenv

rbenv 1.2.0-16-gc4395e5
Usage: rbenv <command> [<args>]

Some useful rbenv commands are:
   commands    List all available rbenv commands
   local       Set or show the local application-specific Ruby version
   global      Set or show the global Ruby version
   shell       Set or show the shell-specific Ruby version
   install     Install a Ruby version using ruby-build
   uninstall   Uninstall a specific Ruby version
   rehash      Rehash rbenv shims (run this after installing executables)
   version     Show the current Ruby version and its origin
   versions    List installed Ruby versions
   which       Display the full path to an executable
   whence      List all Ruby versions that contain the given executable

See `rbenv help <command>' for information on a specific command.
For full documentation, see: https://github.com/rbenv/rbenv#readme

$ echo "$?"

1
```

We see the following:

 - The output of `rbenv --version` (aka the version number) prints out, followed by:
 - The output of `rbenv help` (aka info on how the `rbenv` command is used, along with its syntax and its possible arguments).

 If we then type `echo "$?"` immediately after that to print the last exit status, we see `1` print out.

Pretty straight-forward.

## Typing `rbenv -v` or `rbenv --version`

Next case branch is:

```
-v | --version )
  exec rbenv---version
  ;;
```

This time we're comparing `$command` against two values instead of just one: `-v` or `--version`.  If it matches either pattern, we `exec` the `rbenv---version` script, which is just a one-line output of (in my case) "rbenv 1.2.0":

```
 $ rbenv -v

rbenv 1.2.0-16-gc4395e5

$ rbenv --version

rbenv 1.2.0-16-gc4395e5
```

## Typing `rbenv -h` or `rbenv --help`

Next case branch is:

```
-h | --help )
  exec rbenv-help
  ;;
```
Again, two patterns to match against.  If the user types `rbenv -h` or `rbenv –help`, we just run the `rbenv-help` script:

```
$ rbenv -h

Usage: rbenv <command> [<args>]

Some useful rbenv commands are:
   commands    List all available rbenv commands
   local       Set or show the local application-specific Ruby version
   global      Set or show the global Ruby version
   shell       Set or show the shell-specific Ruby version
   install     Install a Ruby version using ruby-build
   uninstall   Uninstall a specific Ruby version
   rehash      Rehash rbenv shims (run this after installing executables)
   version     Show the current Ruby version and its origin
   versions    List installed Ruby versions
   which       Display the full path to an executable
   whence      List all Ruby versions that contain the given executable

See `rbenv help <command>' for information on a specific command.
For full documentation, see: https://github.com/rbenv/rbenv#readme
```

This is actually the same output we saw from typing `rbenv` with no arguments, except we don't see the version number here.

Again, no real surprises.

## The default case

Next up is:

```
* )
...;;
```

The `* )` line is the catch-all / default case branch.  Any `rbenv` command that wasn't captured by the previous branches, including real commands (`rbenv version`, `rbenv local`, etc.), will be captured by this branch.

How we handle the user's input is determined by what's inside the branch, starting with the next line.

### Getting the filepath for the user's command

```
  command_path="$(command -v "rbenv-$command" || true)"
```

Here we're declaring a variable called `command_path`, and setting its value equal to the result of a response from a command substitution.  That command substitution is **either**:

 - the result of `command -v "rbenv-$command"`, or (if there is no result)
 - the simple boolean value `true`.

We saw the same `|| true` syntax [earlier in this file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L46){:target="_blank" rel="noopener"}.  It means that we don't want a failure of `command -v "rbenv-$command"` to trigger an exit of this script if it errors out.

The value of the command substitution depends on what `command -v "rbenv-$command` evaluates to.  It might be a bit confusing to read, because `command` is the name of a shell builtin, but `$command` is the name of a shell variable that we declared earlier.

If we run `help command` to see what this shell builtin does, we get:

```
bash-3.2$ help command

command: command [-pVv] command [arg ...]
    Runs COMMAND with ARGS ignoring shell functions.  If you have a shell
    function called `ls', and you wish to call the command `ls', you can
    say "command ls".  If the -p option is given, a default value is used
    for PATH that is guaranteed to find all of the standard utilities.  If
    the -V or -v option is given, a string is printed describing COMMAND.
    The -V option produces a more verbose description.
```

So calling `command ls` is the same as calling `ls`.  I could see this being useful if the command you want to run is stored in a variable or an argument, and therefore is set at runtime.  For example:

```
$ run_command() {
  command "$1" "$2"
}

$ run_command pwd

/Users/myusername/.rbenv

$ run_command ls -la

total 80
drwxr-xr-x  19 myusername  staff    608 Apr 25 11:22 .
drwxr-x---+ 96 myusername  staff   3072 Apr 28 10:53 ..
drwxr-xr-x  14 myusername  staff    448 Apr 27 10:56 .git
drwxr-xr-x   3 myusername  staff     96 Apr 25 11:22 .github
-rw-r--r--   1 myusername  staff     97 Apr 25 11:22 .gitignore
-rw-r--r--   1 myusername  staff     35 Apr 25 11:22 .vimrc
-rw-r--r--   1 myusername  staff   3390 Apr 25 11:22 CODE_OF_CONDUCT.md
...
```

As the `help` description mentions, adding the `-v` flag results in a printed description of the command you're running.  When I pass `-v` to `command ls` in my terminal, I see `/bin/ls` *instead of* the regular output of the `ls` command.

So in our case, if we type `rbenv version` in our terminal, then this line of code will evaluate to:

```
command_path="$(command -v "rbenv-version" || true)"
```

Since [we loaded `libexec` into `$PATH` earlier](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79){:target="_blank" rel="noopener"}, we're able to run the `rbenv-version` file as an executable, which means `command -v rbenv-version` will return `/Users/myusername/.rbenv/libexec/rbenv-version` on my machine, and this is the value that would be stored in `command_path`:

```
$ PATH="$(pwd)/libexec:$PATH"

$ command -v rbenv-version

/Users/myusername/.rbenv/libexec/rbenv-version
```

If we had typed `rbenv foobar` or another known-invalid command, then `command -v rbenv-foobar` would have returned nothing, in which case we would store the boolean value `true` in `command_path`:

```
$ command -v rbenv-foobar

$
```

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That knowledge is useful when interpreting our next line of code:

```
if [ -z "$command_path" ]; then
...
fi
```

In other words, if there is no valid command path corresponding to the user's input, then we execute the code inside this `if` block.

That code is:

```
if [ "$command" == "shell" ]; then
  abort "shell integration not enabled. Run \`rbenv init' for instructions."
else
  abort "no such command \`$command'"
fi
```

So if the user's input was the string "shell", then we abort with one error message (`shell integration not enabled. Run 'rbenv init' for instructions.`).

We would reach this branch if we tried to run `rbenv shell` before adding `eval "$(rbenv init - bash)"` to our `~/.bashrc` config file (if we're using `bash` as a shell) or `eval "$(rbenv init - zsh)"` to our `~/.zshrc` file (if we're using `zsh` as a shell).  In this case, `$command_path` would be empty.

On my machine, I have the above `rbenv init` command added to my `~/.zshrc` file, so I can't reproduce this error in `zsh`.  I don't have the equivalent line added to my `~/.bashrc` file, however, so if I open up a `bash` shell and type `rbenv shell`, I get the following:

```
bash-3.2$ rbenv shell

rbenv: shell integration not enabled. Run `rbenv init' for instructions.
```

We'll get to why `$command_path` has a value in my `zsh` and no value in my `bash` later, when we examine the `rbenv-init` file in detail.

In our `else` clause (i.e. if `$command` does *not* equal `"shell"`), we abort with a `no such command` error.  I'm able to reproduce the `else` case by simply running `rbenv foobar` in my terminal.

```
bash-3.2$ rbenv foobar

rbenv: no such command `foobar'
```

So to sum up this entire `if` block- its purpose appears to be to handle any sad-path cases, specifically:

 - if the user enters a command that isn't recognized by RBENV, or
 - if the user tries to run `rbenv shell` without having enabled shell integration by adding the right code to their shell's configuration file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on to the next line of code:

```
shift 1
```
This just shifts the first argument off the list of `rbenv`'s arguments.  The argument we're removing was previously stored in the `command` variable, and we've already processed it so we don't need it anymore.

### Printing `help` instructions for the user's command

Next line of code:

```
if [ "$1" = --help ]; then
  ...
else
  ...
fi
;;
```
Now that we've shifted off the `command` argument in the previous line, we have a new value for `$1`.  Here we check whether that new first arg is equal to the string `--help`.  An example of this would be if the user runs `rbenv init --help`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next block of code:

```
if [[ "$command" == "sh-"* ]]; then
  echo "rbenv help \"$command\""
else
  exec rbenv-help "$command"
fi
```

In the first half of this nested conditional, we check whether the user entered a command which starts with "sh-".  If they did, **and** if they followed that command with `--help`, then we print "rbenv help "$command" to STDOUT.

I try this in my terminal by typing "rbenv sh-shell –help", and I see the following:

```
$ rbenv sh-shell --help

rbenv help "sh-shell"
```

Why would we print `rbenv help "sh-shell"` to the screen, instead of some user-friendly instructions?  At this point we know enough to tell the user which command they *should have* run.  Why don't we just run it for them and save them a step?

I find [the PR which added this block of code](https://github.com/rbenv/rbenv/pull/914){:target="_blank" rel="noopener"} and read up on it.  Turns out the code used to look like this:

```
if [ "$1" = --help ]; then
  exec rbenv-help "$command"
else
  exec "$command_path" "$@"
fi
```

This is much closer to what I'd expect, because in both cases we're calling `exec`, as opposed to `echo` in the `if` branch and `exec` in the `else` branch.

But according to the PR description, this caused the `rbenv shell --help` command to trigger an error.  I run `git checkout` on the commit just before this PR was merged (SHA is `9fdce5d069946417d481fd878c5c005db5b4539c`), and try to reproduce the error:

```
$ rbenv shell --help

(eval):2: parse error near `\n'
```

OK, so what caused this error?

### Making use of `RBENV_DEBUG`

I remember we have the ability to run in verbose mode by passing in the `RBENV_DEBUG` environment variable, so I try running `RBENV_DEBUG=1 rbenv shell --help`.  It results in a ton of output of course, and the last few lines of that output are:

```
...
+ [rbenv-help:124] echo
+ [rbenv-help:125] echo 'Sets a shell-specific Ruby version by setting the `RBENV_VERSION'\''
environment variable in your shell. This version overrides local
application-specific versions and the global version.

<version> should be a string matching a Ruby version known to rbenv.
The special version string `system'\'' will use your default system Ruby.
Run `rbenv versions'\'' for a list of available Ruby versions.'
+ [rbenv-help:126] echo
(eval):2: parse error near `\n'
```

Here we can see the lines of code that are reached (`rbenv-help:124`, `rbenv-help:125`, and `rbenv-help:126`).

For comparison, I run this same command but with `rbenv version` instead of `rbenv shell`, and the last few lines of the verbose output are:

```
...
+ [rbenv-help:124] echo

+ [rbenv-help:125] echo 'Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'\''.'
Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
+ [rbenv-help:126] echo
```

The same lines of code are logged, but no `(eval):2` error at the end.  So I **think** the problem must be in the code that we're trying to `exec`, in the line `exec rbenv-help "$command"`.

I wanted to see what exactly this code was.  So I added the following `echo` statement above it:

```
if [ "$1" = --help ]; then
    echo "Look here" >&2                     # added this line
    echo "--------" >&2                      # added this line
    echo "$(exec rbenv-help "$command")" >&2      # added this line
    echo "--------" >&2                      # added this line
    exec rbenv-help "$command"
  else
```

I'm capturing the output of the same command that we're trying to run, sending it to `echo`, and redirecting `stdout` to `stderr` so that my `echo` statement won't be mis-interpreted as a command to run, by the caller of this code.  I also `echo` a divider line, so we can know where my printed statements end and the code takes over again.

Here's the result when I run `rbenv shell --help`:

```
$ rbenv shell --help

Look here
--------
Usage: rbenv shell <version>
       rbenv shell --unset

Sets a shell-specific Ruby version by setting the `RBENV_VERSION'
environment variable in your shell. This version overrides local
application-specific versions and the global version.

<version> should be a string matching a Ruby version known to rbenv.
The special version string `system' will use your default system Ruby.
Run `rbenv versions' for a list of available Ruby versions.
--------
(eval):2: parse error near `\n'
```

The result is a printed set of usage instructions which are meant for humans to read (not for `bash` to run), followed by the reported error.

But that's confusing to me, because no such error occurs when we run the same code for other commands, such as `rbenv version`.  When I run `rbenv version --help`, I see this:

```
$ rbenv version --help
Look here
--------
Usage: rbenv version

Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
--------
Usage: rbenv version

Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
```

We see the usage instructions printed a 2nd time, in addition to the first time that we expected, because that's what is supposed to happen instead of the `(eval):2` error.

So why does this error only happen with `rbenv shell`, not with `rbenv version`?  Why is the code trying to `eval` usage instructions for `shell`, but not `version`?

OK, I'll stop here and admit that I cheated a little.  I initially was stumped by this question, so I decided to punt on it for the time being and continued onward.  Then, months later when I was re-reading and editing this post, I leveraged the knowledge I had gained during those months to deduce what is happening here.

TL;DR- one of the things that RBENV does when you add that `eval "$(rbenv init -)"` string to your shell config is that it creates a shell function (also called `rbenv`).  When you run `rbenv` commands from inside your terminal, you're **not** running the `rbenv` bash script, at least not directly.  Instead, you're **actually** running *this shell function*, which in turn calls the `rbenv` script.  You can verify this by running `which rbenv` from your terminal:

```
$ which rbenv

rbenv () {
	local command
	command="$1"
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	case "$command" in
		(rehash | shell) eval "$(rbenv "sh-$command" "$@")" ;;
		(*) command rbenv "$command" "$@" ;;
	esac
}
```

Instead of printing `path/to/file/rbenv.bash` or something similar, it prints out a complete shell function.

This shell function gets defined by the `eval "$(rbenv init -)"` call in your shell config, each time you open a new terminal tab.  Since UNIX will check for shell functions before it checks your `PATH` for any commands, this is the first implementation of the `rbenv` command that it finds, and so this is what gets run when you type `rbenv` into your terminal.

As part of its logic, the shell function executes [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147-L152){:target="_blank" rel="noopener"}, which checks if the command that the user is running begins with `sh-`.  If it does, it runs `eval` plus the name of the command with its `sh-` prefix.  Otherwise, it runs the command via the `command` command (which we discussed earlier).  [This was also the case](https://github.com/rbenv/rbenv/blob/9fdce5d069946417d481fd878c5c005db5b4539c/libexec/rbenv-init#L151){:target="_blank" rel="noopener"} at the the time [the error was reported](https://github.com/rbenv/rbenv/pull/914){:target="_blank" rel="noopener"}.

It's **this** call to `eval` that is erroring out.  We can prove that to ourselves by changing that block of code in `rbenv-init` to look like the following:

```
set -e                                        # I added this line
  case "\$command" in
  ${commands[*]})
    echo 'just before eval' >&2               # I added this line
    eval "\$(rbenv "sh-\$command" "\$@")"
    echo 'just after eval' >&2                # I added this line
    ;;
  *)
```

I added the call to `set -e` before the `case` statement (so that the code will exit immediately if the `eval` code throws an error), as well as the two `echo` statements, one before `eval` and one after.  I then `source` my `~/.zshrc` file so that these changes take effect, and I run `which rbenv` to confirm that they appear in the updated shell function:

```
$ which rbenv

rbenv () {
	local command
	command="$1"
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	set -e
	case "$command" in
		(rehash | shell) echo 'just before eval' >&2
			eval "$(rbenv "sh-$command" "$@")"
			echo 'just after eval' >&2 ;;
		(*) command rbenv "$command" "$@" ;;
	esac
}
```

Then, when I run `rbenv shell --help`, I see the following:

```
$ rbenv shell --help

just before eval
(eval):2: parse error near `\n'

[Process completed]
```

I see "just before eval", but **not** "just after eval".  Since we added the `set -e` option to our shell function, the code exited after the first error that it encountered.  Since we only saw the first of the two `echo` statements immediately before and after our call to `eval`, it **must** have been this call to `eval` which threw an error.

But I'm still wondering why commands prefixed with `sh-` use `eval`, while those without the prefix use `command`.  I decide to look up the command which introduced this `if/else` block.  After some digging, I find it [here](https://github.com/rbenv/rbenv/pull/57){:target="_blank" rel="noopener"}.  It says:

> Regular commands pass though as you'd expect. But special shell commands prefixed with sh- are called, but its result is evaled in the current shell allowing them to modify environment variables.

OK, so the idea is to give the `sh-` commands the ability to modify environment variables.  I suspect that this wouldn't have been possible if we had used the same `command` strategy that non-`sh` commands are run with.  To test this, I run an experiment.

### Experiment- can `command` set environment variables?

I write a script named `sh-foo`, containing the following code:

```
#!/usr/bin/env bash

echo "export FOO='foo bar baz'"
```

This script is designed to mimic the `sh-` scripts that are called using `eval`.

I write a 2nd script named `bar`, containing the following code:

```
#!/usr/bin/env bash

export BAR="bar bazz buzz"
```

This script is designed to mimic the non-`sh` scripts, which are called using `command`.

In my terminal, I run the following:

```
$ echo "$FOO"

$ PATH="$(pwd):$PATH"

$ which sh-foo
/Users/richiethomas/Workspace/OpenSource/impostorsguides.github.io/sh-foo

$ eval `sh-foo`

$ echo "$FOO"

foo bar baz
```

We can see that running `sh-foo` via the `eval` command had the effect of setting a value for the `"$FOO"` env var, where there was no value beforehand.

Next, I try running the `bar` script:

```
 $ echo "$BAR"

$ which bar

/Users/richiethomas/Workspace/OpenSource/impostorsguides.github.io/bar

$ command bar

$ echo "$BAR"

$
```

This time, the environment variable was **not** set.  This proves that using `command` does not result in the setting of the environment variable.

We'll see later on that scripts which are prefaced with `sh-` have the convention of `echo`ing lines of code to `stdout`.  Now we understand why this is the case- that output is executed by the caller using `eval`, because this is the only way for child scripts to affect the environment variables of a parent script.

More generally, this is also a cool design pattern for the case where you need to run a child script which modifies environment variables, and have those modifications be available to the parent script.  We can write the child script such that it `echo`s the code for the modifications of the env vars, and have our parent script `eval` the code that is `echo`'ed.  This is a work-around we can use if we're ever stymied by the fact that env var changes in a child script aren't available to the parent.

### Aside- backticks vs. command substitution

FYI, [according to StackOverflow](https://web.archive.org/web/20230411191359/https://stackoverflow.com/questions/9405478/command-substitution-backticks-or-dollar-sign-paren-enclosed){:target="_blank" rel="noopener"}, the following syntax...

```
`sh-foo`
```

 ...is basically interchangeable with the syntax:

 ```
 "$(sh-foo)"
 ```

In other words, surrounding a command with backticks is the same as using the `"$(...)"` command substitution syntax.  I used backticks to keep my experiment code as similar as possible to the `eval` line of the `rbenv` shell function.

## Happy path- executing a regular command

Next (and final!) line of code in this file:

```
  else
    exec "$command_path" "$@"
```

This is the line of code which actually executes the command that the user typed.  The `$@` syntax expands into [the flags or arguments](https://web.archive.org/web/20230319115333/https://stackoverflow.com/questions/3898665/what-is-in-bash){:target="_blank" rel="noopener"} we pass to that command.

That's it!  That's the entire `rbenv` file.  What should we do next?

Normally I'd want to copy the order in which the files appear in the "libexec" directory.  But given what we saw with "rbenv-init" and how it has a big effect on how the "rbenv" file is called, I think it makes more sense to start there and come back to the next file ("rbenv–-version") afterward.
