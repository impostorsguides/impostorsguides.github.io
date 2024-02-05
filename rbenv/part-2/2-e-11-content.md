Next few lines of code:

```
command="$1"
case "$command" in
...
esac
```

Here's where we get to the meat of this file.  We grab the first argument sent to the `rbenv` command, and decide what to do with it via a `case` statement.  The internals of that case statement will dictate how RBENV responds to the command the user has entered.

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

In that event, we call the `rbenv—version` and `rbenv-help` scripts.  We wrap those commands inside curly braces, so their output is piped together into the `abort` function, which will send the output to `stderr`.

Since `abort` also returns a non-zero exit code, this implies that passing `""` to `rbenv` is a non-happy path.  In fact, we can assume this is also true any time we see the `abort` function.

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

 - The output of `rbenv --version` (aka the version number) prints out:

 ```
 rbenv 1.2.0-16-gc4395e5
 ```

 - The output of `rbenv help` (aka info on how the `rbenv` command is used, along with its syntax and its possible arguments):

 ```
 Usage: rbenv <command> [<args>]

Some useful rbenv commands are:
   commands    List all available rbenv commands
   local       Set or show the local application-specific Ruby version

...
 ```

 If we then type `echo "$?"` immediately after that to print the last exit status, we see `1` print out.

Pretty straight-forward.

## Typing `rbenv -v` or `rbenv --version`

Next case branch is:

```
-v | --version )
  exec rbenv---version
  ;;
```

This time we're comparing `$command` against two values instead of just one: `-v` or `--version`.  If it matches either pattern, we `exec` the `rbenv---version` script, which is just a one-line output of (in my case) `rbenv 1.2.0-16-gc4395e5`:

```
 $ rbenv -v

rbenv 1.2.0-16-gc4395e5

$ rbenv --version

rbenv 1.2.0-16-gc4395e5
```

### Version Numbers

