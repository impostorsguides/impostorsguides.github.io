Starting with the test file as usual.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version.bats){:target="_blank" rel="noopener"}

For our first block of code, first we have:

```
create_version() {
  mkdir -p "${RBENV_ROOT}/versions/$1"
}
```

This is a helper function to create a version sub-directory inside the `RBENV_ROOT/versions` directory.  The `-p` flag makes any parent directories which don't already exist.

Next code block:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

Another helper function, this time to make and `cd` into the expected test directory.

Next block of code (and first test):

```
@test "no version selected" {
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-version
  assert_success "system"
}
```

As a sanity check, we first assert that the `$RBENV_ROOT/versions` directory doesn't exist.  Then we run the command, and assert that (since no RBENV Ruby versions are installed) that the command falls back to printing "system" to signify that the Ruby installation being used is the default one from the user's machine.

Next test:

```
@test "set by RBENV_VERSION" {
  create_version "1.9.3"
  RBENV_VERSION=1.9.3 run rbenv-version
  assert_success "1.9.3 (set by RBENV_VERSION environment variable)"
}
```

This test creates a Ruby version in RBENV's directory.  We then run the command with the `RBENV_VERSION` env var set to this version number, and then assert that the correct version number is output and the env var is specified as the source of the version info.

Next test:

```
@test "set by local file" {
  create_version "1.9.3"
  cat > ".ruby-version" <<<"1.9.3"
  run rbenv-version
  assert_success "1.9.3 (set by ${PWD}/.ruby-version)"
}
```

Here we not only create a Ruby version directory, but we also add a `.ruby-version` file and set its contents to be the stringified Ruby version whose folder we just created.  We then run the command, and assert that it succeeded and that the printed output includes the correct Ruby version and the correct source (the `.ruby-version` file we just created).

The line:

```
cat > ".ruby-version" <<<"1.9.3"
```

...says: "Read from STDIN and print what you receive to the file `.ruby-version`.  Oh, and also send the string "1.9.3" to STDIN."  The line `<<<"1.9.3"` is called a herestring, and is [a way of giving text to a program](https://web.archive.org/web/20220605071257/https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash){:target="_blank" rel="noopener"}.

Final test:

```
@test "set by global file" {
  create_version "1.9.3"
  cat > "${RBENV_ROOT}/version" <<<"1.9.3"
  run rbenv-version
  assert_success "1.9.3 (set by ${RBENV_ROOT}/version)"
}
```

This test creates a Ruby version directory *and* a separate file named `version` inside the root directory.  Note that we do *not* create a `.ruby-version` file.  We then run the command, and assert that it was successful.  We also assert that the printed output contains the correct version number *and* the correct source (the global `version` file).

That's it for the test file.  One thing I noticed is that the last two tests might not be covering all of our bases here.  All they do is assert that we can pull the Ruby version from a local project file named `.ruby-version`, *or* that we can pull it from the global `version` file.  If both those things exist, we don't currently have test coverage documenting what should happen (i.e. that the local file should be used over the global file).

I create this test and run it to see if it passes:

```
@test "prefer local over global file" {
  create_version "1.9.3"
  create_version "3.0.0"
  cat > ".ruby-version" <<<"1.9.3"
  cat > "${RBENV_ROOT}/version" <<<"3.0.0"
  run rbenv-version
  assert_success "1.9.3 (set by ${PWD}/.ruby-version)"
}
```

It does indeed pass!  I create [a PR to add this test](https://github.com/rbenv/rbenv/pull/1456){:target="_blank" rel="noopener"}, and am waiting for a response.

That's it for the test file.  Onto the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version){:target="_blank" rel="noopener"}

First block of code:

```
#!/usr/bin/env bash
# Summary: Show the current Ruby version and its origin
#
# Shows the currently selected Ruby version and how it was
# selected. To obtain only the version string, use `rbenv
# version-name'.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

You know the drill:

The `bash` shebang
The "Summary" and "Help" comments
`set -e` to exit after the first error
Setting verbose mode when `RBENV_DEBUG` is passed.

Next block of code:

```
version_name="$(rbenv-version-name)"
version_origin="$(rbenv-version-origin)"
```

Here we run the `rbenv version-name` and `rbenv version-origin` commands (to be described later).  We then store their output in properly-named variables.

Next / last block of code:

```
if [ "$version_origin" = "${RBENV_ROOT}/version" ] && [ ! -e "$version_origin" ]; then
  echo "$version_name"
else
  echo "$version_name (set by $version_origin)"
fi
```

Here we check whether a) the value of `version_origin` that was returned by the `rbenv version-origin` command is equal to the global `version` file, and whether that file *does not* yet exist.  If both these things are true, we simply print the version number.  If either is false, we print the version number *plus* its origin.

That's it.  That's the file!

Next file.
