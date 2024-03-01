The job of the `rbenv global` command, according to the summary comments in the command file itself, is to:

> Set or show the global Ruby version

You're still free to set different versions inside a local Ruby project directory, but if you don't, RBENV will fall back to this global version number.

As usual, we'll read the tests first, then the code.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/global.bats){:target="_blank" rel="noopener" }

### Default Behavior

After the `bats` shebang and the loading of `test_helper`, the first test is:

```
@test "default" {
  run rbenv global
  assert_success
  assert_output "system"
}
```

This is the happy path test.

 - We run the `global` command.
 - We assert that the exit code was 0.
 - We assert that `system` is the default output when no prior Ruby version was set by RBENV (i.e. if no version files are located in `RBENV_ROOT/version/`).

### When a `/version` file exists

Next test:

```
@test "read RBENV_ROOT/version" {
  mkdir -p "$RBENV_ROOT"
  echo "1.2.3" > "$RBENV_ROOT/version"
  run rbenv-global
  assert_success
  assert_output "1.2.3"
}
```

In this test, we:

 - Make an `RBENV_ROOT` directory, and add a file named `version` inside it containing the version `1.2.3`.
 - We run the `rbenv global` command.
 - We assert that the command was successful.
 - We assert that the command printed `1.2.3` to the screen.

This spec ensures that, when there *is* a version file located in `RBENV_ROOT/version`, that the `rbenv global` command gets its output from that file.

Note the singular `/version` filename here.  The contents of the file dictate what RBENV uses for the current Ruby version when running Ruby commands.

### Setting the global Ruby version

Next test:

```
@test "set RBENV_ROOT/version" {
  mkdir -p "$RBENV_ROOT/versions/1.2.3"
  run rbenv-global "1.2.3"
  assert_success
  run rbenv global
  assert_success "1.2.3"
}
```

This case tests what happens when we set the global Ruby version to a version that RBENV knows about.

 - We create a subdirectory of "1.2.3" inside the *plural* `/versions` directory (this is different from the singular `version` file).
 - We then run `rbenv global`, but this time we pass it an argument of `1.2.3` to *set* the global Ruby version (as opposed to the previous test, where we just called `rbenv global` by itself to *get* the current global version).
 - We then run the getter command (`rbenv global`).
 - Lastly, we assert that:
    - the exit code was 0, and
    - "1.2.3" was printed to `stdout`.

This test ensures that running the setter command first didn't subsequently break the getter command.

However, I noticed that this test doesn't perform any sort of baseline tests before running the setter command.  Therefore, it doesn't actually ensure that the setter command was **responsible** for the current Ruby version being correct.  What if `1.2.3` was **already** the version?  In that event, this test would be giving us false confidence that our commands work as expected.

We could fix this by first running a baseline `rbenv global` getter command, and asserting that the response was `system` or whatever we expect the initial version to be.  I'd argue that this is a worthy addition via a PR, but I'll leave this as an exercise for the reader.

### Sad path- setting the Ruby version to an invalid value

The final test in this spec file is:

```
@test "fail setting invalid RBENV_ROOT/version" {
  mkdir -p "$RBENV_ROOT"
  run rbenv-global "1.2.3"
  assert_failure "rbenv: version \`1.2.3' not installed"
}
```

In this test, we run the same `rbenv global "1.2.3"` command as the previous test, but notice that we don't do any of the `mkdir` setup beforehand.  We just assert that the command fails with a specific error message.

The purpose of that setup was to mock out the installation of Ruby v1.2.3 on our system.  If we haven't installed v1.2.3 of Ruby using RBENV, then there will be no "1.2.3" sub-directory inside `/versions`.  Therefore, running `rbenv global 1.2.3` should result in a non-zero exit code.

Having read through the command's test file, let's move on to the file for the command itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-global){:target="_blank" rel="noopener" }

First few lines of code are familiar to us by this point:

```
#!/usr/bin/env bash
#
# Summary: Set or show the global Ruby version
#
# Usage: rbenv global <version>
#
# Sets the global Ruby version. You can override the global version at
# any time by setting a directory-specific version with `rbenv local'
# or by setting the `RBENV_VERSION' environment variable.
#
# <version> should be a string matching a Ruby version known to rbenv.
# The special version string `system' will use your default system Ruby.
# Run `rbenv versions' for a list of available Ruby versions.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

 - The Bash shebang.
 - Usage comments
 - An instruction to exit Bash if an error is raised
 - Setting verbose / `xtrace` mode if `R`BENV_DEBUG is set

### Completions

Next few lines of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo system
  exec rbenv-versions --bare
fi
```

These are the possible code completions for the "global' command, which are printed if the user types `rbenv global --complete`.  We always output "system" as the first output.  We follow that with the output of `rbenv versions --bare`, which prints the non-system Ruby versions that the user has installed.

### Setting variables

Next few lines of code:

```
RBENV_VERSION="$1"
RBENV_VERSION_FILE="${RBENV_ROOT}/version"
```

Here we set a variable named `RBENV_VERSION` equal to the first argument from the command line (i.e. the "1.2.3" in `rbenv global 1.2.3`), and we set a variable named `RBENV_VERSION_FILE` equal to the "/version" subfolder of (in my case) "/Users/myusername/.rbenv".

Nowhere in this file do we `export` these variables, therefore we can't claim that they're environment variables (even though they're capitalized as if they're env vars).

### Writing a new value for the global Ruby version

Next few lines of code:

```
if [ -n "$RBENV_VERSION" ]; then
  rbenv-version-file-write "$RBENV_VERSION_FILE" "$RBENV_VERSION"
```

If the user provided a number that they wanted to set their global Ruby version to, then we call the `rbenv-version-file-write` command, passing it the name of the version file and the version number.  Later on, we'll see exactly how the `rbenv-version-file-write` command works.

### Reading the current global Ruby value

Last block of code:

```
else
  rbenv-version-file-read "$RBENV_VERSION_FILE" || echo system
fi
```

If the user didn't specify a version number that they want to set their global Ruby version to, this implicitly means they want to do read the current version number instead of updating it to a new one.  So we call `rbenv-version-file-read` instead of `rbenv-version-file-write`, passing it the `RBENV_VERSION_FILE` variable.

If that "read" operation fails, that implies there is no global Ruby version installed by RBENV, so we simply echo the string "system".

That's it for this file.  On to the next one.