In the output `1.2.0-16-gc4395e5`, the `1.2.0` represent the major, minor, and patch versions, in accordance with [semantic versioning](https://semver.org/){:target="_blank" rel="noopener"} (or SemVer, for short).

You might also be asking what `16-gc4395e5` represents.  I wasn't sure either, and I didn't know what to Google, so I asked ChatGPT:

<center>
  <a target="_blank" href="/assets/images/screenshot-2may2023-957am.png">
    <img src="/assets/images/screenshot-2may2023-957am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

According to ChatGPT, `16` is the number of commits since the last release of RBENV, and `gc4395e5` is a reference to the SHA that we're currently pointing to (`c4395e58201966d9f90c12bd6b7342e389e7a4cb`) plus a `g` at the end to indicate that there are changes in our version which are not yet released.

We can double-check this by running a `git log` to find the previous commits and their SHAs, checking one of them out, and re-running `rbenv --version`:

```
commit c4395e58201966d9f90c12bd6b7342e389e7a4cb (HEAD -> impostorsguides)
Merge: c6cc0a1 a54b47e
Author: Hiroshi SHIBATA <hsbt@ruby-lang.org>
Date:   Sat Jul 16 08:14:44 2022 +0900

    Merge pull request #1418 from uraitakahito/patch-0

    Fix link to Pow because the server is down

commit a54b47e7835a652b48d142fbe041017895c5aabe
Author: Takahito Urai <uraitakahito@gmail.com>
Date:   Fri Jul 15 21:46:32 2022 +0900

    Fix link to Pow because the server is down

commit c6cc0a1959da3403f524fcbb0fdfb6e08a4d8ae6
Merge: e4f61e6 b39d429
Author: Mislav Marohnić <git@mislav.net>
Date:   Wed Mar 9 13:03:36 2022 +0100

    Merge pull request #1393 from scop/refactor/simplify-version-file-read

    Simplify version file read

commit b39d4291bed8439330f8a399dcdf6f11cf03eabe
Author: Ville Skyttä <ville.skytta@iki.fi>
Date:   Tue Mar 8 20:58:58 2022 +0200

    Simplify version file read

    Avoid a subshell and external `cut` invocation, as well as a throwaway
    intermediate array.


...
```

I'll take `a54b47e7835a652b48d142fbe041017895c5aabe`, the one just prior to my current SHA:

```
$ git co a54b47e7835a652b48d142fbe041017895c5aabe

Note: switching to 'a54b47e7835a652b48d142fbe041017895c5aabe'.

...

$ rbenv --version

rbenv 1.2.0-15-ga54b47e
```

Now we see `15` instead of `16`, and `a54b47e` instead of `c4395e5` after the `-g`.

What if we start at `c4395e5` and count back 16 commits, and check out **that** SHA?  What would we see?

```
$ git log

...

commit 6cc7bff383a603fb47325be80e3cac8a7f55f501
Author: Audree Steinberg <audreee@github.com>
Date:   Thu Oct 21 06:23:46 2021 -0700

    Update code block in readme for rbenv-doctor script (#1353)

    Co-authored-by: Mislav Marohnić <git@mislav.net>

commit 38e1fbb08e9d75d708a1ffb75fb9bbe179832ac8 (tag: v1.2.0)
Author: Mislav Marohnić <git@mislav.net>
Date:   Wed Sep 29 20:47:10 2021 +0200

    rbenv 1.2.0

commit 69323e77cc080d35387762eeb7dc26062ac159ea
Author: Mislav Marohnić <git@mislav.net>
Date:   Wed Sep 29 20:23:42 2021 +0200

    Clarify bash config for Ubuntu Desktop vs. other platforms

    Fixes #1130

...

$ git co 38e1fbb08e9d75d708a1ffb75fb9bbe179832ac8

Note: switching to '38e1fbb08e9d75d708a1ffb75fb9bbe179832ac8'.

...

$ rbenv -v

rbenv 1.2.0
```

This time, there's no `-16` or `g...`.  Just a version number.  That's because RBENV SHA # `38e1fbb08e9d75d708a1ffb75fb9bbe179832ac8` has a [git tag](https://git-scm.com/book/en/v2/Git-Basics-Tagging){:target="_blank" rel="noopener"} attached to it.

We'll get into why this is later, when we look at the actual code for the `rbenv---version` file.  For now, the goal was just to learn how to read the output of the `--version` flag.

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

## The Default Case

Next up is:

```
* )
...;;
```

The `* )` line is the catch-all / default case branch.  Any `rbenv` command that wasn't captured by the previous branches, including both known commands (`rbenv version`, `rbenv local`, etc.) and unknown commands (i.e. `rbenv foobar`), will be captured by this branch.

How we handle the user's input is determined by what's inside the branch, starting with the next line.

### Getting the filepath for the user's command

```
  command_path="$(command -v "rbenv-$command" || true)"
```

Here we're declaring a variable called `command_path`, and setting its value equal to the result of a response from a command substitution.  That command substitution is **either**:

 - the result of `command -v "rbenv-$command"`, or (if there is no result)
 - the simple boolean value `true`.

We saw the same `|| true` syntax [earlier in this file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L46){:target="_blank" rel="noopener"}.  It means that we don't want a failure of `command -v "rbenv-$command"` to trigger an exit of this script.

The value of the command substitution depends on what `command -v "rbenv-$command"` evaluates to.  This might be a bit confusing to read, because `command` is the name of a shell builtin, but `$command` is the name of a shell variable that we declared earlier.

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

So according to the above, calling `command ls` is **not** the same as calling `ls`.

Let's say you have a shell function named `ls`, in addition to the regular `ls` command, and you call `ls` in your shell.  In this case, Bash will try to execute the shell function first, before executing the `ls` command.  The way to bypass this behavior, and go straight to the shell command, is with the `command` command.  [This applies to aliases as well as shell functions.](https://web.archive.org/web/20230502134246/https://askubuntu.com/questions/512770/what-is-the-bash-command-command){:target="_blank" rel="noopener"}

As the `help` output mentions, adding the `-v` flag results in a printed description of the command you're running.  When I pass `-v` to `command ls`, my terminal displays the path to the executable (`/bin/ls`) *instead of* actually executing the command.

So in our case, if we type `rbenv version` in our terminal, then this line of code will evaluate to:

```
command_path="$(command -v "rbenv-version" || true)"
```

Since [we loaded `libexec` into `$PATH` earlier](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79){:target="_blank" rel="noopener"}, `rbenv-version` is considered a valid executable, which means `command -v rbenv-version` will return `/Users/myusername/.rbenv/libexec/rbenv-version` on my machine.

It is this value that gets stored in the `command_path` variable.  We can prove that in our terminal by adding `libexec/` to our `$PATH` and running `command -v rbenv-version`:

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

In other words, if the user's input did **not** result in a valid command path, then we execute the code inside this `if` block.

That code is:

```
if [ "$command" == "shell" ]; then
  abort "shell integration not enabled. Run \`rbenv init' for instructions."
else
  abort "no such command \`$command'"
fi
```

So if the user's input was the string "shell", then we abort with one error message (`shell integration not enabled. Run 'rbenv init' for instructions.`).

We would reach this branch if we tried to run `rbenv shell` either:

 - before adding `eval "$(rbenv init - bash)"` to our `~/.bashrc` config file (if we're using Bash as a shell),
 - before adding `eval "$(rbenv init - zsh)"` to our `~/.zshrc` file (if we're using `zsh` as a shell),
 - etc.

In this case, `$command_path` would be empty.

On my machine, I have the above `rbenv init` command added to my `~/.zshrc` file, so I can't reproduce this error in `zsh`.  However, I **don't** have the equivalent line added to my `~/.bashrc` file.  So if I open up a Bash shell and type `rbenv shell`, I get the following:

```
bash-3.2$ rbenv shell

rbenv: shell integration not enabled. Run `rbenv init' for instructions.
```

We'll get to why `$command_path` has a value in my `zsh` and no value in my Bash later, when we examine the `rbenv-init` file in detail.

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
This just shifts the first argument off the list of `rbenv`'s arguments.  The argument we're removing was previously stored in the `command` variable, so we no longer need to reference it with `"$1"`.  The call to `shift` makes it easier to access the next argument, if any.

## Printing `help` Instructions For The User's Command

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

If the user **did** pass the `--help` flag, we execute the next block of code:

```
if [[ "$command" == "sh-"* ]]; then
  echo "rbenv help \"$command\""
else
  exec rbenv-help "$command"
fi
```

In the first half of this nested conditional, we check whether the user entered a command which starts with "sh-".  If they did, **and** if they followed that command with `--help`, then we print `rbenv help "$command"` to STDOUT.

I try this in my terminal by typing "rbenv sh-shell –help", and I see the following:

```
$ rbenv sh-shell --help

rbenv help "sh-shell"
```

So the output matches what we'd expect from reading the code, but I'm still confused on why the code is written this way in the first place.  At this point we know enough to tell the user which command they *should have* run, because that's what was just printed.  Why don't we just run that same command, and save the user the work of doing so themselves?

I find [the PR which added this block of code](https://github.com/rbenv/rbenv/pull/914){:target="_blank" rel="noopener"} and read through it.  Turns out the code used to look like this:

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

Here we can see the lines of code that are reached (`rbenv-help:124`, `rbenv-help:125`, `rbenv-help:126`, and finally, `(eval):2`).

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

The same lines of code are logged, but no `(eval):2` error at the end.  So I **think** we're in the right neighborhood here.  But where is this call to `eval` happening, and why does it result in an error for `shell`, but not for `version`?

OK, I'll stop here and admit that I cheated a little.  I initially was stumped by this question, so I decided to write down the question so I didn't forget it, and continue reading the code.  Then, months later when I was re-reading and editing this post, I leveraged the knowledge I had gained during those months to deduce what is happening here.

TL;DR- one of the things that RBENV does when you add shell integration is create a shell function (also called `rbenv`).  At the time this PR was introduced, that shell function looked like this:

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

You can verify this by:

 - checking out the commit `9fdce5d069946417d481fd878c5c005db5b4539c`, i.e. the commit just before the above PR was merged.
 - running `rm -r ~/.rbenv/shims/*` followed by `rbenv rehash` to re-generate all your shims based on this new version of RBENV.
 - running `which rbenv` from your terminal, and verifying that it prints out a complete shell function instead of printing `path/to/file/rbenv.bash` or something similar.
 - NOTE- when you're done exploring this older version of RBENV, don't forget to check out the latest version again, and re-generate your shims so that they're up-to-date.

When you run `rbenv` commands from inside your terminal with shell integration enabled, you're **not** running the `rbenv` bash script, at least not directly.  Instead, you're **actually** running *this shell function*, which in turn calls the `rbenv` script.

This shell function gets defined by the `eval "$(rbenv init -)"` call in your shell config, each time you open a new terminal tab.  When responding to a command, UNIX checks for shell functions before it checks your `PATH` for any commands.  Because of this, the shell function is what gets run when you type `rbenv` into your terminal.

One of the things the shell function does is execute [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147-L152){:target="_blank" rel="noopener"}, which checks if the command that the user is running begins with `sh-`.  If it does, it runs `eval` plus the name of the command with its `sh-` prefix.  Otherwise, it runs the command via the `command` command (which we discussed earlier).  [This was also the case](https://github.com/rbenv/rbenv/blob/9fdce5d069946417d481fd878c5c005db5b4539c/libexec/rbenv-init#L151){:target="_blank" rel="noopener"} at the the time [the error was reported](https://github.com/rbenv/rbenv/pull/914){:target="_blank" rel="noopener"}.

It's **this** call to `eval` that is erroring out.  We can prove that to ourselves by changing that block of code in `rbenv-init` to look like the following:

```
  set -e                                                          # I added this line
  case "\$command" in
  ${commands[*]})
    echo "just before rbenv sh-command" >&2                       # I added this line
    echo "result: "\$(rbenv "sh-\$command" "\$@")"" >&2           # I added this line
    eval "\$(rbenv "sh-\$command" "\$@")"
    echo "just after rbenv sh-command" >&2                        # I added this line
    ;;
  *)
```

I added the call to `set -e` before the `case` statement (so that the code will exit immediately if the `eval` code throws an error), as well as the three `echo` statements:

 - one just before `eval` and one after.
 - the resolved values of any arguments that we pass to `eval`

I then `source` my `~/.zshrc` file so that these changes take effect, and I run `which rbenv` to confirm that they appear in the updated shell function:

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
		(rehash | shell) echo "just before rbenv sh-command" >&2
			echo "result: "$(rbenv "sh-$command" "$@")"" >&2
			eval "$(rbenv "sh-$command" "$@")"
			echo "just after rbenv sh-command" >&2 ;;
		(*) command rbenv "$command" "$@" ;;
	esac
}
```

Then, when I run `rbenv shell --help`, I see the following:

```
$ rbenv shell --help

just before rbenv sh-command
result: Usage: rbenv shell <version> rbenv shell --unset Sets a shell-specific Ruby version by setting the `RBENV_VERSION' environment variable in your shell. This version overrides local application-specific versions and the global version. <version> should be a string matching a Ruby version known to rbenv. The special version string `system' will use your default system Ruby. Run `rbenv versions' for a list of available Ruby versions.
(eval):2: parse error near `\n'

[Process completed]
```

I see `just before rbenv sh-command`, but **not** `just after rbenv sh-command`.  Since we added the `set -e` option to our shell function, the code exited after the first error that it encountered.  And since we only saw the first of the two `echo` statements immediately before and after our call to `eval`, it **must** have been this call to `eval` which threw an error.

Furthermore, the "code" that we're passing to `eval` is:

```
Usage: rbenv shell <version> rbenv .....
```

This is a human-readable set of usage instructions.  But `eval` is meant to take a command which the terminal can run.  We're trying to execute a "command" which isn't really a command.  There's our problem.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

But I'm still wondering why commands prefixed with `sh-` use `eval`, while those without the prefix use `command`.  I decide to look up the command which introduced this `if/else` block.  After some digging, I find it [here](https://github.com/rbenv/rbenv/pull/57){:target="_blank" rel="noopener"}.  It says:

> Regular commands pass though as you'd expect. But special shell commands prefixed with sh- are called, but its result is evaled in the current shell allowing them to modify environment variables.

I check both commands which have `sh-` in their names, i.e. `rbenv-sh-shell` and `rbenv-sh-rehash`.  It looks like both of these files use `echo` to print machine-readable commands as output, rather than executing those same commands themselves.  This fits with the pattern described in the above PR link.

It sounds like the idea is to give the `sh-` commands the ability to modify environment variables.  I suspect that it wouldn't have been possible to set env vars if we had used the same `command` strategy that non-`sh` commands are run with.  To test this, I run an experiment.

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
/Users/myusername/Workspace/OpenSource/impostorsguides.github.io/sh-foo

$ eval `sh-foo`

$ echo "$FOO"

foo bar baz
```

We can see that running `sh-foo` via the `eval` command had the effect of setting a value for the `"$FOO"` env var, where there was no value beforehand.

Next, I try running the `bar` script:

```
 $ echo "$BAR"

$ which bar

/Users/myusername/Workspace/OpenSource/impostorsguides.github.io/bar

$ command bar

$ echo "$BAR"

$
```

This time, the environment variable was **not** set.  This proves that using `command` does not result in the setting of the environment variable.

We mentioned earlier that scripts which are prefaced with `sh-` have the convention of `echo`ing lines of code to `stdout`.  Now we understand why this is the case- that output is executed by the caller using `eval`, because this is the only way for child scripts to affect the environment variables of a parent script.

More generally, this is also a useful design pattern if you need to run a child script which modifies the values of environment variables, and rely on those new values in the parent script.  We can write the child script such that it `echo`s the code for the modifications of the env vars, and have our parent script `eval` the code that is `echo`'ed.  This is a work-around we can use if we're ever stymied by the fact that env var changes in a child script aren't available to the parent.

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

To prove this, let's update the code of this `else` block to the following:

```
else
  echo "what gets run: $command_path $@" >&2
  exec "$command_path" "$@"
fi
```

When we then run `rbenv local 3.0.0`, we see the following output:

```
$ rbenv local 3.0.0

what gets run: /Users/myusername/.rbenv/libexec/rbenv-local 3.0.0
```

So we `exec` the filepath `/Users/myusername/.rbenv/libexec/rbenv-local`, and pass `3.0.0` as the one and only arg to this command.

And with that, we've examined how `rbenv` executes the commands in its API!

Let's move on.
