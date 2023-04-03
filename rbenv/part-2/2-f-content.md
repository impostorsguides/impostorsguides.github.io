As with the `rbenv` command, let's start by looking at this command's tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/init.bats)

After the `bats` shebang and the loading of the `test_helper` file, the first test is:

```
@test "creates shims and versions directories" {
  assert [ ! -d "${RBENV_ROOT}/shims" ]
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-init -
  assert_success
  assert [ -d "${RBENV_ROOT}/shims" ]
  assert [ -d "${RBENV_ROOT}/versions" ]
}
```

Given what we know about the BATS library's API and the helper methods exposed by the `test_helper` file, this test is relatively easy to read.  We first perform some sanity-check assertions stating that the `${RBENV_ROOT}/shims` and `${RBENV_ROOT}/versions` directories do not exist.  We then run the command with the `-` flag ([if this flag is missing](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L46), then `rbenv init` prints out usage instructions and [exits with a failure return code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L83), which we'll see in the next section).  Lastly, we assert that the command ran successfully and that the two formerly-missing directories have been created.

I was curious why the default behavior (i.e. the behavior when no "-" flag is passed) is to exit with a non-success return code.  I looked up [the commit which introduced this flag](https://github.com/rbenv/rbenv/commit/4ee92fca43805a3d4a04f453e79a06e85b9810e9), however unfortunately it was added by the original author back when he was likely the only person maintaining the repo, and he didn't include an issue or a PR description other than the commit message itself.  This commit message doesn't reveal the author's intention, so it's anyone's guess as to why the change was introduced.

Next test:

```
@test "auto rehash" {
  run rbenv-init -
  assert_success
  assert_line "command rbenv rehash 2>/dev/null"
}
```

(stopping here for the day; 91710 words)

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L104).  If the value of a variable named `no_rehash` hasn't been set by the time we reach this block, then we print the string 'command rbenv rehash 2>/dev/null' to STDOUT.  This string looks like a command that you might type into your terminal, and in fact it is.  This particular command, `rbenv rehash`, is a command we'll get into down the road, but for now suffice it to say that "rehashing" means generating a new instance of the shim file that RBENV inserts between the user and the gem they're trying to run when they type a certain command.  Fun fact- when you try to run a program that's installed via "gem install", you're really running an RBENV file called a "shim" which tells RBENV to run that program for you, using your currently-installed Ruby version.  Shims are a big part of how RBENV does its job of cleanly managing your Ruby version.

When we start analyzing the command file, we'll see that these commands which are printed to STDOUT are actually captured by something called [command substitution](https://web.archive.org/web/20221010044921/https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html), and executed by `bash`.  So when we see an assertion that expects a certain string to be printed, and when that string looks like shell code, that's what's happening.

Note that at the time of this writing, I'm still not sure why we print stringified versions of the commands to STDOUT, to be later evaluated by command substitution.  I suspect the same goal could have been accomplished by:

having a file for each supported shell type containing the actual code to execute when the user types `rbenv` (as opposed to the stringified version of that code),
detecting which shell program the user is using, and
executing the right file for the user's shell type

Of course, I can't *prove* that this 2nd approach would work without re-writing RBENV the way I envision.  That could be a super-useful learning exercise to see if I could get it to work, but it would also be a huge time commitment and one that I don't think I can manage now.  I don't doubt that the core team had great reasons for writing the library the way they did, it's just that those reasons aren't immediately obvious to me right now.  It may be a question that I have to punt on until later.

Next test:

```
@test "setup shell completions" {
  root="$(cd $BATS_TEST_DIRNAME/.. && pwd)"
  run rbenv-init - bash
  assert_success
  assert_line "source '${root}/test/../libexec/../completions/rbenv.bash'"
}
```

This test covers the 4-line block of code starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L97).  We store the value of our root directory, and run `rbenv-init` while specifying `bash` as our shell.  We assert that the command completed successfully and that the line which `source`s the completion file is `echo`ed to the screen.  The completion files were some of the first files we covered in this document.

Next test:

