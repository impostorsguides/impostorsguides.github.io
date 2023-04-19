Next few lines of code:

```
command="$1"
case "$command" in
...
esac
```

Here's where we get to the meat of this file.  We're grabbing the first argument sent to the `rbenv` command, and we're deciding what to do with it via a `case` statement.  Everything else we've done in this file, from loading plugins to setting up helper functions like `abort`, has led us to this point.  The internals of that case statement will dictate how RBENV responds to the command the user has entered.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's take each branch of the `case` statement in turn:

```
"" )
  { rbenv---version
    rbenv-help
  } | abort
  ;;
```


We've seen the `)` closing parenthesis syntax before.  It denotes a specific case in the case statement.  If the value of `$command` matches our case, then we do what's in the curly braces, and we pipe that output to the `abort` command that we defined earlier in this file.

The `""` before the `)` character is the specific case we're dealing with.  This branch of the case statement will execute if `$command` matches the empty string (i.e. if the user just types `rbenv` by itself, with no args).  The code we execute in that scenario is that we call the `rbenv—version` and `rbenv-help` scripts.

Again, the output of those two commands gets piped to the `abort` command, which will send the output to `stderr` and return a non-zero exit code, which implies that calling `rbenv` with no args is a failure mode of this command.

If we go into our terminal and type `rbenv` with no args, we see this happen.  The version number prints out, followed by info on how the `rbenv` command is used (its syntax and its possible arguments).  If we then type `echo "$?"` immediately after that to print the last exit status, we see `1` print out.

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

Pretty straight-forward.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

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

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

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

Again, no real surprises here.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next up is:

```
* )
...;;
```

The `* )` line is the catch-all / default case branch.  Any `rbenv` command that wasn't captured by the previous branches will be captured by this branch.  How we handle that is determined by what's inside the branch, starting with the next line:

```
  command_path="$(command -v "rbenv-$command" || true)"
```
Here we're declaring a variable called `command_path`, and setting its value equal to the result of a response from a command substitution.  That command substitution is **either**:

 - the result of `command -v "rbenv-$command"`, or (if that result is a falsy value)
 - the simple boolean value `true`.

The value of the command substitution depends on what `command -v "rbenv-$command` evaluates to.  It's a bit confusing to parse because `command` is the name of a shell builtin, but `$command` is the name of a shell variable that we declared earlier.

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

So calling `command ls` is the same as calling `ls`.  I could see this being useful if the command you want to run is stored in a variable, and is dynamically set.  For example:

```
$ myCommand="pwd"

$ if [ "$myCommand" = "pwd" ]; then
> command "$myCommand"
> fi

/Users/myusername/Workspace/OpenSource/rbenv
```

As the `help` description mentions, adding the `-v` flag results in a printed description of the command you're running.  When I pass `-v` to `command ls` in my terminal, I see `/bin/ls` *instead of* the regular output of the `ls` command.  Therefore, the path to the `$command` will end up being the string that we store in the variable named `command_path`.

That is, unless no such path exists, in which case we'll store the boolean `true` instead.  Recall from earlier that passing a boolean to a command substitution results in a response with a length of zero.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That knowledge is useful when interpreting our next line of code:

```
if [ -z "$command_path" ]; then
...
fi
```

In other words, if the user's input doesn't correspond to an actual command path, then we execute the code inside this `if` block.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That code is:

```
if [ "$command" == "shell" ]; then
  abort "shell integration not enabled. Run \`rbenv init' for instructions."
else
  abort "no such command \`$command'"
fi
```

So if the user's input was the string "shell", then we abort with one error message ("shell integration not enabled. Run \`rbenv init' for instructions.").

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

TODO- edit the original explanation of the `shift` command to include what happens when you pass a param (like `1` here).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

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

Why would we print **this** to the screen?  At this point we know enough to tell the user which command they *should have* run.  Why don't we just run it for them and save them a step?

