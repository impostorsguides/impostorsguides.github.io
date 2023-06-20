Let's start by looking at the "Usage" and "Summary" comments.

## [Comments](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-sh-shell#L3){:target="_blank" rel="noopener"}

```
# Summary: Set or show the shell-specific Ruby version
#
# Usage: rbenv shell <version>
#        rbenv shell -
#        rbenv shell --unset
#
# Sets a shell-specific Ruby version by setting the `RBENV_VERSION'
# environment variable in your shell. This version overrides local
# application-specific versions and the global version.
#
# <version> should be a string matching a Ruby version known to rbenv.
# The special version string `system' will use your default system Ruby.
# Run `rbenv versions' for a list of available Ruby versions.
#
# When `-` is passed instead of the version string, the previously set
# version will be restored. With `--unset`, the `RBENV_VERSION`
# environment variable gets unset, restoring the environment to the
# state before the first `rbenv shell` call.
```

From these comments, we learn that the purpose of `rbenv shell` is to set a specific version of Ruby in your current terminal tab (as opposed to in your current project directory, or a global version for all directories in your machine).  This means that even if you open the same project in a new terminal, it would have a different Ruby version, and switching between the two tabs could result in confusing behavior if the two Ruby versions are different enough.

We also learn that there are 3 ways to use `rbenv shell`:

 - `rbenv shell <version>`: sets the current terminal window's Ruby version to the version you specify.
 - `rbenv shell -`: rolls back to the previously-set version number, if there was one.
 - `rbenv shell --unset`: unsets the `RBENV_VERSION` environment variable, meaning the new value will be sourced from:
    - the local directory's Ruby version (as determined by any `.ruby-version` file),
    - the global Ruby version (as determined by `~/.rbenv/version`), or
    - the machine's default system version.

Next, we'll look at the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/shell.bats){:target="_blank" rel="noopener"}

### Sad path- shell integration disabled

After the shebang and the loading of `test_helper`, the first spec is:

```
@test "shell integration disabled" {
  run rbenv shell
  assert_failure "rbenv: shell integration not enabled. Run \`rbenv init' for instructions."
}
```

By definition, `rbenv shell` is part of RBENV's shell integrations.  Therefore a user can only run `rbenv shell` if they've already enabled shell integrations (i.e. they've included the `eval "$(rbenv init -)"` line in their `.zshrc`, or the equivalent in their `.bashrc`).   This test asserts that, when the user has not run this `init` command, that `rbenv shell` fails with a specific error message.

### Getting the shell Ruby version - failure modes

The next few tests are for cases where shell integration is enabled but, for one reason or another, no Ruby version is retrievable.

First test:

```
@test "shell integration enabled" {
  eval "$(rbenv init -)"
  run rbenv shell
  assert_success "rbenv: no shell-specific version configured"
}
```

In this test, we run the `init` command as a setup step, and then we run `rbenv shell` and assert that the command ran successfully.

However, since we haven't yet set a Ruby version, we get the message "no shell-specific version configured".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "no shell version" {
  mkdir -p "${RBENV_TEST_DIR}/myproject"
  cd "${RBENV_TEST_DIR}/myproject"
  echo "1.2.3" > .ruby-version
  RBENV_VERSION="" run rbenv-sh-shell
  assert_failure "rbenv: no shell-specific version configured"
}
```

Here we do a bit more test setup, but we're still testing a failure mode:

 - We create a test Ruby project directory and `cd` into it.
 - Within that directory, we create a `.ruby-version` file containing a Ruby version, however we manually set `RBENV_VERSION` to the empty string before running `rbenv sh-shell`.

When there is no prior `RBENV_VERSION` set *and* the user doesn't provide an argument to `rbenv shell`, the expectation is that an error message should be printed and the program should exit with a non-zero return code.

<!-- You'll notice we didn't call the `init` command as part of the setup, but we're not asserting that we get the same error as test #1.  If you look at the command that was run in test #1, you'll see that it's `run rbenv shell`, which would need the `init` command to have been run in order for it to succeed.  They purposely refrained from running the `init` command *and* ran a command which depended on the `init` logic, in order to verify the specific error message was returned.

