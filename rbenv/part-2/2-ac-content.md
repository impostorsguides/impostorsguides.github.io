First let's look at the "Summary" and "Usage" comments.

## ["Summary" and "Usage" Comments](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-which#L3-L8)

```
# Summary: Display the full path to an executable
#
# Usage: rbenv which <command>
#
# Displays the full path to the executable that rbenv will invoke when
# you run the given command.
```

Similar to the `which` external command, `rbenv which` shows you the filepath for the command you are about to run.  These commands correspond to Ruby gems you've installed, as opposed to RBENV commands themselves.

For example:

```
$ rbenv which rails

/Users/myusername/.rbenv/versions/2.7.5/bin/rails

$ rbenv which ruby

/Users/richiethomas/.rbenv/versions/2.7.5/bin/ruby
```

If you just type `rbenv which` with no command, you get a non-zero exit code and the "Usage" instructions printed to your terminal:

```
$ rbenv which

Usage: rbenv which <command>

$ echo $?

1
```

Next, the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/which.bats){:target="_blank" rel="noopener"}

### Creating an executable for our tests

After the `bats` shebang and loading of `test_helper`, the first block of code is:

```
create_executable() {
  local bin
  if [[ $1 == */* ]]; then bin="$1"
  else bin="${RBENV_ROOT}/versions/${1}/bin"
  fi
  mkdir -p "$bin"
  touch "${bin}/$2"
  chmod +x "${bin}/$2"
}
```

We create a helper method named `create_executable`, which does the following:

 - reads its first argument and checks whether it contains a forward-slash character.
 - If it does, then it assumes that the value is a specific directory that should be used to contain the upcoming executable file, and sets a local variable named `bin` equal to that first argument.
 - If it does not contain a "/", then it assumes that the value corresponds to just the name of the immediate parent directory, and constructs the rest of the directory structure accordingly, before setting `bin` equal to that pathname.
 - It then uses the value of `bin` to construct the needed directories, as well as an actual file (whose name comes from the 2nd arg passed to the helper function).
 - Lastly, it modifies that file to make it executable.

### Happy path- printing the executable's filepath

Next block of code is the first test:

```
@test "outputs path to executable" {
  create_executable "1.8" "ruby"
  create_executable "2.0" "rspec"

  RBENV_VERSION=1.8 run rbenv-which ruby
  assert_success "${RBENV_ROOT}/versions/1.8/bin/ruby"

  RBENV_VERSION=2.0 run rbenv-which rspec
  assert_success "${RBENV_ROOT}/versions/2.0/bin/rspec"
}
```

We do the following:

 - We create a mocked Ruby installation (version 1.8) and inside that directory, an executable file named "ruby".
 - We do the same with an executable file named `rspec` inside a mocked version of Ruby v2.0.
 - We then run the command with `RBENV_VERSION` set to 1.8 and an arg of `ruby`, and assert that the first path we created (for Ruby v1.8) is the one that's printed to `stdout`.
 - We then run the same test a 2nd time, replacing `1.8` with `2.0` and `ruby` with `rspec`.
 - Lastly, we make the same assertion- that the path that was printed to `stdout` was the expected path.

### When our Ruby version is `system`

Next test:

```
@test "searches PATH for system version" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

This test covers the `if`-block of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-which#L39-L40){:target="_blank" rel="noopener"}.  It does the following:

 - It creates two executables, both named `kill-all-humans`.  One lives in the `RBENV_TEST_DIR/bin` path, and the other in `RBENV_ROOT/shims`.
 - We set the selected Ruby version to `system` and run the `which` command for `kill-all-humans`.
 - We assert that the `RBENV_TEST_DIR/bin` version to be the filepath that's printed to `stdout`.

### Alternate path- when `shims/` is added to the beginning of `PATH`

Next test:

```
@test "searches PATH for system version (shims prepended)" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  PATH="${RBENV_ROOT}/shims:$PATH" RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

This is a similar setup to the previous test, except this time we're also passing an updated `PATH` to the command.  In particular, we're adding `${RBENV_ROOT}/shims` to the beginning of `PATH`, to make sure that `rbenv which` will encounter `shims/` before `bin/` when searching for the filepath.

We do this because we specifically assert that, even though the `shims/` filepath would normally be returned, this does not happen because `rbenv which` will ignore `shims/` if the Ruby version is `system`.

