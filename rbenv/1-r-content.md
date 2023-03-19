As usual, let's first look at the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/shell.bats)

After the shebang and the loading of `test_helper`, the first spec is:

```
@test "shell integration disabled" {
  run rbenv shell
  assert_failure "rbenv: shell integration not enabled. Run \`rbenv init' for instructions."
}
```

By definition, `rbenv shell` is part of RBENV's shell integrations.  Therefore a user can only run `rbenv shell` if they've already enabled shell integrations (i.e. they've included the `eval "$(rbenv init -)"` line in their `.zshrc`, or the equivalent in their `.bashrc`).   This test asserts that, when the user has not run this `init` command, that `rbenv shell` fails with a specific error message.

Next test:

```
@test "shell integration enabled" {
  eval "$(rbenv init -)"
  run rbenv shell
  assert_success "rbenv: no shell-specific version configured"
}
```

This test is the happy-path alternative to the first test, which is the sad-path.  In this test, we *do* run the `init` command as a setup step, and then we run `rbenv shell` and assert that the command ran successfully.  Since we haven't yet set a Ruby version, we get the message "no shell-specific version configured".

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

Here we do a bit more test setup, but we're still testing a failure mode.  We create a test Ruby project directory and `cd` into it.  Within that directory, we create a `.ruby-version` file containing a Ruby version, however we manually set `RBENV_VERSION` to the empty string before running `rbenv sh-shell`.  When there is no prior `RBENV_VERSION` set *and* the user doesn't provide an argument to `rbenv shell`, the expectation is that an error message should be printed and the program should exit with a non-zero return code.

You'll notice we didn't call the `init` command as part of the setup, but we're not asserting that we get the same error as test #1.  If you look at the command that was run in test #1, you'll see that it's `run rbenv shell`, which would need the `init` command to have been run in order for it to succeed.  They purposely refrained from running the `init` command *and* ran a command which depended on the `init` logic, in order to verify the specific error message was returned.  In test #3 above, we *also* refrain from running the `init` command, however this time we're running `run rbenv-sh-shell` instead.  This new command points directly to the file for the `shell` command, bypassing the `rbenv` shell function that `init` constructs for us, so we don't need to bother with `init` in this case.  It's essentially a shortcut that we can employ for testing purposes.

Next test:

```
@test "shell version" {
  RBENV_SHELL=bash RBENV_VERSION="1.2.3" run rbenv-sh-shell
  assert_success 'echo "$RBENV_VERSION"'
}
```

Here we provide the bare minimum information that `rbenv shell` needs to do its job- a value for the user's shell and one for their Ruby version.  Once the program has this, it can print the requested Ruby version back to the user, so we assert that it does this and exits successfully.

Next test:

```
@test "shell version (fish)" {
  RBENV_SHELL=fish RBENV_VERSION="1.2.3" run rbenv-sh-shell
  assert_success 'echo "$RBENV_VERSION"'
}
```

Here we do the same test as the one before, except this time we check that `rbenv shell` works with the "fish" shell.

Next test:

```
@test "shell revert" {
  RBENV_SHELL=bash run rbenv-sh-shell -
  assert_success
  assert_line 0 'if [ -n "${RBENV_VERSION_OLD+x}" ]; then'
}
```

This is a bit weird.  I get that we're setting the shell to be bash, and then running the command and asserting a 0 exit code.  But I don't get the last line in the test.  It reads like it expects line 0 of the output to be 'if [ -n "${RBENV_VERSION_OLD+x}" ]; then'.  But this is bash code, and the command under test is the command to revert the shell Ruby version to the previous version.  Why, then, wouldn't we test that the first line of output is the new Ruby version?  And why would we output a bash `if` command to the user, ever?

(stopping here for the day; 66768 words)


I think I want to test this.  I open `bash` in my terminal, I do the following:

```
RBENV_SHELL=bash rbenv sh-shell -
```

When I do that, I get the following output:

```
if [ -n "${RBENV_VERSION_OLD+x}" ]; then
  if [ -n "$RBENV_VERSION_OLD" ]; then
    RBENV_VERSION_OLD_="$RBENV_VERSION"
    export RBENV_VERSION="$RBENV_VERSION_OLD"
    RBENV_VERSION_OLD="$RBENV_VERSION_OLD_"
    unset RBENV_VERSION_OLD_
  else
    RBENV_VERSION_OLD="$RBENV_VERSION"
    unset RBENV_VERSION
  fi
else
  echo "rbenv: RBENV_VERSION_OLD is not set" >&2
  false
fi
bash-3.2$
```

WTF?  That's really weird, especially since when I run `RBENV_SHELL=bash rbenv shell -`, I get:

```
rbenv: shell integration not enabled. Run `rbenv init' for instructions.
```

Ohhhhhh, right.  Technically we're testing `rbenv-sh-shell`, not `rbenv shell`.  When you run the file itself with the "-" argument, it `echo`s the above code for the `eval` command in the shell function to execute.  Apparently that's what we're testing here.  I'm assuming the reason we're doing that is because this code depends on whether you're using `fish` or another shell, and we want to make sure the right code is `eval`'ed for the right shell program.  Same with the next test:

```
@test "shell revert (fish)" {
  RBENV_SHELL=fish run rbenv-sh-shell -
  assert_success
  assert_line 0 'if set -q RBENV_VERSION_OLD'
}
```

In retrospect, I also realize that I was mistaken about the output of a few previous tests.  Rather than printing the Ruby version as output, the command's output is `'echo "$RBENV_VERSION"'`, i.e. an `echo` statement for `eval` to evaluate.  My bad!

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

Next spec:

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

Next spec:

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

This is the same spec as the previous one, but for the `fish` shell.  And that's the last spec for `rbenv shell`!

One final note- it seems to me that testing for the output of specific code to be evaluated by `eval` could make the test more brittle.  It's testing the implementation instead of testing the result.  If the code which is output gets refactored somehow, the tests would break.  Therefore that wouldn't be a green-to-green refactor.  If instead we test that running the command had the intended effect of the command under test, then we could refactor the implementation of that command without breaking its test.  For example, instead of:

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

I just added the above test into the spec file and ran the full file, and everything passed.

And it seems like the user needs shell integration enabled in order to use `rbenv shell` anyway, so there's no harm in refactoring the tests to all resemble the 2nd one.  I submit [a Github issue](https://github.com/rbenv/rbenv/issues/1455) to check whether the core team would find this useful.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-sh-shell)

Now for the file itself.

This first block is pretty long, but it's all code we should be familiar with by now:

```
#!/usr/bin/env bash
#
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

set -e
[ -n "$RBENV_DEBUG" ] && set -x

# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --unset
  echo system
  exec rbenv-versions --bare
fi
```

`bash` shebang
Usage and Summary instructions, with some description too.
`set -e` and `RBENV_DEBUG` (you're likely tired of me repeating myself by now, I know I am lol)
Tab completion code.  Looks like we have 2 hard-coded completions (`--unset` and `system`), as well as the dynamic Ruby versions which are output from `rbenv-versions –bare` and which we've seen before)

Next block of code:

```
version="$1"
shell="$(basename "${RBENV_SHELL:-$SHELL}")"
```

We just set two variables, one named `version` which is equal to the first argument given to `rbenv shell`, and the other named `shell` which is set to the user's shell program name.  `$RBENV_SHELL` resolves to "zsh" on my Macbook, and `$SHELL` resolves to "/bin/zsh".  The output of the `basename` command when given (for example) "/bin/zsh" is just "zsh".

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

If our new `version` variable is empty, then we do one of two things.  If the value of the `RBENV_VERSION` env var is also empty, then we echo a helpful error message before exiting.  Otherwise, we `echo` an `echo` command.  We do this because this code will be executed by the `exec` function.  We can verify this by adding simple loglines to the `rbenv` shell function definition, just before the call to `exec`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-849am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When we open a new terminal and run the following command, we get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-850am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

We `echo` the command we want to run (in this case, that's the same `echo` command) because the goal is to print out the definition of the Ruby version which has been set at some point by `RBENV_VERSION` (we set it manually here to trigger the correct branch of the `if` condition, but it could have just as easily been set by an RBENV hook or something to that effect).

(stopping here for the day; 64096 words)

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

If the first argument to `rbenv shell` (which we stored in the variable `version`) was actually *not* a version number, but rather the flag "--unset", that means the user wants to unset the Ruby version for this shell.  In that case, how we do that depends on which shell they're using.  In either case, we first save their current version in a new shell variable for posterity before deleting the old value.

If they're using the fish shell, we use the `set -gu` command to save away that old value.  According to [the fish docs](https://web.archive.org/web/20221009140752/https://fishshell.com/docs/current/cmds/set.html), the `-g` flag "Causes the specified shell variable to be given a global scope. Global variables don't disappear and are available to all functions running in the same shell. They can even be modified."  And the `-u` flag "Causes the specified shell variable to NOT be exported to child processes."  According to [the PR which introduced these flags](https://github.com/rbenv/rbenv/commit/c4d97ad3927c2670d293ac8910ff2bbcd05a06c7), these flags somehow help ensure that `RBENV_VERSION_OLD` is never exported.  If this is our goal, I'm not sure what is accomplished via the one-two punch of a) giving the variable global scope, and b) making it unavailable to child processes.  Maybe this will become clearer as I read the script.

However, if we assume that the fish and non-fish versions of this case statement behave in the exact same way (which I don't know enough to say for sure yet but which seems reasonable), then we could look at the next branch of the case statement to give us a clue about that unclear fish logic:

```
  * )
    echo 'RBENV_VERSION_OLD="${RBENV_VERSION-}"'
    echo "unset RBENV_VERSION"
    ;;