In test #3 above, we *also* refrain from running the `init` command, however this time we call `run rbenv-sh-shell` instead.  This new command points directly to the file for the `shell` command, bypassing the `rbenv` shell function that `init` constructs for us, so we don't need to bother with `init` in this case.  It's essentially a shortcut that we can employ for testing purposes. -->

### Getting the shell Ruby version - happy path

Next test:

```
@test "shell version" {
  RBENV_SHELL=bash RBENV_VERSION="1.2.3" run rbenv-sh-shell
  assert_success 'echo "$RBENV_VERSION"'
}
```

Here we provide the bare minimum information that `rbenv shell` needs to do its job:

 - a specific shell program to use, as stored in the `RBENV_SHELL` environment variable, and
 - a specific Ruby version, as stored in the `RBENV_VERSION` environment variable.

Once the program knows these things, it can print the requested Ruby version back to the user.  We assert that it does this, and exits successfully.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "shell version (fish)" {
  RBENV_SHELL=fish RBENV_VERSION="1.2.3" run rbenv-sh-shell
  assert_success 'echo "$RBENV_VERSION"'
}
```

Here we do the same test as the one before, except this time we set that `RBENV_SHELL` is set to `fish` instead of `bash`.

#### `run rbenv shell` vs. `run rbenv-sh-shell`

Notice that, in both of the above cases, the expected output is a snippet of code, including an `echo` statement.  That's because the command we're running is `run rbenv-sh-shell`, **not** `run rbenv shell`.  Those are two subtly different commands.

`run rbenv shell` assumes that we have shell integration enabled, whereas `run rbenv-sh-shell` does not.  The latter will output code, which will be executed by the call to `eval` in our shell function.  That's why, when we write tests which run `rbenv-sh-shell`, our assertions will all test that specific code is printed to the screen.

### Reverting to an earlier Ruby version

Next test:

```
@test "shell revert" {
  RBENV_SHELL=bash run rbenv-sh-shell -
  assert_success
  assert_line 0 'if [ -n "${RBENV_VERSION_OLD+x}" ]; then'
}
```

We set `RBENV_SHELL` to `bash` and run `rbenv sh-shell -`.  We assert that the command was successful, and that the first line of output was a snippet of `bash` code, i.e.:

```
if [ -n "${RBENV_VERSION_OLD+x}" ]; then
```

Again, we're testing `rbenv-sh-shell`, not `rbenv shell`, so our expected output will be code that the `rbenv` shell function will `eval`.

The code that is printed to the terminal depends on what shell you're using, i.e. `bash`, `fish`, or another shell.  We want to make sure the right code is `eval`'ed for the right shell program.  This test covers that case, for the `bash` shell.

Same with the next test:

```
@test "shell revert (fish)" {
  RBENV_SHELL=fish run rbenv-sh-shell -
  assert_success
  assert_line 0 'if set -q RBENV_VERSION_OLD'
}
```

This covers the same case as the previous test, but for the `fish` shell.

### Unsetting the current Ruby version

Next spec:

```
@test "shell unset" {
  RBENV_SHELL=bash run rbenv-sh-shell --unset
  assert_success
  assert_output <<OUT
RBENV_VERSION_OLD="\${RBENV_VERSION-}"
unset RBENV_VERSION
OUT
}
```

Here we pass the `RBENV_SHELL=bash` env var and the `--unset` flag to `rbenv sh-shell` and assert that, in the case of `bash`, the output is bash-specific code for setting `RBENV_VERSION_OLD` and unsetting `RBENV_VERSION`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "shell unset (fish)" {
  RBENV_SHELL=fish run rbenv-sh-shell --unset
  assert_success
  assert_output <<OUT
set -gu RBENV_VERSION_OLD "\$RBENV_VERSION"
set -e RBENV_VERSION
OUT
}
```

This is again the fish-specific version of the previous spec.  Nothing new to see here except `RBENV_SHELL=fish`.

### Changing the shell version

Next spec:

```
@test "shell change invalid version" {
  run rbenv-sh-shell 1.2.3
  assert_failure
  assert_output <<SH
rbenv: version \`1.2.3' not installed
false
SH
}
```

Here we test the sad-path case where we attempt to set the local shell version to a version number which is not installed in the system.  We do no setup work, we simply run the `sh-shell` program and assert that an error message is `echo`d to the `eval` command.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "shell change version" {
  mkdir -p "${RBENV_ROOT}/versions/1.2.3"
  RBENV_SHELL=bash run rbenv-sh-shell 1.2.3
  assert_success
  assert_output <<OUT
RBENV_VERSION_OLD="\${RBENV_VERSION-}"
export RBENV_VERSION="1.2.3"
OUT
}
```

This is a happy-path, `bash`-specific test which asserts that, when a given Ruby version has been installed and the user tries to set their shell's Ruby version to that version, the command succeeds and does in fact set the shell version to that number.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Last test:

```
@test "shell change version (fish)" {
  mkdir -p "${RBENV_ROOT}/versions/1.2.3"
  RBENV_SHELL=fish run rbenv-sh-shell 1.2.3
  assert_success
  assert_output <<OUT
set -gu RBENV_VERSION_OLD "\$RBENV_VERSION"
set -gx RBENV_VERSION "1.2.3"
OUT
}
```

This is the same spec as the previous one, but for the `fish` shell.  Instead of testing that certain `bash` code is printed to the screen, we test that certain `fish` code is printed.

### Testing **what** code does vs. testing **how** it does it

One final note- when we assert that certain code is printed to the screen (as we do for many of the tests above), we're testing implementation instead of behavior.  This is considered by many programmers to be less-than-great practice:

> <div style="margin: 2em; border-bottom: 1px solid grey"></div>
>
> Tests that are independent of implementation details are easier to maintain since they don't need to be changed each time you make a change to the implementation. They're also easier to understand since they basically act as code samples that show all the different ways your class's methods can be used, so even someone who's not familiar with the implementation should usually be able to read through the tests to understand how to use the class.
>
> [Google Testing Blog](https://web.archive.org/web/20230327072205/https://testing.googleblog.com/2013/08/testing-on-toilet-test-behavior-not.html){:target="_blank" rel="noopener"}
>
> <div style="margin: 2em; border-bottom: 1px solid grey"></div>
>
> When I test for behavior, I’m saying:
>
> “I don’t care how you come up with the answer, just make sure that the answer is correct under this set of circumstances.”
>
> When I test for implementation, I’m saying:
>
> “I don’t care what the answer is, just make sure you do this thing while figuring it out.”
>
> \- [LaunchScout.com](https://web.archive.org/web/20230323231337/https://launchscout.com/blog/testing-behavior-vs-testing-implementation){:target="_blank" rel="noopener"}
>
> <div style="margin: 2em; border-bottom: 1px solid grey"></div>
>
> If I “verify” that my car works by checking for the presence of various parts, then I haven’t really actually verified anything. I haven’t demonstrated that the system under test (the car) actually meets spec (can drive).
>
> If I test the car by actually driving it, then the questions of whether the car has various components become moot. If for example the car can travel down the road, we don’t need to ask if the car has wheels. If it didn’t have wheels it wouldn’t be moving.
>
> All of our “implementation” questions can be translated into more meaningful “behavior” questions.
>
> - Does it have an ignition? -> Can it start up?
> - Does it have an engine and wheels? -> Can it drive?
> - Does it have brakes? -> Can it stop?
>
> Lastly, behavior tests are better than implementation tests because behavior tests are more loosely coupled to the implementation. I ask “Can it start up?” instead of “Does it have an engine?” then I’m free to, for example, change my car factory from a gasoline-powered car factory to an electric car factory without having to change the set of tests that I perform. In other words, behavior tests enable refactoring.
>
> [Code With Jason](https://web.archive.org/web/20230209001509/https://www.codewithjason.com/testing-implementation-vs-behavior-rails/){:target="_blank" rel="noopener"}
>
> <div style="margin: 2em; border-bottom: 1px solid grey"></div>
>

Testing for the output of specific code to be evaluated by `eval` makes the test more brittle.  It's testing the implementation instead of testing the result.  If the code which is output gets refactored somehow, the tests would break.

What if we instead test that running `rbenv shell` results in a change to our shell's Ruby version?  Then we could refactor the implementation of that command without breaking its test.  For example, instead of:

```
@test "shell version" {
  RBENV_SHELL=bash RBENV_VERSION="1.2.3" run rbenv-sh-shell
  assert_success 'echo "$RBENV_VERSION"'
}
```

We could write:

```
@test "shell version foo" {
  eval "$(rbenv init -)"
  new_version="1.2.3"
  RBENV_SHELL=bash RBENV_VERSION="$new_version" run rbenv shell
  assert_success "$new_version"
}
```

When I add the above test into the spec file and run the full file, everything passes.  So in theory, at least, this approach could be applied to RBENV.  And it seems like the user needs shell integration enabled in order to use `rbenv shell` anyway, so there's no harm in refactoring the tests to all resemble the above.

I submitted [a PR](https://github.com/rbenv/rbenv/pull/1479){:target="_blank" rel="noopener"} to check whether the core team would find this useful, and as of June 17, 2023 I'm waiting for a response.

Let's now move on to the file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-sh-shell){:target="_blank" rel="noopener"}

Skipping the shebang and "Usage" comments that we've already looked at, the first block of code is:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

This hopefully looks familiar by now:

 - Setting "exit on error mode" via `set -e`.
 - Setting verbose mode via `set -x`.

### Printing completions

 Next block of code:

 ```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --unset
  echo system
  exec rbenv-versions --bare
