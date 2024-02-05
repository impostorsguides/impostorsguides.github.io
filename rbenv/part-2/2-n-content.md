We're bypassing `rbenv-init` because we already covered that earlier, and skipping ahead to `rbenv-local`.  As per usual, let's look at the test file first.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/local.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and call to `test_loader`, the first block of code is:

```
setup() {
  mkdir -p "${RBENV_TEST_DIR}/myproject"
  cd "${RBENV_TEST_DIR}/myproject"
}
```

Pretty straightforward, just makes a directory for a fake test project and `cd`s into it.  We can assume that we'll need this fake project directory in order to set its Ruby version.

This `setup()` function is called by the `bats` testing framework, inside the `bats_test_begin()` function of the `bats-exec-test` file.

### Getting the version

The next few tests relate to fetching an existing version.  Later tests will relate to setting a new version number.

#### When no version exists

Our first test for this command:

```
@test "no version" {
  assert [ ! -e "${PWD}/.ruby-version" ]
  run rbenv-local
  assert_failure "rbenv: no local version configured for this directory"
}
```

I don't remember if I've seen the `-e` flag in a `[ ... ]` call before, so I look it up:

```
-e file       True if file exists (regardless of type).
```

So as a sanity check, this test first asserts that a file named `.ruby-version` does *not* currently exist in the current directory.  It then runs the `rbenv local` command, and asserts that the command fails with a non-zero exit status and a helpful error message.

#### When a local version exists in the current dir

Next test:

```
@test "local version" {
  echo "1.2.3" > .ruby-version
  run rbenv-local
  assert_success "1.2.3"
}
```

Here we create a `.ruby-version` file and set its contents equal to `1.2.3`.  We then run the `rbenv local` command without any arguments and assert that:

- the command exited successfully, and
- its printed output was the contents of the file we just created.

#### When a local version exists in the parent dir

Next test:

```
@test "discovers version file in parent directory" {
  echo "1.2.3" > .ruby-version
  mkdir -p "subdir" && cd "subdir"
  run rbenv-local
  assert_success "1.2.3"
}
```

Here we create that same `.ruby-version` file in one directory, then we make (and navigate to) a subdirectory.  We run the `rbenv local` command and assert that, even though no `.ruby-version` file is found in this sub-directory, the command is smart enough to recursively check parent directories until it finds such a file.

#### Preferring the `.ruby-version` file over the `RBENV_DIR` env var

Next test:

```
@test "ignores RBENV_DIR" {
  echo "1.2.3" > .ruby-version
  mkdir -p "$HOME"
  echo "2.0-home" > "${HOME}/.ruby-version"
  RBENV_DIR="$HOME" run rbenv-local
  assert_success "1.2.3"
}
```
Here we see that two `.ruby-version` files are created- the 1st one in the current directory, and the 2nd one in a special `$HOME` directory.  We then set the `RBENV_DIR` env var equal to the parent directory of that 2nd `.ruby-version` file and run the `rbenv local` command.  We expect that command to *ignore* this environment variable, and instead use the current directory's Ruby version file.

### Setting the local Ruby version

The next few tests relate to *setting* (not *getting*) the local Ruby version.

#### Setting a previously-installed version

First setter test:

```
@test "sets local version" {
  mkdir -p "${RBENV_ROOT}/versions/1.2.3"
  run rbenv-local 1.2.3
  assert_success ""
  assert [ "$(cat .ruby-version)" = "1.2.3" ]
}
```

Here we create a directory representing the location where RBENV installs its Ruby versions, and create a sub-directory called `1.2.3/`.  This is our way of mocking out a real RBENV installation of Ruby v1.2.3.

We then run `rbenv local` *with* an argument which corresponds to the version of Ruby that we just "installed".  We then assert that the test was successful and that the contents of the (newly-created) `.ruby-version` file are the same as the argument we provided to `rbenv local`.

The reason we had to create that fake directory in step 1 is because we don't actually want RBENV to make a network call, pull down a real Ruby install, and set it up on our machine.  That would make the test take forever and could even result in a flaky test if (for example) the network was down.

#### Updating an existing `.ruby-version` file to a new version number

Next test:

```
@test "changes local version" {
  echo "1.0-pre" > .ruby-version
  mkdir -p "${RBENV_ROOT}/versions/1.2.3"
  run rbenv-local
  assert_success "1.0-pre"
  run rbenv-local 1.2.3
  assert_success ""
  assert [ "$(cat .ruby-version)" = "1.2.3" ]
}
```

Here we create a `.ruby-version` file with one version of Ruby (`1.0-pre`), and create a fake "installed" version with a different version number (`1.2.3`).  As a sanity check, we run `rbenv local` once to confirm that it outputs the first version number.