```

Here we're setting (but not exporting) `RBENV_VERSION_OLD` to be equal to `RBENV_VERSION`, and we're using parameter expansion to check whether `RBENV_VERSION` was previously set.  If it's not, the parameter expands to be the null string, making the value of `RBENV_VERSION_OLD` equal to null.  If we assume that the non-fish version of the code does the same as the fish version of the code, then:

```
    echo 'set -gu RBENV_VERSION_OLD "$RBENV_VERSION"'
```

…is probably the fish way of doing:

```
    echo 'RBENV_VERSION_OLD="${RBENV_VERSION-}"'
```

…in bash.

As a side note, the `case` statement which switches on the value of `$shell` is (I'm guessing) the reason this file has `-sh-` in it.  As we discussed before, any command containing shell-specific logic seems to use this naming convention.

Next block of code:

```
if [ "$version" = "-" ]; then
  case "$shell" in
  …
  esac
  exit
fi
```

This `case` statement is quite long, so I'll break it up into chunks.  Here we test whether that first argument (which, again, we stored in the variable named `version`) is equal to a single hyphen character.  If it is, then we execute the case statement which branches on the value of the `shell` variable.

First case statement is:

```
  fish )
    cat <<EOS
if set -q RBENV_VERSION_OLD
  if [ -n "\$RBENV_VERSION_OLD" ]
    set RBENV_VERSION_OLD_ "\$RBENV_VERSION"
    set -gx RBENV_VERSION "\$RBENV_VERSION_OLD"
    set -gu RBENV_VERSION_OLD "\$RBENV_VERSION_OLD_"
    set -e RBENV_VERSION_OLD_
  else
    set -gu RBENV_VERSION_OLD "\$RBENV_VERSION"
    set -e RBENV_VERSION
  end