### Alternate path- when `shims/` is added to the the end of `PATH`

Next spec:

```
@test "searches PATH for system version (shims appended)" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  PATH="$PATH:${RBENV_ROOT}/shims" RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

Again, very similar test to the one before.  It seems like the goal is to ensure that, no matter where `RBENV_ROOT` falls in the path, `RBENV_TEST_DIR` (i.e. the path we're currently running the command from) is the path that's returned from the `rbenv which` command when the Ruby version is set to `system`.

### Alternate path- when `shims/` is added to `PATH` more than once

Next spec:

```
@test "searches PATH for system version (shims spread)" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  PATH="${RBENV_ROOT}/shims:${RBENV_ROOT}/shims:/tmp/non-existent:$PATH:${RBENV_ROOT}/shims" \
    RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

As before, the shell will use the first instance of an executable file which matches the name it's searching for.  This is a valuable test to have because sometimes a user's `PATH` variable will get polluted, with the same directory added multiple times.  We want to make sure that `rbenv which` doesn't exit early if it finds and removes a single instance of the `shims/` directory in `PATH`.

### When a command only exists in the current working directory, not in `PATH`

Next test:

```
@test "doesn't include current directory in PATH search" {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
  touch kill-all-humans
  chmod +x kill-all-humans
  PATH="$(path_without "kill-all-humans")" RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_failure "rbenv: kill-all-humans: command not found"
}
```

 - We make a directory with an executable inside of it, and navigate into that directory.
 - We ensure that `PATH` doesn't include the current directory, and we run the program.
 - We assert that `rbenv which` fails, and that the error message indicates that no executable with the specified name was found.

### When the specified Ruby version is not installed

Next spec:

```
@test "version not installed" {
  create_executable "2.0" "rspec"
  RBENV_VERSION=1.9 run rbenv-which rspec
  assert_failure "rbenv: version \`1.9' is not installed (set by RBENV_VERSION environment variable)"
}
```

 - This test creates an executable named "rspec" which is compatible with Ruby v2.0.
 - We then set the Ruby version to 1.9 via an environment variable, and run the `which` command to retrieve the path for this command.
 - We then assert that the command fails, and the error message indicates that v1.9 is not yet installed.

### When the requested executable is not installed

Next test:

```
@test "no executable found" {
  create_executable "1.8" "rspec"
  RBENV_VERSION=1.8 run rbenv-which rake
  assert_failure "rbenv: rake: command not found"
}
```

This test does the following:

- It creates an executable named "rspec" which is compatible with Ruby 1.8.
- It then runs the `which` command for that same version number, specifying a **different** (non-installed) executable file.
- Lastly, it asserts that the command fails, and that the specified executable was not found.

### Alternate test- when the selected Ruby version is `system`

Next test:

```
@test "no executable found for system version" {
  PATH="$(path_without "rake")" RBENV_VERSION=system run rbenv-which rake
  assert_failure "rbenv: rake: command not found"
}
```

This test covers the same edge case as the one before it- asserting that a specific error is returned and the command fails when a given executable requested but has not been installed.  The only differences seem to be that:

 - The selected Ruby version is `system`, and
 - The test author didn't explicitly create any executables beforehand.

This 2nd difference doesn't seem relevant to me, since when we did create an executable in the previous test, it wasn't the executable that we were running `rbenv which` on.  So the biggest difference is the differing versions of Ruby that are selected before running the test.

### When an executable exists, but only for non-selected Ruby versions

Next spec:

```
@test "executable found in other versions" {
  create_executable "1.8" "ruby"
  create_executable "1.9" "rspec"
  create_executable "2.0" "rspec"

  RBENV_VERSION=1.8 run rbenv-which rspec
  assert_failure
  assert_output <<OUT
rbenv: rspec: command not found
The \`rspec' command exists in these Ruby versions:
  1.9
  2.0
OUT
}
```

Here we do the following:

- We create 3 executables:
  - A `ruby` executable for Ruby version `1.8`
  - An `rspec` executable for Ruby version `1.9`, and
  - Another `rspec` executable for Ruby version `2.0`
- We then set our current Ruby version to 1.8 via an environment variable and run the `which` command, passing as an argument the name of the executable that is *not* installed in Ruby 1.8.
- We assert that the command fails because the executable was not found in our current Ruby version.
- We also assert that the printed error includes not only the 'command not found' message, but also a message stating which Ruby versions *do* contain the requested executable.

