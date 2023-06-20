There are no "Usage" comments at the top of the file, but there are some "Summary" comments.  So we'll start there.

## "Summary" comments

```
# Summary: Show the current Ruby version and its origin
#
# Shows the currently selected Ruby version and how it was
# selected. To obtain only the version string, use `rbenv
# version-name'.
```

According to the comments, the expected output of the command is a version number plus an "origin".

I try the command in my terminal, and get the following:

```
bash-3.2$ rbenv version

2.7.5 (set by /Users/myusername/.rbenv/version)
```

`2.7.5` is my Ruby version number, and `/Users/myusername/.rbenv/version` is the origin.

Now let's move on to the test file.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version.bats){:target="_blank" rel="noopener"}

### "Installing" a test Ruby version

Our first block of code is:

```
create_version() {
  mkdir -p "${RBENV_ROOT}/versions/$1"
}
```

This is a helper function to "install" a fake Ruby version inside RBENV's `versions/` directory.  If RBENV sees a sub-directory inside `versions/`, it will assume it represents a specific version of Ruby that the user has installed.

The above function simply creates a sub-directory inside the `RBENV_ROOT/versions` directory, whose name corresponds to the function's first argument.  The `-p` flag makes any parent directories which don't already exist.

### The `setup` callback

Next code block:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

Another helper function, this time to create and navigte into the expected test directory.

### When no RBENV Rubies are installed

Next block of code (and first test):

```
@test "no version selected" {
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-version
  assert_success "system"
}
```

As a sanity check, we first assert that the `$RBENV_ROOT/versions` directory doesn't exist.  Then we run the command, and assert that the command falls back to printing `system`, signifying that the Ruby installation being used is the default one from the user's machine.

### When the origin is the `RBENV_VERSION` environment variable

Next test:

```
@test "set by RBENV_VERSION" {
  create_version "1.9.3"
  RBENV_VERSION=1.9.3 run rbenv-version
  assert_success "1.9.3 (set by RBENV_VERSION environment variable)"
}
```

This test creates a Ruby version in RBENV's directory.  It then runs the command with the `RBENV_VERSION` env var set to this version number, and asserts that:

 - the correct version number is output, and
 - `RBENV_VERSION` is the source of the version info.

### When the origin is a `.ruby-version` file

Next test:

```
@test "set by local file" {
  create_version "1.9.3"
  cat > ".ruby-version" <<<"1.9.3"
  run rbenv-version
  assert_success "1.9.3 (set by ${PWD}/.ruby-version)"
}
```

Here we not only create a Ruby version directory, but we also add a `.ruby-version` file and set its contents to be the stringified Ruby version whose folder we just created.  We then run the command, and assert that:

 - it succeeded, and that
 - the printed output includes the correct Ruby version and the correct source (the `.ruby-version` file we just created).

The line:

```
cat > ".ruby-version" <<<"1.9.3"
```

...says: "Read from STDIN and print what you receive to the file `.ruby-version`.  At the same time, send the string "1.9.3" to STDIN."  The line `<<<"1.9.3"` is called a herestring, and is [a way of sending text to `stdin`](https://web.archive.org/web/20220605071257/https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash){:target="_blank" rel="noopener"}.

### When the origin is RBENV's global Ruby file

Final test:

```
@test "set by global file" {
  create_version "1.9.3"
  cat > "${RBENV_ROOT}/version" <<<"1.9.3"
  run rbenv-version
  assert_success "1.9.3 (set by ${RBENV_ROOT}/version)"
}
```

This test creates a Ruby version directory *and* a separate file named `version` inside the root directory.  We then run the command, and assert that it was successful.  We also assert that the printed output contains the correct version number *and* the correct source (the global `version` file).

That's it for the test file.

### Adding a new test

One thing I noticed is that the last two tests might not be covering all of our bases here.  All they do is assert that we can pull the Ruby version from a local project file named `.ruby-version`, *or* that we can pull it from the global `version` file.  If both those things exist, we don't currently have test coverage documenting what should happen (i.e. that the local file should be used over the global file).

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

It does indeed pass, so I create [a PR to add this test](https://github.com/rbenv/rbenv/pull/1456){:target="_blank" rel="noopener"}, and a few days later the core team merges it.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version){:target="_blank" rel="noopener"}

Now on to the code itself.

First block of code:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

You know the drill:

`set -e` to exit after the first error
Setting verbose mode when `RBENV_DEBUG` is passed.

### Setting the version name and origin

Next block of code:

```
version_name="$(rbenv-version-name)"
version_origin="$(rbenv-version-origin)"
```

Here we run the `rbenv version-name` and `rbenv version-origin` commands, and store their output in properly-named variables.  We'll read through the code for these commands later.  For now, we can just run them in the terminal to see what their output is:

```
bash-3.2$ rbenv version-name

2.7.5

bash-3.2$ rbenv version-origin

/Users/myusername/.rbenv/version
```

Pretty unsurprising IMHO, given what we already know.

### Printing the version name (and possibly the origin)

Next / last block of code:

```
if [ "$version_origin" = "${RBENV_ROOT}/version" ] && [ ! -e "$version_origin" ]; then
  echo "$version_name"
else
  echo "$version_name (set by $version_origin)"
fi
```

Here we check whether:

 - the value of `version_origin` that was returned by the `rbenv version-origin` command is equal to the global `version` file, and
 - whether that file *does not* yet exist.

If both these things are true, we simply print the version number.  If either is false, we print the version number *plus* its origin.

It's a bit strange to me that we would check both that the origin is equal to `${RBENV_ROOT}/version` **and** that the `version_origin` file does not yet exist.  If the return value of the `rbenv-version-origin` command (which we stored in the `version_origin` variable) was `${RBENV_ROOT}/version`, shouldn't we be confident that the `${RBENV_ROOT}/version` file exists?

I guess we'll find out when we get to the `rbenv-version-origin` command.

At any rate, that's the end of this file.  On to the next one.
