First the test file.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-file-write.bats)

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

This is the implementation of our `setup` hook, which in this case makes a new directory and navigates into it.

Our first test is:

```
@test "invocation without 2 arguments prints usage" {
  run rbenv-version-file-write
  assert_failure "Usage: rbenv version-file-write <file> <version>"
  run rbenv-version-file-write "one" ""
  assert_failure
}
```

This is a sad-path test.  Judging from the description text, this command always expects two arguments.  Here we run the command with no setup and no arguments, and we assert that the command fails with an error message which tells the user to specify both a filename and a version number.  We then run the command again with two arguments, one of which is an empty string, and again assert that the command fails.

Next test:

```
@test "setting nonexistent version fails" {
  assert [ ! -e ".ruby-version" ]
  run rbenv-version-file-write ".ruby-version" "1.8.7"
  assert_failure "rbenv: version \`1.8.7' not installed"
  assert [ ! -e ".ruby-version" ]
}
```

As a setup step, we assert that the `.ruby-version` file does not exist.  We then run the `version-file-write` command, passing that same `.ruby-version` file as argument #1 and the stringified version number "1.8.7" as argument #2.  We then assert that the command fails with an error message saying the requested version number is not installed.  Lastly, we assert that the `.ruby-version` file has not been created since we last checked for its existence.

Last test:

```
@test "writes value to arbitrary file" {
  mkdir -p "${RBENV_ROOT}/versions/1.8.7"
  assert [ ! -e "my-version" ]
  run rbenv-version-file-write "${PWD}/my-version" "1.8.7"
  assert_success ""
  assert [ "$(cat my-version)" = "1.8.7" ]
}
```

As a setup step, we create a fake Ruby installation for Ruby v1.8.7, and we assert that a version file named `my-version` does not yet exist.  We then run the command with the `my-version` filename and version "1.8.7" as arguments.  This time we assert that the command was successful and that the contents of the newly-created version file is equal to "1.8.7".  This 2nd assertion implicitly tests that the new version file also, in fact, exists.

That's all for the tests, now on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-file-write)

Let's get the following out of the way:

```
#!/usr/bin/env bash
# Usage: rbenv version-file-write <file> <version>

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

 - `bash` shebang
 - "Usage" comments
 - `set -e` tells the shell to exit when it encounters an error for the first time.
 - `set -x` tells the shell to print verbose output, in this case when the `RBENV_DEBUG` env var has been set.

Next block of code:

```
RBENV_VERSION_FILE="$1"
RBENV_VERSION="$2"
```

Here we just store off the first two arguments (aka the version filename and the version number) in appropriately-named variables.

Next block of code:

```
if [ -z "$RBENV_VERSION" ] || [ -z "$RBENV_VERSION_FILE" ]; then
  rbenv-help --usage version-file-write >&2
  exit 1
fi
```

If either the two variables we just created are empty (i.e. if the user failed to provide two arguments to the `version-file-write` command), then we print the usage instructions for this file and exit with an error return code.

Next block of code:

```
# Make sure the specified version is installed.
rbenv-prefix "$RBENV_VERSION" >/dev/null
```

Here we validate that the Ruby version number that the user passed as argument #2 corresponds to a valid Ruby version that exists on the user's machine.  If not, we exit.

I was curious whether this last statement was actually true or not.  I checked the `rbenv-prefix` command and saw [this block of code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-prefix#L37) along with the `exit 1` statement on line 39, but I wasn't sure if the `rbenv-prefix` command executed by [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-file-write#L16) was running in a separate process or not, therefore I wasn't sure if that `exit 1` statement would cause just that process or the calling process which is running `rbenv-version-file-write` to be exited.

So I did an experiment.  My hypothesis is that, if there is only a single process running both `rbenv-version-file-write` and `rbenv-prefix`, then the `exit 1` command will cause `rbenv-version-file-write` to exit, so no further code after line 16 of `version-file-write` should be executed.  So I placed the following `echo` statement on line 17 of `rbenv-version-file-write`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-905am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I then ran `rbenv version file write foo bar`, knowing that `bar` is not a valid Ruby version and therefore `rbenv-prefix` should run its `exit 1` command.  Sure enough, I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-17mar23-906am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Sure enough, I see the expected error message from [this line of code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-prefix#L38), but not the output of the `echo` statement I added.

Note that I ran `ls -la` to verify that no version file named `foo` was created.

So unless I'm misunderstanding something, we can conclude that the `exit 1` inside `rbenv-prefix` caused the exit of `rbenv-version-file-write` as well, and that therefore these two commands are running in the same process.

Last block of code:

```
# Write the version out to disk.
echo "$RBENV_VERSION" > "$RBENV_VERSION_FILE"
```

Now that we've verified the Ruby version provided by the user is valid, we simply write that version to the file whose name the user also provided.

And that's it for `version-file-write`!  Next file.