### Uses the original `IFS` value when `source`'ing any hooks

Next test:

```
@test "carries original IFS within hooks" {
  create_hook which hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
exit
SH

  IFS=$' \t\n' RBENV_VERSION=system run rbenv-which anything
  assert_success
  assert_output "HELLO=:hello:ugly:world:again"
}
```

We've seen a test like this before:

- We create a hook (in this case, for the `which` command) which relies on the internal field separator env var (`IFS`) to do its job.
- We then set `IFS` to something that will produce a certain string (a list of strings separated by colons), and run the `which` command with an arbitrary, throw-away parameter.
- Lastly, we assert that:
  - the command exited successfully, and that
  - the printed output is equal to the expected string.

### When the global Ruby version is selected

Last spec:

```
@test "discovers version from rbenv-version-name" {
  mkdir -p "$RBENV_ROOT"
  cat > "${RBENV_ROOT}/version" <<<"1.8"
  create_executable "1.8" "ruby"

  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"

  RBENV_VERSION= run rbenv-which ruby
  assert_success "${RBENV_ROOT}/versions/1.8/bin/ruby"
}
```

Here we do the following:

 - We set up our environment to include a global Ruby version file containing `1.8`.
 - We create an executable within that version called `ruby`.
 - We then make and navigate into our `$RBENV_TEST_DIR` directory.
 - We run the command with no previously-specified Ruby version, passing the name of our "ruby" executable as the argument.
 - Lastly, we assert that:
    - the command was successful, and that
    - the global Ruby version file was used to locate the Ruby executable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's all for the tests, now let's move on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-which){:target="_blank" rel="noopener"}

### Printing the available completions

After setting "exit-on-error" mode and "verbose" mode (if `RBENV_DEBUG` is turned on), the first block of code is:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  exec rbenv-shims --short
fi
```

If the first argument that the user provided to `rbenv which` is `--complete`, then we use `rbenv-shims --short` to print a list of the user's installed shims.  These shim names all represent valid arguments that the user can pass to `rbenv which`.

### The `remove_from_path` helper function

Next block of code:

```
remove_from_path() {
  local path_to_remove="$1"
  local path_before
  local result=":${PATH//\~/$HOME}:"
  while [ "$path_before" != "$result" ]; do
    path_before="$result"
    result="${result//:$path_to_remove:/:}"
  done
  result="${result%:}"
  echo "${result#:}"
}
```

Here we create a helper function named `remove_from_path`.  This is the function that we'll use to remove the `shims/` directory from `PATH` if the selected Ruby version is `system`.  We do this because `system` is not managed by RBENV- it's the version that is installed directly on our machine, and is not managed by any version manager.  Therefore we shouldn't invoke any shims when relying on it.

The function does the following:

- It creates 3 local variables:
    - `path_to_remove`, which we set to the first argument to the function.
    - `path_before`, which we leave unset for now.
    - `result`, which we initialize to the value of `$PATH`, with any values of `~` replaced with the value of `$HOME`.  More info on this can be found in the GNU "parameter expansion" docs [here](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}; search for the string "//".
 - It executes a `while` loop, which repeatedly removes instances of `path_to_remove` from `result`, until the value of `PATH` before removing `path_to_remove` is the same as the value after removing `path_to_remove` (in other words, when there are no more instances of `path_to_remove` left to remove).
 - It removes leading and trailing `:` characters from `result`, and then prints `result` to `stdout`.

### Handling a missing argument

```
RBENV_COMMAND="$1"
if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage which >&2
  exit 1
fi
```

We store the first argument to `rbenv which` inside a variable named `RBENV_COMMAND`.

If the user didn't provide a first argument, then we print the "Usage" comments from the beginning of the file to STDERR, and we exit with a non-zero return code.

### Setting `RBENV_VERSION` (unless it has already been set)

Next block of code:

```
RBENV_VERSION="${RBENV_VERSION:-$(rbenv-version-name)}"
```

We test whether the environment variable `RBENV_VERSION` is undefined or null, using the `:-` parameter expansion syntax mentioned in [the GNU docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}:

> ${parameter:-word}
>
> If parameter is unset or null, the expansion of word is substituted. Otherwise, the value of parameter is substituted.

If the value was previously set, that value is used.  If not, we set it equal to the value returned from the `rbenv version-name` command.

### Setting the path that we'll use to return a filepath

Next block of code:

```
if [ "$RBENV_VERSION" = "system" ]; then
  PATH="$(remove_from_path "${RBENV_ROOT}/shims")" \
    RBENV_COMMAND_PATH="$(command -v "$RBENV_COMMAND" || true)"