I find [the PR which added this block of code](https://github.com/rbenv/rbenv/pull/914){:target="_blank" rel="noopener"} and read up on it.  Turns out the code used to look like this:

```
if [ "$1" = --help ]; then
  exec rbenv-help "$command"
else
  exec "$command_path" "$@"
fi
```

This is much closer to what I'd expect.  But according to the PR description, this caused the `rbenv shell --help` command to trigger an error.  I check out the commit just before this PR was merged and try to reproduce the error:

```
$ rbenv shell --help

(eval):2: parse error near `\n'
```

OK, so what caused this error?

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

The same lines of code are logged, but no `(eval):2` error at the end.  So I **think** the problem must be in the code that we're trying to `eval`, i.e. `exec rbenv-help "$command"`.

I wanted to see what exactly this code was.  So I added the following `echo` statement above it:

```
if [ "$1" = --help ]; then
  echo "$(rbenv-help "$command")" >&2
  echo "----------" >&2
  exec rbenv-help "$command"
else
```

I'm capturing the output of the same command that we're trying to `exec`, sending it to `echo`, and redirecting `stdout` to `stderr` so that my `echo` statement won't interfere with anything else that's going on in the code.  I also `echo` a divider line, so we can know where my printed statements end and the code takes over again.

Here's the result when I run `rbenv shell --help`:

```
$ rbenv shell --help

Usage: rbenv shell <version>
       rbenv shell --unset

Sets a shell-specific Ruby version by setting the `RBENV_VERSION'
environment variable in your shell. This version overrides local
application-specific versions and the global version.

<version> should be a string matching a Ruby version known to rbenv.
The special version string `system' will use your default system Ruby.
Run `rbenv versions' for a list of available Ruby versions.
----------
(eval):2: parse error near `\n'
```

OK, so we're trying to `exec` a printed set of usage instructions which are meant for humans to read (not for `bash` to run).  But this error only happened with `rbenv shell`, not with `rbenv version`.

What if I capture the output from `rbenv version` instead?  Does it also print out usage instructions?

```
$ rbenv version --help
Usage: rbenv version

Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
Usage: rbenv version

Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
```

Yep, `"$(rbenv-help $command)"` evaluates to the usage instructions for `version`, just like it did with `shell`.  So why is it trying to `eval` usage instructions for `shell`, but not `version`?  We know from [the PR diff](https://github.com/rbenv/rbenv/pull/914/files){:target="_blank" rel="noopener"} that the solution was to treat commands that are prefixed with `sh-` differently.  Where is this happening?

OK, I'll stop here and admit that I cheated a little.  I initially was stumped by this question, so I decided to punt on it for the time being and continued onward.  Then, months later when I was re-reading and editing this post, I went back with the knowledge I had gained reading the other files in this repo and leveraged that knowledge to deduce what is happening here.

TL;DR- one of the things that RBENV does when you add that `eval "$(rbenv init -)"` string to your shell config is that it creates a shell function (also called `rbenv`).  When you run `rbenv` commands from inside your terminal, you're **not** running the `rbenv` bash script, at least not directly.  Instead, you're **actually** running *this shell function*, which in turn calls the `rbenv` shell script.  You can verify this by running `which rbenv` from your terminal:

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

Instead of printing `path/to/file/rbenv.bash` or something similar, it prints out a complete shell function.  It's this shell function that gets defined by the `eval "$(rbenv init -)"` call in your shell config every time you open a new terminal tab.  Since UNIX will check for shell functions before it checks your `PATH` for any commands, this is the first implementation of the `rbenv` command that it finds, and so this is what gets run when you type `rbenv` into your terminal.

As part of its logic, the shell function executes [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147-L152){:target="_blank" rel="noopener"}, which checks if the command that the user is running begins with `sh-`.  If it does, it runs `eval` plus the name of the command with its `sh-` prefix.  Otherwise, it runs the command via the `command` command (which we discussed earlier).

It's **this** call to `eval` that is erroring out.  We can prove that to ourselves by changing that block of code in `rbenv-init` to look like the following:

```
set -e
  case "\$command" in
  ${commands[*]})
    echo 'just before eval' >&2
    eval "\$(rbenv "sh-\$command" "\$@")"
    echo 'just after eval' >&2
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

Now it's starting to make sense why the PR author structured their code the way they did.  Since all `sh-` scripts will be treated the same way by this `case` statement,

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next (and final!) line of code in this file:

```
  else
    exec "$command_path" "$@"
```

This is the line of code which actually executes the command that the user typed.  The `$@` syntax expands into [the flags or arguments](https://web.archive.org/web/20230319115333/https://stackoverflow.com/questions/3898665/what-is-in-bash){:target="_blank" rel="noopener"} we pass to that command.

That's it!  That's the entire `rbenv` file.  What should we do next?

Normally I'd want to copy the order in which the files appear in the "libexec" directory.  But given what we saw with "rbenv-init" and how it has a big effect on how the "rbenv" file is called, I think it makes more sense to start there and come back to the next file ("rbenv–-version") afterward.
