First, the tests:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/whence.bats)

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_executable() {
  local bin="${RBENV_ROOT}/versions/${1}/bin"
  mkdir -p "$bin"
  touch "${bin}/$2"
  chmod +x "${bin}/$2"
}
```

We create a helper function named `create_executable`.  It creates a sub-directory of RBENV's “versions/” directory, with a name that corresponds to a Ruby version that we specify in the first argument to the helper function.  We then create an executable file within our new sub-directory, with a filename corresponding to the 2nd argument we send to the helper function.

The next block of code is our first (and only) test for this file:

```
@test "finds versions where present" {
  create_executable "1.8" "ruby"
  create_executable "1.8" "rake"
  create_executable "2.0" "ruby"
  create_executable "2.0" "rspec"

  run rbenv-whence ruby
  assert_success
  assert_output <<OUT
1.8
2.0
OUT

  run rbenv-whence rake
  assert_success "1.8"

  run rbenv-whence rspec
  assert_success "2.0"
}
```

We create 2 Ruby version directories, named “1.8” and “2.0”, and we create two files inside each of those directories (files named “ruby” and “rake” inside directory “1.8”, and files “ruby” and “spec” inside directory “2.0”).

We then run our `rbenv whence` command, passing the “ruby” argument.  We assert that it outputs both Ruby versions “1.8” and “2.0”, since “ruby” is installed inside each of those version directories.

We then run the command again, this time passing “rake” instead of “ruby”.  Since “rake” is only installed in version directory “1.8”, we assert the command succeeds and that only “1.8” is printed to the screen.

Lastly, we run the command a 3rd time with “rspec” as the argument, and assert that “2.0” is the only printed output (since “rspec” was only installed in directory “2.0”).

On to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-whence)

The first block of code is one we're familiar with already:

```
#!/usr/bin/env bash
# Summary: List all Ruby versions that contain the given executable
# Usage: rbenv whence [--path] <command>

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

The `bash` shebang
The “Summary” and “Usage” notes.  It looks like we provide a shim name to `rbenv whence`, and it prints back a list of Ruby versions in which that shim is installed.  This should look familiar, given the test we just read.
`set -e` to tell the shell to exit immediately upon its first exception
`set -x` to tell the shell to run in verbose mode, in this case only when `RBENV_DEBUG` is set.

Next block of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --path
  exec rbenv-shims --short
fi
```

This block checks whether the first argument is the string `--complete`.  If it is, the user is asking for a list of completions to the `rbenv whence` command.  In this case, we print the string “--path” and then print the list of shims that the user has installed, since each of those shim names is also a valid argument to pass to `rbenv whence`.

Next block of code:

```
if [ "$1" = "--path" ]; then
  print_paths="1"
  shift
else
  print_paths=""
fi
```

Here we see that we have the option of specifying a flag named `--path`.  If we do this, we set a variable named `print_paths` equal to “1” and shift it off of our argument stack.  Otherwise, we set it equal to the empty string.  We'll use `print_paths` later on in the code.

Next block of code:

```
whence() {
  local command="$1"
  rbenv-versions --bare | while read -r version; do
    path="$(rbenv-prefix "$version")/bin/${command}"
    if [ -x "$path" ]; then
      [ "$print_paths" ] && echo "$path" || echo "$version"
    fi
  done
}
```

Here we create a helper function named `whence`.  It looks like we take the first argument provided to this helper, and store it in a local variable named “command”, so it's probably the name of the command that we passed to `rbenv whence`.  We then run the `rbenv-versions --bare` command, which returns a list of Ruby versions, minus all the extraneous info (filepaths, asterisks next to the currently-selected version, etc.).  This list then gets piped to the `read -r` command, storing each line in a local variable named `version`.  For each line of code in `rbenv-versions` (i.e for each version of Ruby installed), we then construct a possible filepath to the command within the Ruby version's directory.  If that filepath corresponds to a file which is executable, we then either echo the path if the user passed the `--path` flag, or just the Ruby version itself.  When the `read` command is done reading lines of input from `rbenv-versions`, the `whence` helper function terminates.

Next block of code:

```
RBENV_COMMAND="$1"
if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage whence >&2
  exit 1
fi
​​```

Here we check whether there was an argument passed to `rbenv whence`.  If not, we echo the “Usage” comments for this command and exit with a non-zero return code.

Last block of code:

```
result="$(whence "$RBENV_COMMAND")"
[ -n "$result" ] && echo "$result"
```

Here we call our `whence` helper function, and store the results as an array of strings inside a variable named `result`.  If `result` is non-empty, we print its contents to the screen.

That's the end of this file!  Next one:

(stopping here for the day; 85130 words)
