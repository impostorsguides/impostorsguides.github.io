First the test file.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-file-write.bats){:target="_blank" rel="noopener"}

### Setting up our working directory

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

This is the implementation of our `setup` hook, which in this case makes a new directory and navigates into it.

### Sad path- testing a response to incorrect usage

Our first test is:

```
@test "invocation without 2 arguments prints usage" {
  run rbenv-version-file-write
  assert_failure "Usage: rbenv version-file-write <file> <version>"
  run rbenv-version-file-write "one" ""
  assert_failure
}
```

This is a sad-path test.  According to the test's description, this command always expects two arguments.

We run the command with no setup and no arguments, and we assert that the command fails with an error message which tells the user to specify both a filename and a version number.  We then run the command again with two arguments, one of which is an empty string, and again assert that the command fails.

### Sad path- trying to set a version which isn't installed

Next test:

```
@test "setting nonexistent version fails" {
  assert [ ! -e ".ruby-version" ]
  run rbenv-version-file-write ".ruby-version" "1.8.7"
  assert_failure "rbenv: version \`1.8.7' not installed"
  assert [ ! -e ".ruby-version" ]
}
```

In this test:

- We first assert that the `.ruby-version` file does not exist, as a sanity check.
- We then run the `version-file-write` command, passing that same `.ruby-version` file as argument #1 and the stringified version number "1.8.7" as argument #2.
- We then assert that the command fails with an error message saying the requested version number is not installed.
- Lastly, we assert that the `.ruby-version` file has not been created since we last checked for its existence.

### Happy path- writing to a version file other than `.ruby-version`

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

In this test:

- As a setup step, we create a fake Ruby installation for Ruby v1.8.7, and we assert that a version file named `my-version` does not yet exist.
- We then run the command with the `my-version` filename and version "1.8.7" as arguments.
- This time we assert that the command was successful and that the contents of the newly-created version file is equal to "1.8.7".

This 2nd assertion implicitly tests that the new version file also, in fact, exists.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's all for the tests, now on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-file-write){:target="_blank" rel="noopener"}

First up:

```
#!/usr/bin/env bash
# Usage: rbenv version-file-write <file> <version>

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

As usual, we have:

 - Bash shebang
 - "Usage" comments
 - `set -e` to set "exit-on-error" mode.
 - `set -x` to set "verbose" mode.

### Setting variables for the version file and version

Next block of code:

```
RBENV_VERSION_FILE="$1"
RBENV_VERSION="$2"
```

Here we just store off the first two arguments (aka the version filename and the version number) in appropriately-named variables.

### Handling missing arguments

Next block of code:

```
if [ -z "$RBENV_VERSION" ] || [ -z "$RBENV_VERSION_FILE" ]; then
  rbenv-help --usage version-file-write >&2
  exit 1
fi
```

If the user failed to provide either the version filename or the version number itself, then we print the usage instructions for this file and exit with an error return code.

### Ensuring the version is installed

Next block of code:

```
# Make sure the specified version is installed.
rbenv-prefix "$RBENV_VERSION" >/dev/null
```

Here we validate that the Ruby version number that the user passed as argument #2 corresponds to a valid Ruby version that exists on the user's machine.

If not, an error will be raised, and we'll exit.  We can see this error being raised in the `rbenv-prefix` command, at [this block of code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-prefix#L37){:target="_blank" rel="noopener"}.

### Writing the version number to the version file

Last block of code:

```
# Write the version out to disk.
echo "$RBENV_VERSION" > "$RBENV_VERSION_FILE"
```

Now that we've verified the Ruby version provided by the user is valid, we simply write that version to the file whose name the user also provided.

And that's it for `version-file-write`!  Next file.