fi
 ```

Looks like we have 2 hard-coded completions (`--unset` and `system`), as well as the dynamic Ruby versions which are output from `rbenv-versions –bare` and which we've seen before.

### Setting local variables for the version and shell

Next block of code:

```
version="$1"
shell="$(basename "${RBENV_SHELL:-$SHELL}")"
```

We just set two variables:

 - one named `version` which is equal to the first argument given to `rbenv shell`, and
 - the other named `shell` which is set to the user's shell program name.

`$RBENV_SHELL` resolves to `zsh` on my Macbook, and `$SHELL` resolves to `/bin/zsh`.  The output of the `basename` command when given (for example) `/bin/zsh` is just `zsh`.

### If no argument is passed

Next block of code:

```
if [ -z "$version" ]; then
  if [ -z "$RBENV_VERSION" ]; then
    echo "rbenv: no shell-specific version configured" >&2
    exit 1
  else
    echo 'echo "$RBENV_VERSION"'
    exit
  fi
fi
```

If our new `version` variable is empty, then we do one of two things:

 - If the value of the `RBENV_VERSION` env var is also empty, then we print a helpful error message before exiting.
 - Otherwise, we `echo` an `echo` command.

We use `>&2` to redirect the `if`-clause's message to `stderr`.  We do this because, without `>&2`, we would be printing to `stdout` instead.  This would cause an error when the message reaches the `eval` command which calls `rbenv-sh-shell`.

### Unsetting the Ruby shell version

Next block of code:

```
if [ "$version" = "--unset" ]; then
  case "$shell" in
  fish )
    echo 'set -gu RBENV_VERSION_OLD "$RBENV_VERSION"'
    echo "set -e RBENV_VERSION"
    ;;
  * )
    echo 'RBENV_VERSION_OLD="${RBENV_VERSION-}"'
    echo "unset RBENV_VERSION"
    ;;
  esac
  exit
fi
```

If the argument `$1` that we stored in our `version` variable was not a version number at all, but rather the string `"--unset"`, that means the user wants to unset the Ruby version for this shell.  In this case, we set `RBENV_VERSION_OLD` to our current value of `RBENV_VERSION`, and then use the `unset` command to remove any value from `RBENV_VERSION`.

### Rolling back to a previous Ruby version

Next block of code:

```
if [ "$version" = "-" ]; then
  case "$shell" in
  ...
  esac
  exit