```
@test "detect parent shell" {
  SHELL=/bin/false run rbenv-init -
  assert_success
  assert_line "export RBENV_SHELL=bash"
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L36) and the lines after it.  We purposely set the `SHELL` env var to be a falsy value, and run the command with no argument after the "-" character.  Because of these facts, initially the `$shell` variable inside our script is empty.  But after the relevant line of code, we've detected that our parent shell is `bash`, and we use that as the value for `$shell` from then on.  We can see this by adding a bunch of `echo` statements to this block of code, like so:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-725am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I run the test, and print out `foo.txt`, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-726am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Once the correct shell program has been detected and stored in a string, our script just whittles the string down until it has just the shell program's name.  Once we have just the name, we can construct our shell function to suit the user's shell type.

Next test:

```
@test "detect parent shell from script" {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
  cat > myscript.sh <<OUT
#!/bin/sh
eval "\$(rbenv-init -)"
echo \$RBENV_SHELL
OUT
  chmod +x myscript.sh
  run ./myscript.sh
  assert_success "sh"
}
```

We create and navigate into a test directory, and in that directory we create a test script which contains an `sh` shebang and a call to `eval` RBENV's `init` command with no explicit shell set.  Lastly, it prints out the value of `RBENV_SHELL` (which should be set when `rbenv init -` is run).  We make the script executable and run it, and assert that `sh` was indeed printed to the screen.

Next test:

```
@test "skip shell completions (fish)" {
  root="$(cd $BATS_TEST_DIRNAME/.. && pwd)"
  run rbenv-init - fish
  assert_success
  local line="$(grep '^source' <<<"$output")"
  [ -z "$line" ] || flunk "did not expect line: $line"
}
```

We store a directory path in a variable named `root`, quite similar to a previous test.  I actually think this is a copy-paste mistake, because `root` is not subsequently used anywhere in the test.  We'll ignore it for now.

We run `rbenv init`, passing `fish` as the explicit shell.  We first assert that the command succeeded.  We then search the lines of output (which `bats` stores for us in a variable named `$output`) for the string `source`.  We store any matches we find in a variable named `line`.  We then assert that this variable is empty, and we fail the test if it is not.

Next test:

```
@test "posix shell instructions" {
  run rbenv-init bash
  assert [ "$status" -eq 1 ]
  assert_line 'eval "$(rbenv init - bash)"'
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L77), as well as [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L83).  We specify `bash` as the shell type for `rbenv-init` and run it.  Because we didn't specify the "-" before the shell type, we find ourselves inside the `if` code of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L46).  We assert that one of the lines of text printed to STDOUT contains the command that we need to add to our shell profile in order to enable shell integration (i.e. the `eval` command *with* the "-" hyphen included).

Next test:

```
@test "fish instructions" {
  run rbenv-init fish
  assert [ "$status" -eq 1 ]
  assert_line 'status --is-interactive; and rbenv init - fish | source'
}
```

(stopping here for the day; 92723 words)

This is a similar test to the previous one, except here we pass the argument "fish" instead of "bash".  We once again assert that the command exited with a status code of 1, and that the proper shell integration script is printed to STDOUT.  This time, the script syntax is "fish"-specific, rather than "bash"-specific.

Next test:

```
@test "option to skip rehash" {
  run rbenv-init - --no-rehash
  assert_success
  refute_line "rbenv rehash 2>/dev/null"
}
```

This test appears to test [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L28), as well as [this block](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L104).  We run the `init` command, passing the "-" and "--no-rehash" flags.  We assert that a) the test was successful, and b) that the code to rehash RBENV's shims (`"rbenv rehash 2>/dev/null"`) does *not* get printed to STDOUT.

Next test:

```
@test "adds shims to PATH" {
  export PATH="${BATS_TEST_DIRNAME}/../libexec:/usr/bin:/bin:/usr/local/bin"
  run rbenv-init - bash
  assert_success
  assert_line 0 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L94).  We set `$PATH` to a known value, then run `init` with the arguments "-" and "bash".  We assert that the test was successful, and that the path was prepended with `{RBENV_ROOT}'/shims`.

Next test:

```
@test "adds shims to PATH (fish)" {
  export PATH="${BATS_TEST_DIRNAME}/../libexec:/usr/bin:/bin:/usr/local/bin"
  run rbenv-init - fish
  assert_success
  assert_line 0 "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
}
```

