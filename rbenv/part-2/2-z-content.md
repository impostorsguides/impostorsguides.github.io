First, the tests:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-origin.bats)

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

This `setup` helper function just makes and navigates into the temporary test directory that we use to create our test data, directories, etc.  Having a dedicated directory in which to run our spec ensures that we can do whatever setup our test requires (ex. do things like create fake Ruby version files) and subsequently blow away those setup steps without damaging actual ruby version files, directories, etc. that live on our machines and which we depend on to do real work.

Next block of code (and first test):


```
@test "reports global file even if it doesn't exist" {
  assert [ ! -e "${RBENV_ROOT}/version" ]
  run rbenv-version-origin
  assert_success "${RBENV_ROOT}/version"
}
```

First, this test performs a sanity check to ensure that RBENV's global “version” file does not exist.  It then runs the `version-origin` command and asserts that this non-existent global “version” file's path is returned anyway.

Note- I'm not sure why we'd want a non-existent filepath to be returned by the `version-origin` command.  To me this is a bit misleading, as a novice user of this command could spend time banging their head against the wall trying to find a file that doesn't exist on their machine.  It's good that this test documents this behavior, but it's unexpected (to me, at least) that the behavior was implemented in this way.  I checked [the commit](https://github.com/rbenv/rbenv/commit/ab197ef51e5d99110015907c4346fde7c5a61de4) which introduced this test, but no answer to this question was provided in the description.  When it comes time to read through the command file itself, I'll check the `git blame` for this logic to see if that PR has a relevant description.

Next test:

```
@test "detects global file" {
  mkdir -p "$RBENV_ROOT"
  touch "${RBENV_ROOT}/version"
  run rbenv-version-origin
  assert_success "${RBENV_ROOT}/version"
}
```

This test creates the global “version” file in its expected location, then runs the `version-origin` command and asserts that it completed successfully, with the global version file as its output.

Next test:

```
@test "detects RBENV_VERSION" {
  RBENV_VERSION=1 run rbenv-version-origin
  assert_success "RBENV_VERSION environment variable"
}
```

This test asserts that, when we pass the `RBENV_VERSION` env var to the `version-origin` command, the command runs successfully and prints the string "RBENV_VERSION environment variable" to STDOUT.

Next test:

```
@test "detects local file" {
  echo "system" > .ruby-version
  run rbenv-version-origin
  assert_success "${PWD}/.ruby-version"
}
```

This test creates a local Ruby version file, and specifies that the `version-origin` command runs successfully with that local version file path as its output.

Next test:

```
@test "reports from hook" {
  create_hook version-origin test.bash <<<"RBENV_VERSION_ORIGIN=plugin"

  RBENV_VERSION=1 run rbenv-version-origin
  assert_success "plugin"
}
```

This test creates a hook for the `version-origin` command named `test.bash`, which contains code to overwrite the value of the `RBENV_VERSION_ORIGIN` env var to the string “plugin”.  We then run the `version-origin` command with a *different* value of `RBENV_VERSION`, and assert that the command used the value from the hook, *not* the value from the passed-in env var.

Next test:

```
@test "carries original IFS within hooks" {
  create_hook version-origin hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
SH

  export RBENV_VERSION=system
  IFS=$' \t\n' run rbenv-version-origin env
  assert_success
  assert_line "HELLO=:hello:ugly:world:again"
}
```

This test is similar to one we saw in the previous file's test suite.  We create a hook which depends on the `IFS` (i.e. internal field separator) env var being set to contain certain characters.  These characters are the tab, whitespace, and newline characters.  We create a hook which first creates an array of strings containing these characters, and then prints a 2nd string which uses these characters as delimiters to split that single string into an array of strings.  Next we set `RBENV_VERSION` to equal the string “system” and we run the `version-origin` command, making sure to set `IFS` to contain the same characters as those we use as delimiters in our hook (tab, space, and newline).  Finally, we assert that the command exited successfully and that the IFS characters that we set were, in fact, used to delimit the single string into an array of strings.

Note- it looks like we're passing an argument (i.e. the string “env”) to `version-origin` in this test.  I'm not sure what that is.  The argument doesn't appear to be used anywhere, nor does “$1” appear anywhere in the command itself.  I took a look at [the PR](https://github.com/rbenv/rbenv/pull/852/files) which introduced this line of code, and it looks like it might have been a copy-paste error, since the previous implementation of the test did not include an argument to the invocation of the command.  I make a commit on my local `rbenv` repo to remove this argument, but I don't want to make a PR just for this one minor fix because I don't think it's high-value enough by itself to be worth the core team's time.  I'll include it with other changes in a future PR, or make a PR for it by itself if I can't find other PR-worthy changes to make.

Last test:

```
@test "doesn't inherit RBENV_VERSION_ORIGIN from environment" {
  RBENV_VERSION_ORIGIN=ignored run rbenv-version-origin
  assert_success "${RBENV_ROOT}/version"
}
```

This test just asserts that the `version-origin` command ignores any value of `RBENV_VERSION_ORIGIN` that's passed in via an environment variable from the caller.

That's it for specs, now onto the code:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-origin)

Let's get the usual suspects out of the way first:

```
#!/usr/bin/env bash
# Summary: Explain how the current Ruby version is set
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

 - `bash` shebang
 - “Summary” docs
 - `set -e` to exit the script immediately when it encounters an error
 - `set -x` to print output in verbose mode when the `RBENV_DEBUG` env var is set

Next block of code:

```
unset RBENV_VERSION_ORIGIN
```

Here we explicitly unset any previously-set values for `RBENV_VERSION_ORIGIN`, such as those passed into the command by the caller.

Next block of code:

```
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks version-origin`)
IFS="$OLDIFS"
for script in "${scripts[@]}"; do
  source "$script"
done
```

We've seen this code before.  Taken together, it just pulls the filepaths for any hooks for the `version-origin` command that the user has installed.  It then runs `source` on each of those filepaths, to ensure that the hook code is executed.

The final block of code for this command:

```
if [ -n "$RBENV_VERSION_ORIGIN" ]; then
  echo "$RBENV_VERSION_ORIGIN"
elif [ -n "$RBENV_VERSION" ]; then
  echo "RBENV_VERSION environment variable"
else
  rbenv-version-file
fi
```

At this point, the only place where we could be getting our `RBENV_VERSION_ORIGIN` value from is a hook that was just `source`'ed.  If that's indeed what happened, we echo that value to STDOUT.  Otherwise, if we have a non-empty value for `RBENV_VERSION` (either from the caller of `version-origin` or from a hook file), we print the string "RBENV_VERSION environment variable" to STDOUT.  Otherwise, we print the output of the `version-file` command that we examined earlier.

And that's a wrap for this command!  On to the next command.
