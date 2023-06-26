First let's look at the "Summary" and "Usage" comments.

## ["Summary" and "Usage" comments](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-whence#L2-L3){:target="_blank" rel="noopener"}

```
# Summary: List all Ruby versions that contain the given executable

# Usage: rbenv whence [--path] <command>
```

The `whence` command "lists all Ruby versions that contain the given executable", where the executable is specified by `<command>` above.  So for example, I have Ruby version `2.7.5` and `3.0.0` installed via RBENV, but only `2.7.5` contains the `rails` executable:

```
$ rbenv whence rails

2.7.5
```

According to the comments, passing the `--path` argument is an option as well:

```
$ rbenv whence --path rails

/Users/myusername/.rbenv/versions/2.7.5/bin/rails
```

The result is the full path to the executable, rather than just its name.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next, the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/whence.bats){:target="_blank" rel="noopener"}

### Creating a mocked executable

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_executable() {
  local bin="${RBENV_ROOT}/versions/${1}/bin"
  mkdir -p "$bin"
  touch "${bin}/$2"
  chmod +x "${bin}/$2"
}
```

 - We create a helper function named `create_executable`.
 - It creates a sub-directory of RBENV's `versions/` directory, whose job is to contain all the executable files for a specific version of Ruby that we specify via argument #1 of the function.
    - This will also have the effect of mocking out the installation of that version of Ruby, since RBENV considers a version to be "installed" if a directory whose name corresponds to that version exists in `versions/`.
    - For example, RBENV considers Ruby version `2.7.5` to be installed if a directory named `${RBENV_ROOT}/versions/2.7.5` exists.
 - We then create an executable file within our new sub-directory, with a filename corresponding to argument #2 of the function.

### Returning a subset of versions which contain the given executable

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

 - We create a Ruby version named `1.8` containing executables named `ruby` and `rake`.
 - We create a Ruby version named `2.0` containing executables named `ruby` and `rspec`.
 - We run our `rbenv whence` command, passing the name of the `ruby` executable that we created.
 - We assert that it outputs both Ruby versions `1.8` and `2.0`, since `ruby` is installed inside each of those version directories.
 - We then run the command again, this time passing `rake` instead of `ruby`.  Since `rake` is only installed in version directory `1.8`, we assert the command succeeds and that only `1.8` is printed to the screen.
 - Lastly, we run the command a 3rd time with "rspec" as the argument, and assert that `2.0` is the only printed output (since `rspec` was only installed in directory `2.0`).

I notice that we don't have a spec to cover the `--path` flag.  That seems like something worth adding.  In case anyone wants their first RBENV pull request, I'll leave that as an exercise for the reader.

Now on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-whence){:target="_blank" rel="noopener"}

### Printing Completions

After the calls to `set -e` and `set -x`, the first block of code is:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --path
  exec rbenv-shims --short
fi
```

This block checks whether the first argument is the string `--complete`.  If it is, the user is asking for a list of completions to the `rbenv whence` command.  In this case, we print the string "--path" and then print the list of shims that the user has installed, since each of those shim names is also a valid argument to pass to `rbenv whence`.

This block of code isn't covered by a test either.  That also seems like something worth adding, especially since we expect to see more than just hard-coded output (`rbenv-shims` generates dynamic content based on which executables are installed on the user's machine).  Such a test would have to do the following:

 - create at least one (ideally a few) executables
 - run `rbenv rehash`
 - run the `whence` command with the `--complete` flag, and
 - assert that the output contained `--path` plus the name(s) of any executable(s) created during the test setup.

Again, I leave that as an exercise for the reader.

### Preparing to print either the full path, or just the executable name

Next block of code:

```
if [ "$1" = "--path" ]; then
  print_paths="1"
  shift
else
  print_paths=""
fi
```

Here we see that we have the option of specifying a flag named `--path`.  If we do this, we set a variable named `print_paths` equal to `1` and shift it off of our argument stack.  Otherwise, we set it equal to the empty string.  We'll use `print_paths` later on in the code.

### Printing the output

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

Here we create a helper function named `whence`, which does the following:

 - We take the first argument provided to this helper, and store it in a local variable named `command`.  As we saw earlier, the first arg is the name of the command that we passed to `rbenv whence`.
 - We then run the `rbenv-versions --bare` command, which returns a list of Ruby version numbers.
 - This list then gets piped to the `read -r` command, storing each line in a local variable named `version`.
 - For each installed Ruby version, we then construct a possible filepath to the command within the Ruby version's directory.
 - If that filepath actually exists and corresponds to a file which is executable, we then print one of two things:
    - the path itself, if the user passed the `--path` flag, or
    - just the Ruby version itself, if the user did *not* pass `--path`.
 - When the `read` command is done reading lines of input from `rbenv-versions`, the `whence` helper function terminates.

### If the user forgot to specify a command

Next block of code:

```
RBENV_COMMAND="$1"
if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage whence >&2
  exit 1
fi
```

Here we check whether there was an argument passed to `rbenv whence`.  If not, we echo the "Usage" comments for this command and exit with a non-zero return code.

### Printing the results

Last block of code:

```
result="$(whence "$RBENV_COMMAND")"
[ -n "$result" ] && echo "$result"
```

Here we call our `whence` helper function, and store the results inside a variable named `result`.  If `result` is non-empty, we print its contents to the screen.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's the end of this file!  Next one:
