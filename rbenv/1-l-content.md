The job of the `rbenv global` command, according to the summary comments in the command file itself, is to:

> Set or show the global Ruby version

You’re still free to set different versions inside a local Ruby project directory, but if you don’t, RBENV will fall back to this global version number.

Let’s check out the spec file first, this time.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/global.bats)

After the `bats` shebang and the loading of `test_helper`, the first test is:

```
@test "default" {
  run rbenv global
  assert_success
  assert_output "system"
}
```

This is the happy path test.  We run the `global` command, assert that the exit code was 0, and that `system` is the default output when no prior Ruby version was set by RBENV (i.e. if no version files are located in `RBENV_ROOT/version/`, as we’ll see in the next test).

Speaking of which:

```
@test "read RBENV_ROOT/version" {
  mkdir -p "$RBENV_ROOT"
  echo "1.2.3" > "$RBENV_ROOT/version"
  run rbenv-global
  assert_success
  assert_output "1.2.3"
}
```

This spec ensures that, when there *is* a version file located in `RBENV_ROOT/version`, that the `rbenv global` command gets its output from that file.

Note the singular `/version` folder name here.  The contents of the singular folder dictate what RBENV’s actual current version is.  In the next test case, we’ll see where RBENV keeps its *potential* versions, i.e. the ones that it has installed and could switch to, upon a user’s request.

Next test case:

```
@test "set RBENV_ROOT/version" {
  mkdir -p "$RBENV_ROOT/versions/1.2.3"
  run rbenv-global "1.2.3"
  assert_success
  run rbenv global
  assert_success "1.2.3"
}
```

This case tests what happens when “1.2.3” exists as one of the versions that RBENV has installed.  Here we see that part of the test setup is to create a subdirectory of “1.2.3” inside the *plural* `/versions` directory (*not* the singular `/version` directory).  We then run `rbenv global`, but this time we pass it an argument of `1.2.3` to *set* the global Ruby version (as opposed to the previous test, where we just called `rbenv global` by itself to *get* the current global version).  We finish up by running the getter command (`rbenv global`), asserting that a) the exit code was 0, and b) that “1.2.3” was printed to STDOUT.  This ensures that we didn’t break the command by running the setter command first.  However, one thing I *think* is true is that this test doesn’t actually ensure that the setter command was responsible for the current Ruby version being correct.  To do that, we’d first have to run an earlier `rbenv global` getter command and assert that the response was “system” or whatever we want the “before” version to be.  I’d argue that this is a worthy addition via a PR, but I’ll save this for another time.

The final test in this spec file is:

```
@test "fail setting invalid RBENV_ROOT/version" {
  mkdir -p "$RBENV_ROOT"
  run rbenv-global "1.2.3"
  assert_failure "rbenv: version \`1.2.3' not installed"
}
```

This is the test which covers the sad path of the “global” command.  If we haven’t installed v1.2.3 of Ruby using RBENV, then there will be no “1.2.3” subdirectory of `/versions`.  Therefore, running `rbenv global 1.2.3` should result in a non-zero exit code (which is verified by calling `assert_failure`, and the error message printed to STDOUT should indicate that the requested version is not yet installed.

Having read through the command’s test file, let’s move on to the file for the command itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-global)

First few lines of code are boilerplate at this point:

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

These are the standard shebang / usage comments / “exit upon first error” command / “verbose output if RBENV_DEBUG is set” command.

Next few lines of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo system
  exec rbenv-versions --bare
fi
```

These are the possible code completions for the “global’ command, which are printed if the user types `rbenv global --complete`.  We always output “system” as the first output, and we follow that with the output of `rbenv versions --bare`, which prints the non-system Ruby versions that the user has installed.

(stopping here for the day; 35691 words)

Next few lines of code:

```
RBENV_VERSION="$1"
RBENV_VERSION_FILE="${RBENV_ROOT}/version"
```

Here we set a variable named `RBENV_VERSION` equal to the first argument from the command line (i.e. the “1.2.3” in `rbenv global 1.2.3`), and we set a variable named `RBENV_VERSION_FILE` equal to the “/version” subfolder of (in my case) “/Users/myusername/.rbenv”.

Next few lines of code:

```
if [ -n "$RBENV_VERSION" ]; then
  rbenv-version-file-write "$RBENV_VERSION_FILE" "$RBENV_VERSION"
else
  rbenv-version-file-read "$RBENV_VERSION_FILE" || echo system
fi
```

If the user provided a number that they wanted to set their global Ruby version to, then we call the `rbenv-version-file-write` command, passing it the name of the version file and the version number.  The `rbenv-version-file-write` command is further down in the directory I’m examining, so I’ll get to it at some point in the future.

If the `if` conditional is false, that means the user didn’t specify a version number that they want to set their global Ruby version to, implying they want to do a “get” operation instead of a “set” operation.  So we call `rbenv-version-file-read` instead of `rbenv-version-file-write`, passing it the `RBENV_VERSION_FILE` variable.  If that “read” operation fails, that implies there is no global Ruby version installed by RBENV, so we simply echo the string “system”.

That’s it for this file.  On to the next one.