else
  RBENV_COMMAND_PATH="${RBENV_ROOT}/versions/${RBENV_VERSION}/bin/${RBENV_COMMAND}"
fi
```

Here we set the variable `RBENV_COMMAND_PATH`, which represents the value that we intend to print to `stdout`, assuming it's a valid path.

If we're using our machine's default version of Ruby instead of a version installed via RBENV, then we set this variable by doing the following:

 - removing RBENV's "shims/" path from our machine's `$PATH` environment variable, using our `remove_from_path` helper function from earlier.
 - using the version of `PATH` that we modified above to search for the user's specified command using `command -v`.
 - setting `RBENV_COMMAND_PATH` equal to the first filepath returned from the above call to `command -v`.

 Note that, by removing "shims/" from `$PATH`, the value to which we set `RBENV_COMMAND_PATH` will not be the path to an RBENV shim.  Again, this is because our `system` Ruby is not managed by RBENV, therefore we don't use RBENV's shims to call the gem executables.

If we're *not* using the `system` version of Ruby, we still create a new variable named `​​RBENV_COMMAND_PATH`, but this time we construct it based on the path we expect it to live in, based on our Ruby version, the command name, and the root location of our RBENV installation.

### Running any hooks for `rbenv which`

Next block of code:

```
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks which`)
IFS="$OLDIFS"
for script in "${scripts[@]}"; do
  source "$script"
done
```

We've seen this code in other commands, such as `rbenv exec`, `rbenv rehash`, etc, so we won't go into depth again here.  In short, this is where we initialize any and all hooks that the user has installed for the `rbenv which` command.

### Happy path- our command path exists and is executable

Next block of code:

```
if [ -x "$RBENV_COMMAND_PATH" ]; then
  echo "$RBENV_COMMAND_PATH"
```

First we check whether the constructed command path is executable by the user.  If it is, we echo it back and exit the command.  This is the happy path of this command.

### Sad path- the specified Ruby version is not installed

Next block of code:

```
elif [ "$RBENV_VERSION" != "system" ] && [ ! -d "${RBENV_ROOT}/versions/${RBENV_VERSION}" ]; then
  echo "rbenv: version \`$RBENV_VERSION' is not installed (set by $(rbenv-version-origin))" >&2
  exit 1
```

If it's not executable by the user, we check whether:

 - The user's current Ruby version is set to something *other than* the non-RBENV (aka "system") version, *and*
 - The user's current Ruby version does *not* correspond to a version that's currently installed within RBENV.

Both these things could be true if, for example, the directory that the user is currently in has a `.ruby-version` file which specifies a certain Ruby version, but the user doesn't have that version installed via RBENV.

In this case, we print a helpful error message saying which Ruby version is missing, along with the source which is telling RBENV to use that version (so that the user can potentially investigate whether that requested version is correct or not).

Lastly,  we exit with a non-zero return code.

### Sad path- the specified command was not found in the current Ruby version

```
else
  echo "rbenv: $RBENV_COMMAND: command not found" >&2

  versions="$(rbenv-whence "$RBENV_COMMAND" || true)"
  if [ -n "$versions" ]; then
    { echo
      echo "The \`$1' command exists in these Ruby versions:"
      echo "$versions" | sed 's/^/  /g'
      echo
    } >&2
  fi

  exit 127
fi
```

If neither of the above conditions were met, it means that either the user is using "system" Ruby, or the user is using a non-system Ruby version (i.e. a version installed via RBENV), but *does not* have the requested Ruby command installed *for their Ruby version*.

In either case, we do the following:

 - We first let the user know that the command was not found by printing an error message to STDERR.
 - We then use the `rbenv whence` command to check which Ruby versions *do* include the requested command.  If there are any such versions, we print them to the screen.
 - Whether or not we found other Ruby versions containing the requested command, we exit with a return code of 127.  This exit code [tells the user's shell](https://web.archive.org/web/20220930064126/https://linuxconfig.org/how-to-fix-bash-127-error-return-code){:target="_blank" rel="noopener"} that the command was not found.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

One more command to go, and then we can move on to the next folder in the main project directory.