We then run `rbenv local` a 2nd time, and this time we pass it the 2nd version number.  We then assert that the command exited successfully and that our the contents of our `.ruby-version` file changed from the 1st Ruby version to the 2nd one.

#### Unsetting the Ruby version

Last test:

```
@test "unsets local version" {
  touch .ruby-version
  run rbenv-local --unset
  assert_success ""
  assert [ ! -e .ruby-version ]
}
```

Here we create an empty `.ruby-version` file.  The file doesn't need any contents because, in step 2, we run `rbenv local –unset`.  This should have the effect of deleting that version file.  We then assert that the command exited successfully and that the version file no longer exists.

A pretty straightforward series of specs.  Now on to the command itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-local){:target="_blank" rel="noopener"}

The first block of code is:

```
#!/usr/bin/env bash
#
# Summary: Set or show the local application-specific Ruby version
#
# Usage: rbenv local <version>
#        rbenv local --unset
#
# Sets the local application-specific Ruby version by writing the
# version name to a file named `.ruby-version'.
#
# When you run a Ruby command, rbenv will look for a `.ruby-version'
# file in the current directory and each parent directory. If no such
# file is found in the tree, rbenv will use the global Ruby version
# specified with `rbenv global'. A version specified with the
# `RBENV_VERSION' environment variable takes precedence over local
# and global versions.
#
# <version> should be a string matching a Ruby version known to rbenv.
# The special version string `system' will use your default system Ruby.
# Run `rbenv versions' for a list of available Ruby versions.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

Same deal as always:

 - The Bash shebang
 - The usage + summary comments
 - The call to `set -e`, which tells the shell to exit immediately upon the first error it encounters
 - When the `RBENV_DEBUG` env var is present, call `set -x` to tell the shell to run in verbose mode.

### Completions

Next block of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --unset
  echo system
  exec rbenv-versions --bare
fi
```

These are the completions that get picked up and printed out when the user runs `rbenv local –complete`.  We echo `--unset` and `system`, and then print the output of `exec rbenv-versions –bare`.  In my case, that output is:

```
2.7.5
3.0.0
3.1.0
```

That's because these are the 3 versions of Ruby that I've installed via `rbenv`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Last block of code:

```
RBENV_VERSION="$1"

if [ "$RBENV_VERSION" = "--unset" ]; then
  rm -f .ruby-version
elif [ -n "$RBENV_VERSION" ]; then
  rbenv-version-file-write .ruby-version "$RBENV_VERSION"
else
  if version_file="$(rbenv-version-file "$PWD")"; then
    rbenv-version-file-read "$version_file"
  else
    echo "rbenv: no local version configured for this directory" >&2
    exit 1
  fi
fi
```

Let's break this up into smaller chunks.

### Setting a new Ruby version

```
RBENV_VERSION="$1"

if [ "$RBENV_VERSION" = "--unset" ]; then
  rm -f .ruby-version
```

We create a variable named `RBENV_VERSION` and set it equal to the first argument passed to `rbenv local`.  If that argument was `--unset`, then we delete the file named `.ruby-version` if it exists.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
elif [ -n "$RBENV_VERSION" ]; then
  rbenv-version-file-write .ruby-version "$RBENV_VERSION"
```

Otherwise, if the argument was any other value, then we pass that value to the program `rbenv-version-file-write`.  Based on a quick experiment, that program appears to check whether the argument it receives is equal to a version number for an installed version of Ruby.  If it's not, an error is returned:

```
$ rbenv local foobarbaz

rbenv: version `foobarbaz' not installed
```

### Reading the existing Ruby version

```
else
  if version_file="$(rbenv-version-file "$PWD")"; then
    rbenv-version-file-read "$version_file"
```

If we reach the `else` block, that means there was no first argument, i.e. the user just typed `rbenv local`.  In this case, the expectation is that the user wants to know what version of Ruby has been set by RBENV for the current directory or project.

In this case, we check whether we have a file containing a Ruby version number, using the `rbenv-version-file` command.  I try this command out in a directory without a `.ruby-version` file, and I see the following:

```
$ rbenv version-file

/Users/myusername/.rbenv/version
```

I then make a `.ruby-version` file in that same directory, and re-run it:

```
$ echo "2.0.0" > .ruby-version
$ rbenv version-file

/Users/myusername/.rbenv/.ruby-version
```

If we do have a version file somewhere, we run `rbenv version-file-read` and pass the name of that version file as an argument.  Again trying this command out on my machine, I see:

```
$ rbenv version-file-read .ruby-version

2.0.0
```

Last block of code:

```
  else
    echo "rbenv: no local version configured for this directory" >&2
    exit 1
  fi
fi
```

If we reach this block, we're trying to read a Ruby version but RBENV doesn't have a source from which to read a Ruby version.  So it prints out a helpful error message to `stderr` and exits with a non-zero return status.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for this command.  On to the next one.