This is a similar test to the previous one, except that it passes "fish" as an argument instead of "bash" (the line of code that's tested is [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L90)).  We perform the same setup, and as before the assertion tests that the `PATH` env var is re-exported to include `{RBENV_ROOT}'/shims` before its original value.

Next test:

```
@test "can add shims to PATH more than once" {
  export PATH="${RBENV_ROOT}/shims:$PATH"
  run rbenv-init - bash
  assert_success
  assert_line 0 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
}
```

This test asserts that, when the value of `PATH` already includes RBENV's `shims/` directory, a subsequent call to "rbenv init" results in `PATH` being prepended with additional copies of the `shims/` directory.  We set `PATH` to include `shims/`, run `rbenv init` with the arguments "-" and "bash", assert that the test is successful, and assert that the new value of `PATH` to be exported includes the original value (with `shims/`), plus a duplicate value of the `shims/` path at the front of the env var.

I was curious why we'd explicitly want to ensure that duplication within `PATH` is acceptable.  I would have thought that we'd want to actively *prevent* such duplication, since it makes `PATH` harder to read and debug.

As it turns out, this test appears to cover a problem presented by some of RBENV's users [here](https://github.com/rbenv/rbenv/issues/369).  When certain users attempted to run the `tmux` command, their version of Ruby was changed unintentionally.  According to RBENV's core team, the reason for this was as follows:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-729am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So by running `tmux`, the shell configuration files `.bashrc` or `.zshrc` get `source`'ed a 2nd time.  In the case of these users, this action caused `$PATH` to be prepended with a duplicate copy of the path to "system" Ruby.  Since the same config files presumably contained the `rbenv init` command, this normally would have caused `$PATH` to be prepended with a duplicate of the path to RBENV Ruby versions as well.

However, at the time of this bug, RBENV included a line of logic which prevented duplicate copies of the paths to its Ruby versions from being added to `$PATH`.  This was meant to avoid polluting `$PATH` with duplicate directory paths, for the reasons I mentioned earlier.

By including this logic to prevent duplication, RBENV inadvertently contributed to the existence of this unexpected behavior for `tmux` users.  The core team appears to have decided that the best of several less-than-ideal solutions was to allow the `$PATH` duplication after all, since the existing logic was causing problems for too many users.  The PR to "revert back to simpler times" is located [here](https://github.com/rbenv/rbenv/commit/e2173df4aa91c8d365ca1596fb857fcac9fdd787).

Next test:

```
@test "can add shims to PATH more than once (fish)" {
  export PATH="${RBENV_ROOT}/shims:$PATH"
  run rbenv-init - fish
  assert_success
  assert_line 0 "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
}
```

This test covers the same edge case as the previous test, but for the `fish` shell instead of the `bash` shell.

Next test:

```
@test "outputs sh-compatible syntax" {
  run rbenv-init - bash
  assert_success
  assert_line '  case "$command" in'

  run rbenv-init - zsh
  assert_success
  assert_line '  case "$command" in'
}
```

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147).  It asserts that, when we run `rbenv init` for both the `bash` and `zsh` shells, the shell function that `rbenv init` helps create includes a certain `case` statement which determines which RBENV file to execute based on which RBENV command the user typed.

Last test:

```
@test "outputs fish-specific syntax (fish)" {
  run rbenv-init - fish
  assert_success
  assert_line '  switch "$command"'
  refute_line '  case "$command" in'
}
```

This test covers the blocks of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L116) and [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L139), and covers the alternate path to the previous test.  When the user invokes `rbenv init` with `fish` as the shell argument instead of `bash` or `zsh`, we need very different syntax for our shell function.

Now that the tests are done, let's look at the code:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init)

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

I find [the PR which introduced the code](https://github.com/rbenv/rbenv/pull/822).  It doesn't contain any comments around this section of the diff, but it does contain a comment that catches my eye:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-732am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I've never heard of "magic comments" before.  Does this imply that this comment isn't *just* a comment, but is in fact picked up by an interpreter too?

After a quick search of the codebase for "provide rbenv completions", it looks like [the answer is yes](https://github.com/rbenv/rbenv/blob/d604acb78aeba583be95f08d45eeae430372beb9/libexec/rbenv-completions#L23).  I don't want to get too in the weeds now, so I add it to my list of questions to answer later.

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

I also notice that we seem to go from the "rbenv-init" file, *back to* the "rbenv" file.  I see this because the 2nd tracer statement above is "inside rbenv-init, just before 'command rbenv'", then the 3rd tracer is "start of rbenv file".  I actually know why this is, because I read [a post on StackExchange](https://web.archive.org/web/20220203113040/https://askubuntu.com/questions/512770/what-is-use-of-command-command) earlier today which explains what the `command` command does:

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

Next line of code:

```
print=""
no_rehash=""
for args in "$@"
do
...
done
```
Pretty straightforward.  We're declaring two variables (`print` and `no_rehash`), setting them to empty strings, then iterating over each arg in the list of args sent to `rbenv init`.

Next few lines:

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
I bit off a fairly big block here, but it's pretty straightforward.  For each of the args, we check whether the arg is equal to either the "-" string or the "--no-rehash" string.  If the first condition is true, we set the "print" variable equal to 1.  If the 2nd condition is true, we set the "no_rehash" variable equal to 1.  Otherwise, they remain empty strings.  These variables will likely be used later in the file.

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

Here we grab the new 1st argument (due to the `shift` calls in the previous `for` loop), and store it in a variable named `shell`.  If that argument was empty, then we attempt to set it to the return value of a certain terminal command.  That command is `ps -p "$PPID" -o 'args='`.  We then progressively whittle down the value of this output, until we get to just the name of the user's shell.

To see in detail what happens here, I add a bunch of `echo` statements to this line of code:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-756am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I open a new tab, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-757am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So the whole purpose of this series of parameter expansions is just to store a string like "zsh" (or "bash" or "fish" or whatever the user's shell happens to be).  Again, to be used later, presumably.

Let's remove the tracers we just added, and move on to the next line of code:

```
root="${0%/*}/.."
```
`$0` in a bash script resolves to the name of the file that's being run.  Therefore, so does `${0}`.  Adding `%/*` just trims off everything from the final `/` character to the end of the string.  If we echo `${0%/*}` tot the console (along with the value of `$root`, for completeness) and open a new terminal tab, we get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-758am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-759am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

As expected, we see the parent dir of the `rbenv-init` file, and the value of `$root`.  The name "root" makes sense, because it's the root directory of RBENV.

Next few lines of code:

```
if [ -z "$print" ]; then
  case "$shell" in
  ...
  esac
...
fi
```

Here we check whether our `$print` variable is empty.  If it is, then we run a case statement based on what shell we're using.

Next few lines:

```
  bash )
    if [ -f "${HOME}/.bashrc" ] && [ ! -f "${HOME}/.bash_profile" ]; then
      profile='~/.bashrc'
    else
      profile='~/.bash_profile'
    fi
    ;;
```

If our shell is "bash", we run another "if/else" check.  We reach the "if" branch if the "~/.bashrc" file exists *and* if the "~/.bash_profile" file does NOT exist.  If this condition is true, we set a new "profile" variable equal to "~/.bashrc".  If it's false, we set it equal to "~/.bash_profile".

Next few lines of code:

```
  zsh )
    profile='~/.zshrc'
    ;;
```
If our shell is "zsh", we set the "profile" var equal to "~/.zshrc".

Next few lines of code:

```
  ksh )
    profile='~/.profile'
    ;;
```

Similar to the last "case" branch, but with "ksh" instead of "zsh".  Looks like the standard config file for "ksh" is located at "~/.profile" instead of zsh's "~/.zshrc".

Next few lines of code:

```
  fish )
    profile='~/.config/fish/config.fish'
    ;;
```
Same deal as before, but with the standard config file for the "fish" shell instead of "ksh".

The next (and final) case branch:

```
  * )
    profile='your profile'
    ;;
```

The catch-all default is just the string "your profile".  We'll find out why the code sets "profile" equal to the human-readable string "your profile" in the next block of code.

Next lines of code:

```
{ echo "# Load rbenv automatically by appending"
    echo "# the following to ${profile}:"
    echo
    case "$shell" in
    fish )
      echo 'status --is-interactive; and rbenv init - fish | source'
      ;;
    * )
      printf 'eval "$(rbenv init - %s)"\n' "$shell"
      ;;
    esac
    echo
  } >&2
```
Here we take everything inside the curly braces, and we send the output to STDERR.

The content of the data we send is a message telling the user what text to add to their shell configuration file (i.e. ~/.zshrc, ~/.profile, etc., depending on their shell).  Here we also see where that "your profile" string gets used.  If we run `rbenv init foobar` in the terminal, we see:

```
$ rbenv init foobar
# Load rbenv automatically by appending
# the following to your profile:

eval "$(rbenv init - foobar)"
```

Here we see that `the following to ${profile}:` evaluates to `the following to your profile:`.  In contrast, if we run `rbenv init zsh`, we see:

```
$ rbenv init zsh
# Load rbenv automatically by appending
# the following to ~/.zshrc:

eval "$(rbenv init - zsh)"
```

Here, that same string evaluates to `the following to ~/.zshrc:`.

Next line of code is:

```
mkdir -p "${RBENV_ROOT}/"{shims,versions}
```

Here we make two sub-directories inside "$RBENV_ROOT"- one named "shims" and one named "versions".  No big deal.

Next line of code:

```
case "$shell" in
 ...
esac
```

Here we have a simple case statement, which branches based on the value of our "$shell" string.

Next lines of code:

```
fish )
  echo "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
  echo "set -gx RBENV_SHELL $shell"
;;
```

The first case branch is if our shell is "fish".  If it is, we `echo` a few commands to the script which calls `eval` on `rbenv init`.

Both these commands use the "fish" shell's "set" command to set shell variables.  More info [here](https://fishshell.com/docs/current/cmds/set.html).  The "-g" flag makes the variable global, and the `-x` flag makes the variable available to child processes.  We're creating two such variables here: `PATH` and `RBENV_SHELL`.  Well, technically, we're *creating* one variable (`RBENV_SHELL`) and *resetting* another (`PATH`).  The latter already existed in our terminal; we're just pre-pending it with `${RBENV_ROOT}/shims'` so that the shims which RBENV creates will be findable by our terminal.

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-806am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Next lines of code:

```
* )
  echo 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
  echo "export RBENV_SHELL=$shell"

  completion="${root}/completions/rbenv.${shell}"
  if [ -r "$completion" ]; then
    echo "source '$completion'"
  fi
;;
```

The first two lines of code do exactly what the two lines in the "fish" case branch do, just with regular bash syntax instead of fish syntax.

The next line of code creates a file path where the user's completion file should live, assuming the user is using a shell program that RBENV has a completions file for.  It only has two for now- "bash" and "zsh", as we saw in our sojourn into the "/completions" directory.  After the filepath is created, the "if" block checks whether that file actually exists and is readable:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-807am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

If it does exist, we run `source` on that file in order to run its contents.

Next lines of code:

```
if [ -z "$no_rehash" ]; then
  echo 'command rbenv rehash 2>/dev/null'
fi
```
If "$no_rehash" was not set (i.e. if the user did NOT pass "--no-rehash" as an argument), then we run "rbenv command rehash" and send any errors to /dev/null.  We don't yet know what the "rbenv rehash" command does; we'll get to that when we cover the "libexec/rbenv-rehash" file.

Next line of code:

```
commands=(`rbenv-commands --sh`)
```

This line stores the output of `rbenv-commands --sh` in a variable called `commands`.  Since this appears to be executing the libexec folder's `rbenv-commands` script directly, I add `libexec/` to my `$PATH` and run the same command, with the following results:

```
$ PATH=~/Workspace/OpenSource/rbenv/libexec/:$PATH
$ rbenv-commands --sh

rehash
shell
```

(stopping here for the day; 25761 words)

I didn't see anything relevant to the `--sh` flag when running `rbenv commands --help`, but a quick look at the `rbenv-commands` file itself tells us that the `--sh` flag just narrows down the output to the commands whose files contain `sh-` in their names (i.e. `shell` and `rehash`).  Again, I'm not sure what makes these commands special or requires them to be treated differently, but hopefully we'll answer that question in due time.

Next line of code:

```
case "$shell" in
...
esac
```
Here we're just branching via case statement based on the different values of our `$shell` var.

Our first branch is:

```
fish )
  cat <<EOS
function rbenv
  set command \$argv[1]
  set -e argv[1]
...
EOS
  ;;
```

If the user is using the "fish" shell, we create a multi-line string (also called a "here-string") using the `<<EOS` syntax to start the string, and the `EOS` syntax to end it.  Inside the here-string is where we begin creating a function named "rbenv" (we encountered this when we were dissecting the "rbenv" file).  We're creating a function inside a string because we then "cat" the string out to STDOUT, which is received by the `eval` caller of `rbenv init`.

Since the "fish" shell operates so much differently from other shells, we need to do things a bit differently when defining the "rbenv" function in this shell environment.  We can refer back to the [Fish shell docs](https://web.archive.org/web/20220720181625/https://fishshell.com/docs/current/cmds/set.html), however I can already tell that I'll need the ability to test some of this "fish" syntax on my local machine.  For example, on these two lines:

```
  set command \$argv[1]
  set -e argv[1]
```

Why do we use a "$" sign on line 1, but not on line 2?

To truly test this syntax out, I need to create fish shell scripts on my local machine.  Since I don't yet have fish installed, I need to install it.  I'll use Homebrew to do that:

```
brew install fish
```

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-808am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Great!  Now when I write a fish shebang as the first line of my script, my computer will know how to handle that.  Here's a simple test script, to ensure that my fish shell was installed properly:

```
#!/usr/bin/env fish

echo 'Hello world'
```

When I run it, I get:

```
$./foo

Hello world
```

Awesome, now we can mess around with fish on our local and see what different syntaxes (syntaces?) do.  Here's a simple fish function, which takes in any args which are passed from the command line:

```
#!/usr/bin/env fish

function foo
  echo "oldest argv: $argv"
  echo "old command: $command"
  set command $argv[1]
  echo "new command: $command"
  echo "old argv: $argv"
  set -e argv[1]
  echo "new argv: $argv"
  exit
end

foo $argv
```

And here is me calling it from the command line:

```
$ ./foo bar baz buzz

oldest argv: bar baz buzz
old command:
new command: bar
old argv: bar baz buzz
new argv: baz buzz
```

Here we see that, initially, the "$command" variable is undefined (as shown by the "old command: <blank>" line.  After we run "set command $argv[1]", its value changes to "bar".  This has the effect of declaring a variable named "command", and setting its value equal to the first argument in the list.

We also see that, initially, the args passed to the foo function are "bar", "baz", and "buzz".  After I call "set -e argv[1]", the new args are "baz" and "buzz".  This means that "set -e argv[1]" has the effect of removing the first arg from the arg list.  This is the same thing that "shift" does in zsh.

Taken together, these two lines mean that we're creating a variable named "command" and setting its value equal to the value of "argv[1]", and then we're deleting argv[1] itself.

Next few lines of code (inside the here-string, but after `set -e argv[1]`):

```
switch "\$command"
  case ${commands[*]}
    rbenv "sh-\$command" \$argv|source
  case '*'
    command rbenv "\$command" \$argv
  end
end
```

Not gonna lie, I had a really hard time with this code.

At first I thought this was just a fish-flavored case statement with two branches, depending on the value of our "command" variable.  I suspected that the first branch is reached if the value of that variable is one of the values in our "commands" variable, but I wasn't 100% sure since I'm not super-familiar with the "[*]" syntax.  To test my hypothesis, I wrote a simple test script in fish:

```
#!/usr/bin/env fish

set command "foo"

switch $command
case ${argv[*]}
  echo "command in args"
case "*"
  echo "command not found"
end
```

I'll save you the drama of why this didn't work and the alternatives I tried, because I don't think it would be very educational to see my muddled thought process here.  In the end, I wrote a StackExchange question and got an answer [here](https://archive.ph/zKi7G).  TL;DR- I was getting confused about which parts of the syntax were being resolved by fish and which by bash, as well as when.  The answer appears to be that 1) bash constructs a string containing a function definition, resolving certain parameter expansions and variables along the way, and then 2) that string is evaluated by fish as a set of commands and a function definition.  I was unable to reproduce that behavior in the timebox I gave myself, but I'm relatively confident that this is what happens.

Side note: it's amazing who might answer you when you post a StackExchange question.  It turns out that the person who helped me out was [a well-known ethical hacker](https://web.archive.org/web/20220308002926/https://www.smh.com.au/technology/stephane-chazelas-the-man-who-found-the-webs-most-dangerous-internet-security-bug-20140926-10mixr.html) who helped find and fix a zero-day Bash exploit in millions of laptops, phones, and embedded devices around the world!

On another note, I have to say I'm a bit disheartened that I was unable to understand the interplay of bash and fish well enough to reproduce a simplified test case for you here.  I would have considered that a mark not only of my success in teaching you something, but also in me having learned something.  To the extent that I'm unable to produce such test cases, I consider that a failure on my part.

I compare myself and my work against people like Aaron Patterson and Mislav Marohnić, who would undoubtedly be able to succeed where I've failed here.  If they ever write a guide to reading and understanding open-source code and you're choosing whether to buy their book or mine, I heartily encourage you to buy theirs.  Until then, you'll have to make do with mine.  I console myself with the idea that, while my knowledge of code may not be comparable to theirs, perhaps I can at least pass on a lesson in staying humble and taking things one day at a time.

—--

OK, today is the next day.  I decide to take another crack at this.  I know that what I want is to create a string which represents a fish function, and then cat that string to a fish script.  That fish script should run `eval` on that function string, so that `eval` can turn the string into code.  I know this is how `eval` works in fish because I've reproduced it locally:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-810am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Once the string has been turned into code, I *should* be able to call the function defined in that string.  If I can successfully reproduce the above steps, I will have succeeded in my goal.

So far I have the following:

 - A bash script named "foo" in a folder also named "foo", which looks like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-811am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

 - A fish script named "bar", which looks like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-812am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I run the "foo" script directly, it successfully prints out the function in the format that I would expect:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-813am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

My hypothesis was that, when I run the "bar" script, the "eval" statement would process the string that is `cat`'ed to STDOUT, and produce a runnable function.  But that's not what happens.  Instead, I see this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-814am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I Googled this exact error string (`Expected end of the statement, but found end of the input`), but shockingly I got no results at all:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-818am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

My mental bandwidth was already pretty shot by the time I hit this wall yesterday, which is why I wrote what I wrote yesterday about being disappointed in myself.

Today, I decide to try again.  I start by creating a bash script named "baz", which implements a simpler function definition:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    echo "Hello world"
  end
EOS
```

There's no dynamic string interpolation or parameter expansion here.  Just a simple 'Hello world' function.  I run `chmod +x baz` so that I can execute it.  I run "baz" by itself to make sure it works:

```
$ vim foo
$ chmod +x foo
$ ./foo

  function bar
    echo "Hello world"
  end
```

I open up a fish shell and try to "eval" the output of this file.  I get the same error:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-820am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I re-read [the fish docs on defining functions](https://fishshell.com/docs/current/cmds/function.html).  I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-821am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

What stood out to me this time is the semi-colons at the end of the signature and body.  I wonder if it would help things if I reformatted my function string to use semi-colons.

I add semi-colons to the end of each line of the "baz" script:

```
#!/usr/bin/env bash

cat << EOS
  function bar;
    echo "Hello world";
  end;
EOS
```

I then try to re-run the "eval" statement in my fish shell:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-822am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Holy shit, it worked!

Now let's try the same solution in the original "bar" script:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-823am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Hmmm, well I didn't get the same error as last time (in fact, it looks like I didn't get an error at all).  But when I try to call my "foo" function, it says there's no command found.  That means it didn't define my function like I had planned.

Maybe the problem is that I'm not handling the semi-colons correctly with respect to the switch statement.  Let me go back to my "baz" script and increase its complexity a bit with a "switch" statement of its own:

```
#!/usr/bin/env bash

cat << EOS
  function bar;
    set myVar 5;
    switch $myVar;
    case 5;
      echo 'e';
    case '*';
      echo 'Not found';
    end;
  end;
EOS
```

When I "eval" this code, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-826am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

Why does it think I'm missing an "end"?  Both the "switch" statement and the function itself have closing "end" lines (11 and 12, respectively).

Oh, hmmm.  I see in the fish docs for switch statements that there isn't supposed to be a closing "end" tag for the switch:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-827am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I delete line 11...

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-830am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

...and try again:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-831am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

I Google this error ("Missing end to balance this function definition"), and one of the first results is [this link](https://archive.ph/R1eVq), which contains an IRC discussion of someone experiencing the same error.  At one point, a participant in the discussion says "You're not using `eval` to load it, are you?", which catches my eye.  Am I not supposed to be loading the code with "eval"?

I Google "using eval to load code fish", and one of the first results that comes up is [a discussion in the "fish-shell" Github repo](https://github.com/fish-shell/fish-shell/issues/3993).  I see several people recommending that a piece of text be piped into "source" instead.  It appears that the fish shell prefers piping over the use of "eval".

I re-write the function again:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    set myVar 5
    echo $myVar
  end
EOS
```

And back in my fish shell, I run the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-838am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

OK, so now we know we can load code by `cat`'ing a string and piping the result to the `source` command.  Let's again try a case statement:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    set myVar 5
    switch $myVar
    case 4
      echo '4'
    case 5
      echo '5'
    case '*'
      echo 'Not found'
  end
EOS
```

I still get the same error:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-839am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I try adding another 'end' before line 13:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-840am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

Same thing:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-841am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Damnit, I'm close!  I can feel it!  I'm sure it's just some stupid syntax issue in my case statement.

I try defining a function with a switch statement directly in my shell, and that works:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-842am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I notice two things here:

I didn't need any semi-colons in order for the case statement or the function to work, and
Both the case statement and the function itself required separate "end" lines.

I post [a StackExchange question](https://unix.stackexchange.com/questions/716957/fish-shell-whats-wrong-with-this-syntax), and eventually I get an answer: since my function is defined inside a string, my reference to $myVar should really be a reference to "\$myVar":

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-843am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

Running this version of the `baz` file via `./baz | source` fixes the glitch!

```
myusername@me ~/foo (master)> ./baz | source
myusername@me ~/foo (master)> bar
5
5
```
Not sure why it outputs "5" twice; my best guess is that the return value of a case statement in fish is the value of the variable that we "switch" on?  Not sure, but I'm now ready to try the final step in this experiment: passing in an array to the `cat`'ed function string:

```
#!/usr/bin/env bash

cat << EOS
  function bar
    echo ${@}
    set myVar 5
    switch "\$myVar"
      case ${@}
        echo 'myVar in nums!'
      case '*'
        echo 'myVar not in nums :-('
    end
  end
EOS
```

When I run this, I get good news!

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-848am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

To make sure I'm not getting a false positive, I change `set myVar 5` to `set myVar 6` in the script...

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-849am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...and re-run it:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-850am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Success!

That's all for today, I think.  I conquered a problem that was flummoxing me yesterday, and I feel a little better as a result.

Next line of code:

```
ksh )
  cat <<EOS
function rbenv {
  typeset command
EOS
  ;;
```

This is the 2nd branch of our outer case statement (the one which checks which shell the user is using).  If the user is using the `ksh` shell (aka the Korn shell), we employ a similar strategy of starting to `cat` a function definition, but this time we don't close that definition (that comes later).  For now, we just declare a variable named `command`, which is scoped locally with respect to the "rbenv" function according to [the Korn shell docs](https://web.archive.org/web/20161203165249/https://docstore.mik.ua/orelly/unix3/korn/ch06_05.htm):

> typeset without options has an important meaning: if a typeset statement is used inside a function definition, the variables involved all become local to that function (in addition to any properties they may take on as a result of typeset options).

Next lines of code:

```
* )
  cat <<EOS
rbenv() {
  local command
EOS
  ;;
```
This is the default, catch-all case for our "$shell" variable switch statement.  If the user's shell is not fish or ksh, then we "cat" our "rbenv" function definition, and (again) create a local variable named "command".

(stopping here for the day; 27022 words)

Next lines of code:

```
if [ "$shell" != "fish" ]; then
...
fi
```

Here we just check whether our user's shell is "fish".  If it's not, we execute the code inside the `if` block.

Next lines of code:

```
IFS="|"
cat <<EOS
...
EOS
```

Here we set the `IFS` variable (which stands for "internal field separator") to the pipe symbol "\|".  [We've covered this before](https://web.archive.org/web/20220715010436/https://www.baeldung.com/linux/ifs-shell-variable), but `IFS` is a special shell variable that determines how bash separates a string of characters into multiple strings.  For example, let's say we have a string `a|b|c|d|e`.  If `IFS` is set to the pipe character (as above), and if we pass our single string to a `for` loop, then bash will internally split our string into 5 strings ('a', 'b', 'c', 'd', and 'e') and iterate over each of them.

The `cat << EOS` line of code starts a new heredoc, so that we can finish implementing our `rbenv` function.

Next lines of code:

```
command="\${1:-}"
```
The `\` character is just used to tell bash not to interpret the `$` character as a call to execute the parameter expansion here.  By the time this line is resolved by the `eval` statement, it will appear as:

```
command="${1:-}"
```
Since the `$` is no longer escaped with a `\` inside the `eval` statement, `eval` will perform the parameter expansion at runtime.

Speaking of that parameter expansion, I know that's what this is, and I am almost positive that it has something to do with the first argument provided to the script (hence the `1`).  But I don't recognize the `:-` syntax or what it does.  Referring to the GNU docs and searching for `:-`, I find the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-854am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

The docs go on to show multiple variations of the `:-` syntax, however all of them contain something after the hyphen character.  None of them end in `:-` the way that our code does.  We'll have to do some experiments to see for sure what this does.

I write the following simple script:

```
#!/usr/bin/env bash

command="${1:-}"

echo "$command"
```

I `chmod` it and run it, both with and without arguments:

```
$ ./foo

$ ./foo bar baz buzz

bar
```

It looks like we did indeed capture the first argument.  And if there is no first argument, the variable is empty.

I decide to do a bit more Googling since I'm still not confident that I understand all the possible edge cases that I could test here.  I find [this StackExchange post](https://web.archive.org/web/20220531142657/https://unix.stackexchange.com/questions/338146/bash-defining-variables-with-var-number-default), which seems to say the same thing that the GNU docs said:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-856am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

That said, I think the way that the StackExchange post phrases the information is more friendly to beginners like me.  Moral of the story- sometimes I need to read the same information phrased in multiple ways before I can feel confident that I understand it.

I now know another edge case I can test- what if we were to provide a default value after the `:-` syntax?  Would that work as we expect?

Here's the new script, with a default value of `foo` for the first argument:

```
#!/usr/bin/env bash

command="${1:-foo}"

echo "$command"
```

And here's what happens when we call the script, again both with and without arguments:

```
$ ./foo

foo

$ ./foo bar baz buzz

bar
```

So the script continues to print the first argument if there is one, but if there isn't, it defaults the value to `foo`.  Cool!  That means our script populates the `command` variable with the first argument, but does not supply a default value of no argument is specified.

With this line of code, our in-progress heredoc string containing our rbenv function looks like this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-858am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

As you can see, we've *opened* (but not yet closed) the implementation of our `rbenv()` function.

(stopping here for the day; 28162 words; today I added a lot of writing prior to the previous day's stopping point)

Next lines of code:

```
  if [ "\$#" -gt 0 ]; then
    shift
  fi
```

If we recall, "$#" is shorthand for the number of arguments passed to the script.  So what this says is that, if the number of arguments is greater than zero, shift the first one off of the argument stack.  Again, the `\` escapes the `$` sign so that our currently-running shell doesn't resolve the `$#` symbol immediately, but instead lets the `eval` caller do so.

Next lines of code:

```
  case "\$command" in
  ${commands[*]})
    eval "\$(rbenv "sh-\$command" "\$@")";;
  *)
    command rbenv "\$command" "\$@";;
  esac
}
```

This block of code is short and familiar enough that we can analyze it all at once.  We create a `case` statement which branches depending on the value of the `command` that the user entered.

Recall that the value of the `commands` variable was set to `commands=(`rbenv-commands --sh`)`.  Therefore, if the user's command is present in the return value of `rbenv-commands --sh` (i.e. if it's equal to either `rehash` or `shell`), then we re-run the *shell function* version of `rbenv`, but this time pre-pending `sh-` to it.  If not, we use the `command` shell program to skip the `rbenv` function and go directly to the `rbenv` script inside `libexec`, passing the command to that script along with any other arguments the user included.

And with that, we've reached the end of the `rbenv-init` file!