fi
```

This `case` statement is quite long, so I'll break it up into chunks.

We start with a similar situation as the last block of code, in which the value stored in the `version` variable is not a version number at all.  In this case, instead of testing whether the value is the string `--unset`, we test whether it's a single hyphen character `-`.

If it is, then we execute a similar case statement to the `--unset` block, which branches on the value of the `shell` variable.

#### If the current shell is `fish`

First case statement is:

```
  fish )
    cat <<EOS
if set -q RBENV_VERSION_OLD
  ...
else
  ...
end
EOS
    ;;
```

We're `cat`'ing a here-doc string containing a bunch of commands which will be evaluated by the `rbenv` shell function:

[The fish docs](https://web.archive.org/web/20221009140752/https://fishshell.com/docs/current/cmds/set.html){:target="_blank" rel="noopener"} tell us that `set -q` is how we test whether a variable has been defined.  There's no output, but the exit code is the number of variables passed to `set -q` which were undefined.  So since we only passed one variable to `set -q`, i.e. `RBENV_VERSION_OLD`, our exit code is 0 if `RBENV_VERSION_OLD` is defined and 1 if it is undefined.

##### If `RBENV_VERSION_OLD` is set

 If the exit code of the `set -q` command is 0, that means 0 variables in the list of variables were undefined.  Since our "list of variables" consisted of just `RBENV_VERSION_OLD`, that means `RBENV_VERSION_OLD` was defined.  According to [fish's `if` docs](https://web.archive.org/web/20221009122727/https://fishshell.com/docs/current/cmds/if.html){:target="_blank" rel="noopener"}, that means our `if` check would be true, and we execute the following code:

```
  if [ -n "\$RBENV_VERSION_OLD" ]
    set RBENV_VERSION_OLD_ "\$RBENV_VERSION"
    set -gx RBENV_VERSION "\$RBENV_VERSION_OLD"
    set -gu RBENV_VERSION_OLD "\$RBENV_VERSION_OLD_"
    set -e RBENV_VERSION_OLD_
  else
    set -gu RBENV_VERSION_OLD "\$RBENV_VERSION"
    set -e RBENV_VERSION
  end
```

Just because `RBENV_VERSION_OLD` has been set, doesn't mean it has a value.  It could be set to `null`.

Here we check whether it has a non-zero value.  The `[ -n ... ]` syntax does the same thing in `fish` as it does in `bash`.

If it does have a value:

 - we set a temporary variable named `RBENV_VERSION_OLD_` equal to the current value of `RBENV_VERSION`.  Note the trailing underscore character, which makes this a different variable from `RBENV_VERSION_OLD`.
 - We then set the `RBENV_VERSION` variable equal to the value of `RBENV_VERSION_OLD` (more specifically, a global environment variable, as denoted by the `-gx` flags).
 - We then set `RBENV_VERSION_OLD` equal to the value of our temp variable (the one with the underscore at the end).
 - Lastly, we unset (aka delete) the `RBENV_VERSION_OLD_` temp variable.

All this has the effect of swapping the values of `RBENV_VERSION_OLD` and `RBENV_VERSION`.

If `[ -n RBENV_VERSION_OLD]` is false, then we execute the logic in the `else` block of code.  This block sets a new value for `RBENV_VERSION_OLD` which is equal to our current `RBENV_VERSION` value, and then unsets the value of `RBENV_VERSION` via the `set -e` command (here, `e` stands for `erase`).

##### If `RBENV_VERSION_OLD` is NOT set

If `RBENV_VERSION_OLD` **was** undefined, we'll execute the `else` branch, which does the following:

```
  echo "rbenv: RBENV_VERSION_OLD is not set" >&2
  false
```

This just prints an error message to STDERR.  The `false` command at the end is how the `fish` shell sets a non-zero exit status (see the docs [here](https://web.archive.org/web/20230523203818/https://fishshell.com/docs/current/cmds/false.html){:target="_blank" rel="noopener"}).

#### If the current shell is NOT `fish`

Next block of code is the "non-fish" version of the exact same process as above:

```
  * )
    cat <<EOS
