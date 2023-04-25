TODO: figure out why this file has multiple case statements, each of which prints one section of the shell function, instead of one case statement that prints each shell's function in its entirety.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init){:target="_blank" rel="noopener"}

First few lines of code are:

```
#!/usr/bin/env bash
# Summary: Configure the shell environment for rbenv
# Usage: eval "$(rbenv init - [--no-rehash] [<shell>])"

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

We have our shebang, which tells us we're in bash-land.
We have 2 lines of comments, which tell us what this command does and how to invoke it.
We have our old friend, `set -e`, which tells the shell to stop execution and exit immediately if an error is raised.
The last line checks if the `$RBENV_DEBUG` env var is set, and if it is, to set the shell's verbose option so that things like the line of code and its location are output to the screen.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

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

The first line is a comment which seems to say that this block of code adds completion functionality.  But that doesn't appear to be what the code actually does.  Instead, it first checks whether the first argument to `init` is the string "--complete".  If it is, it just `echo`'s some strings to the screen and then exits.  I'm able to reproduce this by running a simple `rbenv init --complete` in my terminal:

```
$ rbenv init --complete

-
--no-rehash
bash
fish
ksh
zsh
```

I think resolving my confusion here would involve doing a Github history dive.  Again, I don't want to get too sidetracked here, so I timebox it for 10 minutes.

I find [the PR which introduced the code](https://github.com/rbenv/rbenv/pull/822){:target="_blank" rel="noopener"}.  It doesn't contain any comments around this section of the diff, but it does contain a comment that catches my eye:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-732am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I've never heard of "magic comments" before.  Does this imply that this comment isn't *just* a comment, but is in fact picked up by an interpreter too?

After a quick search of the codebase for "provide rbenv completions", it looks like [the answer is yes](https://github.com/rbenv/rbenv/blob/d604acb78aeba583be95f08d45eeae430372beb9/libexec/rbenv-completions#L23){:target="_blank" rel="noopener"}.  I don't want to get too in the weeds now, so I add it to my list of questions to answer later.

But I still have my larger question of why we're `echo`ing the names of different shells here, along with the `--no-rehash` flag and the `-` symbol.

I do recall that `rbenv init` is part of the `eval` command (i.e. `eval "$(rbenv init - )" `) that I've often run when, for example, adding tracer statements to my actual version of `rbenv`.  I try replacing the `-` with `--complete` in this code and running it directly in my terminal:

```
$ eval "$( rbenv init --complete )"

zsh: command not found: --no-rehash

The default interactive shell is now zsh.
To update your account to use zsh, please run `chsh -s /bin/zsh`.
For more details, please visit https://support.apple.com/kb/HT208050.

bash-3.2$ echo $0
bash
```

It looks like the only thing this did was change my command prompt and create a `bash` shell.  I kill this terminal tab because I want my old shell prompt back, and re-assess.

I realize I don't even know for sure in what order the different command files are run.  Initially I thought the `rbenv` file is run first.  But then I realized that the `init` command defines a function called `rbenv`, which internally calls the `rbenv` command.

I'm now well past my 10-minute timebox, but I think it's important to at least figure out the order in which files are executed.  I hypothesize that a good place to start is to add tracer statements in various files (including `rbenv` as well as `rbenv-init` and maybe a few others), then open a new terminal.  Since the above `eval` command is located in my `~/.zshrc` file, opening a new terminal will kick off the initialization of RBENV, which in turn should show us the order in which the files with tracer statements are executed.

I add a line to the start of the `rbenv` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-736am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I open a new tab, I see it run:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-738am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I then add a tracer to the beginning of "rbenv-init":

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-739am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I open I new terminal, I see this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-740am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I then add a tracer to the first line of the `rbenv` shell function:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-741am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I open a new tab, I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-742am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So my 3rd of 3 tracers does not show up on a terminal start.  This seems to mean that neither the `init` script nor the `rbenv` script execute the `rbenv` shell function.  When I try to run a command, I see the following:

```
$ rbenv global

inside rbenv shell function
start of rbenv file
2.7.5
```

OK, so this is the first time we see the function being executed.

I'm curious whether `rbenv-init` or `rbenv` finishes executing first.  I add tracer statements to the ends of both files.  Here's `rbenv-init`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-743am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

And here's the "rbenv" file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-744am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Opening a new tab, I see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-745am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Hmm, so we see the start of both files, but the end of only "rbenv-init", not "rbenv".  Does it exit before it hits my tracer?

I add a few more tracers to "rbenv", including the ones on lines 123 and 131:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-746am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Opening a new tab results in:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-747am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So we get all the way up to "just before execution of..." in the "rbenv" file, but no further.

Oh, I think I know what's going on.  The line after line 131 in "rbenv" is an "exec" command.  "exec" will exit after it finishes executing the given command.  I think we actually encountered this before.  See the following terminal experiment:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-748am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So the process (in this case, the execution of the "rbenv" script) exits before we can run the tracer statement on line 137.

I form another hypothesis after viewing more of the "if/else" logic before the "end of rbenv file" tracer:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-749am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I see that line 126 only "echo"s, it doesn't "exec".  The conditional seems to be structured so that, if this "if" branch is reached, the "echo" command would run and then the entire "case" statement would break, leaving the last tracer statement to be executed.  The way to reach line 126 is to make sure that a) the "rbenv" command I run begins with "sh-", b) that it's a valid command, and c) the first argument that I pass to my "sh-" command is "--help".  I know "sh-shell" is a valid command, so I run "rbenv sh-shell --help" in my terminal, and get the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-750am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Success- we see the "end of rbenv file" tracer!

I also notice that we seem to go from the "rbenv-init" file, *back to* the "rbenv" file.  I see this because the 2nd tracer statement above is "inside rbenv-init, just before 'command rbenv'", then the 3rd tracer is "start of rbenv file".  I actually know why this is, because I read [a post on StackExchange](https://web.archive.org/web/20220203113040/https://askubuntu.com/questions/512770/what-is-use-of-command-command){:target="_blank" rel="noopener"} earlier today which explains what the `command` command does:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-751am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The important thing that I get from this answer is that, if we want to make sure the `rbenv` we're running is our `rbenv` *file* (instead of the `rbenv()` *function*), we need to use `command rbenv` instead of `rbenv` by itself.  This tells the shell to skip any pre-defined shell functions (including `rbenv()`) when looking for the right executable to use.

OK, so now I feel like I have a slightly better understanding of what gets executed when.  But I still don't know what the intention is behind all the `echo` statements in the `completion` code.  I decide to add more tracer statements, this time to the list of `echo`'ed shell apps...

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-752am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...as well as the beginning of the `rbenv-completions` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-753am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I try a few rbenv commands with the "--complete" flag added at the end:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-754am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I don't see my "completions" tracer anywhere, but I do see "inside --complete of rbenv-init" when I run "rbenv-init --complete".  The only time I see my "completions" tracer is when running "rbenv completions –complete":

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-755am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I thought based on the comment (`# Provide rbenv completions`) that this was meant to actually do some sort of initialization, which implies that the `echo` statements were consumed by some higher-level caller and `exec`'ed.  But based on what we've seen so far, especially when running the "rbenv init --complete" command, I think it's safe to say that the purpose of this "if" block really is as simple as it seems- to simply provide a list of possible arguments you can pass to (in this case) the "rbenv init" command.  I guess I was thrown off by the word "Provide"- I interpreted it to mean "initialize", when really it just meant "print out for the user".

I remove all the tracer statements I've added up to this point, verify that they don't appear when I run any `rbenv` commands from a new terminal tab, and move on.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>