else
  echo "rbenv: RBENV_VERSION_OLD is not set" >&2
  false
end
EOS
    ;;
```

We're `cat`'ing a here-doc string containing a bunch of commands which will be evaluated by the shell function.  [The fish docs](https://web.archive.org/web/20221009140752/https://fishshell.com/docs/current/cmds/set.html) tell us that `set -q` is how we test whether a variable has been defined.  There's no output, but the exit code is the number of variables passed to `set -q` which were undefined.  So since we only passed one variable to `set -q`, i.e. `RBENV_VERSION_OLD`, our exit code is 0 if `RBENV_VERSION_OLD` is defined and 1 if it is undefined.

If our exit code is 1, according to [fish's `if` docs](https://web.archive.org/web/20221009122727/https://fishshell.com/docs/current/cmds/if.html), we'll execute the `else` branch, which just prints an error message to STDERR.  I was confused by the inclusion of `false` on the next line, since by now I've learned that bash doesn't have true "return values" the way that Ruby does; it only has exit statuses.  After Googling around a bit for "bash booleans", I found [this StackOverflow link](https://web.archive.org/web/20221010223229/https://stackoverflow.com/questions/2953646/how-can-i-declare-and-use-boolean-variables-in-a-shell-script) which explains:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-851am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

So here we're using `false` to send a command to the shell to exit with a non-zero return status.  The above SO answer is for bash, but [it appears to work the same way in fish](https://fishshell.com/docs/current/cmds/false.html#cmd-false).

Back to the first of our `if` statements.  If `RBENV_VERSION_OLD` is set and our exit code is 0, then we execute the logic inside this `if` statement.  That logic is:

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

At the risk of beating a dead horse, if we've reached this block, that means `RBENV_VERSION_OLD` has been set.  But just because it's been set, doesn't mean it has a value.  It could be set to `null`.

Here we check whether it has a non-zero value.  If it does, we set a temporary variable named `RBENV_VERSION_OLD_` equal to the current value of `RBENV_VERSION`.  Note the trailing underscore character, which makes this a different variable from `RBENV_VERSION_OLD`.  We then set the `RBENV_VERSION` variable equal to the value of `RBENV_VERSION_OLD` (more specifically, a global environment variable, as denoted by the `-gx` flags).  We then set `RBENV_VERSION_OLD` equal to the value of our temp variable (the one with the underscore at the end), and lastly we unset (aka delete) the `RBENV_VERSION_OLD_` temp variable.  All this has the effect of swapping the values of `RBENV_VERSION_OLD` and `RBENV_VERSION`.

Otherwise, if we don't *have* a value for `RBENV_VERSION_OLD`, then we execute the logic in the `else` block of code, which is to *create* a value for `RBENV_VERSION_OLD` which is equal to our current `RBENV_VERSION` value, and then we unset that current Ruby version.

Taken together, this case statement appears to either set our current `RBENV_VERSION` value equal to the value of `RBENV_VERSION_OLD` (as well as bumping the value for that `_OLD` variable for posterity), or to unset `RBENV_VERSION` entirely if we don't have an old value to roll back to.  Since we're still inside the `if [ "$version" = "-" ]; then` check, we *only* do this if the first argument passed to `rbenv shell` was `-`.

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

We can go faster this time around, since now we know what the code and its purpose does.  But there may be some interesting bits of bash syntax that we can learn something from.

(stopping here for the day; 65226 words)

Let's look at the first `if` condition:

```
if [ -n "\${RBENV_VERSION_OLD+x}" ]; then
```

According to [StackOverflow](https://web.archive.org/web/20190823232017/https://stackoverflow.com/questions/46891981/what-does-argumentx-mean-in-bash), the point of the `+x` in the parameter expansion is to "deterimine(s) if a variable ARGUMENT is set to any value (empty or non-empty) or not."  Similar to the fish script, we're just querying if the variable has been set, even if it's just to the empty string.  We could just use the simpler `if [ -n "${RBENV_VERSION_OLD}" ]` (and in fact we do exactly that on the next line), but that test would be falsy in the case where `RBENV_VERSION_OLD` is set to "", but we would want that case to be truthy, because we want the ability to have an `else` clause where we tell the user that the variable is unset.

It might be instructive to look at the commit which introduced this relatively more complicated conditional logic, to see if it used to be simpler (and if so, whether there's any context on why the additional complexity was needed).  I find [this commit](https://github.com/rbenv/rbenv/commit/c4d97ad3927c2670d293ac8910ff2bbcd05a06c7), which includes the following diff:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-852am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

And the description for this PR is:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-853am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

So the goal of this PR was specifically to refactor the logic around the `-` argument to `rbenv shell`.  And now it's dawning on me why the core team picked "-" as the argument to trigger this logic- because this logic is all about decrementing the shell's Ruby version to the previously-set version.

The one remaining question I have is, when it comes to the value of RBENV_VERSION_OLD, why can't we treat the empty string and a null value as being the same thing?  Either way, it seems like the old Ruby version is unset.  Like, if I were to have written this code, I would have thought it'd be:

```
  if [ -n "\$RBENV_VERSION_OLD" ]; then
    RBENV_VERSION_OLD_="\$RBENV_VERSION"
    export RBENV_VERSION="\$RBENV_VERSION_OLD"
    RBENV_VERSION_OLD="\$RBENV_VERSION_OLD_"
    unset RBENV_VERSION_OLD_
  else
    echo "rbenv: RBENV_VERSION_OLD is not set" >&2
    false
  fi