if [ -n "\${RBENV_VERSION_OLD+x}" ]; then
  if [ -n "\$RBENV_VERSION_OLD" ]; then
    RBENV_VERSION_OLD_="\$RBENV_VERSION"
    export RBENV_VERSION="\$RBENV_VERSION_OLD"
    RBENV_VERSION_OLD="\$RBENV_VERSION_OLD_"
    unset RBENV_VERSION_OLD_
  else
    RBENV_VERSION_OLD="\$RBENV_VERSION"
    unset RBENV_VERSION
  fi
else
  echo "rbenv: RBENV_VERSION_OLD is not set" >&2
  false
fi
EOS
    ;;
```

We can go faster this time around, since we can assume that this block of code does the same thing in `bash` that the previous block of code does in `fish`.

##### If `RBENV_VERSION_OLD` is set

Let's look at the first `if` condition:

```
if [ -n "\${RBENV_VERSION_OLD+x}" ]; then
```

According to [StackOverflow](https://web.archive.org/web/20190823232017/https://stackoverflow.com/questions/46891981/what-does-argumentx-mean-in-bash){:target="_blank" rel="noopener"}, the point of the `+x` in the parameter expansion is to "deterimine(s) if a variable ARGUMENT is set to any value (empty or non-empty) or not."

Similar to the fish script, we're just querying if the variable has been set, even if it's just to the empty string.  We could just use the simpler `if [ -n "${RBENV_VERSION_OLD}" ]` (and in fact we do exactly that on the next line), but that test would be falsy in the case where `RBENV_VERSION_OLD` is set to "", whereas `[ -n "\${RBENV_VERSION_OLD+x}" ]` is truthy in that case.

We would want that case to be truthy, because we want the ability to have an `else` clause where we tell the user that the variable is unset.  That's why we use the somewhat-confusing `+x` syntax instead.

#### Summary of the `-` argument

Taken together, this case statement appears to either set our current `RBENV_VERSION` value equal to the value of `RBENV_VERSION_OLD`, or to unset `RBENV_VERSION` entirely if we don't have an old value to roll back to.

### Happy path- setting the shell's Ruby version

Last block of code for this file:

```
# Make sure the specified version is installed.
if rbenv-prefix "$version" >/dev/null; then
  ...
else
  ...
fi
```

#### Checking whether the specified version is installed

We run `rbenv prefix` on the version param passed to `rbenv shell`.  For example, if we type `rbenv shell 2.7.5`, then we run `rbenv prefix 2.7.5`.

On my machine, that returns the filepath to the directory for version 2.7.5 (`/Users/myusername/.rbenv/versions/2.7.5`).  If I pass `rbenv prefix` and invalid version, I get an error:

```
$ rbenv prefix foo

rbenv: version `foo' not installed
```

So if our `version` variable corresponds to a version that we have installed in our system, we execute the next block of code.

#### If the requested version is valid

```
  if [ "$version" != "$RBENV_VERSION" ]; then
    case "$shell" in
    fish )
      echo 'set -gu RBENV_VERSION_OLD "$RBENV_VERSION"'
      echo "set -gx RBENV_VERSION \"$version\""
      ;;
    * )
      echo 'RBENV_VERSION_OLD="${RBENV_VERSION-}"'
      echo "export RBENV_VERSION=\"$version\""
      ;;
    esac
  fi
```

If we've pass a *valid* version, i.e. one that **does** have a prefix, we check whether our new version of Ruby is different from our current version.

 - If they are different:
    - We set `RBENV_VERSION_OLD` equal to the current version of Ruby, or null if there is no current version.
    - We then set the Ruby version equal to the version that the user requested, and export `RBENV_VERSION` so that it may be used elsewhere.
 - If the two version numbers are the same, we do nothing.  Hence, no `else` condition for this `if` check.

#### If the requested version is NOT valid

What if we've passed a version of Ruby that **doesn't** have a prefix, i.e. was not installed by RBENV?

```
  echo "false"
  exit 1
```

If we've passed an *invalid* version, we `echo "false"` and exit with a non-zero status code.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for `rbenv sh-shell`.  On to the next file.