```

This is less surprising to me than checking both that the variable is set and SEPARATELY that it's a greater-than-zero length.  The only thing I can think of is that the core team thought there was a valid case for someone setting `RBENV_VERSION_OLD` to the empty string, and they wanted to handle that separately from the value not being set at all.  The only way this could happen is if they pass `RBENV_VERSION_OLD` into their `rbenv shell` command, i.e.:

```
RBENV_VERSION_OLD=3.0.0 rbenv shell -
```

This worked for me:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-857am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</p>

Side note- I don't love that the argument to roll back to the previous version of Ruby is "-".  This could be interpreted either as a minus sign or as a hyphen- indeed, I interpreted it as a hyphen until just now, and thought it was meant to be similar to the "--" syntax that we sometimes see in command line args.  I think a worthy PR would be to alias the "-" argument to "decrement", i.e. "rbenv shell decrement" or something.  Pseudo-code would be something like:

```
if [ "$version" = "-" ] or [ "$version" = "decrement" ]; then
```

If nothing else, this would make the intention of the code clearer.  And it would be backwards-compatible, since it's a strictly additive change.  I know the above code won't compile, but you get the idea.

On the other hand, the maintainers may not want multiple arguments which do the same thing.  The whole idea of "pick the one right tool for the job" appeals to me, and might appeal to them as well.  And if the only goal here is readability, a simple comment would accomplish the same thing with less risk.

Just some thoughts.

Last block of code for this file:

```
# Make sure the specified version is installed.
if rbenv-prefix "$version" >/dev/null; then
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
else
  echo "false"
  exit 1
fi
```

We run `rbenv prefix` on the version param passed to `rbenv shell`.  For example, if we type `rbenv shell 2.7.5`, then we run `rbenv prefix 2.7.5`.  On my machine, that returns the filepath to the directory for version 2.7.5 (`/Users/myusername/.rbenv/versions/2.7.5`).  If I pass `rbenv prefix` and invalid version, I get an error:

```
$ rbenv prefix foo

rbenv: version `foo' not installed
```

So if the version number we passed as an arg corresponds to a version that we have installed in our system, we do one thing.  Otherwise, we do another.

What are those two things?  Well, if we pass an *invalid* version, we `echo "false"` and exit with a non-zero status code.  If we pass a *valid* version, there's another `if` check we perform.  Specifically, we check whether the version number passed as a param is different from our current Ruby version.  We do nothing if the two version numbers are the same (hence, no `else` condition for this `if` check).  But if they're different, we set `RBENV_VERSION_OLD` equal to the current version of Ruby, or null if there is no current version.  We then set the Ruby version equal to the version that the user requested, and export `RBENV_VERSION` so that it may be used elsewhere.

Next file.
