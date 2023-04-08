First, the tests:

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/which.bats){:target="_blank" rel="noopener"}

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

We create a helper method named `create_executable`, which reads its first argument and checks whether it contains a forward-slash character.  If it does, then it assumes that the value is a specific directory that should be used to contain the upcoming executable file, and sets a local variable named `bin` equal to that first argument.  If it does not contain a "/", then it assumes that the value corresponds to just the name of the immediate parent directory, and constructs the rest of the directory structure accordingly, before setting `bin` equal to that pathname.

We then use that directory path name contained in `bin` to construct the needed directories, as well as an actual file (whose name comes from the 2nd arg passed to the helper function), and modify that file to make it executable.

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

We create a mocked Ruby installation (version 1.8) and inside that directory, an executable file named "ruby".  We do the same with an executable file named `rspec` inside a mocked version of Ruby v2.0.  We then run the command with `RBENV_VERSION` set to 1.8 and an arg of "ruby", and assert that the first path we created (for Ruby v1.8) is the one that's printed to STDOUT, along with the "ruby" executable itself as the filename.

We then run the same test a 2nd time, replacing "1.8" with "2.0" and "ruby" with "rspec".  We then make the same assertion, i.e. that the path that was printed to STDOUT was the expected path.

Next test:

```
@test "searches PATH for system version" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

This test creates two executables, both named "kill-all-humans".  One lives in the `RBENV_TEST_DIR/bin` path, and the other in `RBENV_ROOT/shims`.  When we assume the selected Ruby version is "system" and run the `which` command on "kill-all-humans", we expect the `RBENV_TEST_DIR/bin` version to be the filepath that's printed to STDOUT.  I don't think we yet have enough information to deduce why this is.  We'll likely find out when we dive into the code.

Next test:

```
@test "searches PATH for system version (shims prepended)" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  PATH="${RBENV_ROOT}/shims:$PATH" RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

This is a similar setup to the previous test, except this time there's a different environment variable passed to the command.  Again, not sure why the expected result is `RBENV_TEST_DIR` here, since it falls *after* `RBENV_ROOT` [in the path sequence](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L26){:target="_blank" rel="noopener"} that `test_helper` sets.  Let's wait and see when we get to the code.

Next spec:

```
@test "searches PATH for system version (shims appended)" {
  create_executable "${RBENV_TEST_DIR}/bin" "kill-all-humans"
  create_executable "${RBENV_ROOT}/shims" "kill-all-humans"

  PATH="$PATH:${RBENV_ROOT}/shims" RBENV_VERSION=system run rbenv-which kill-all-humans
  assert_success "${RBENV_TEST_DIR}/bin/kill-all-humans"
}
```

Again, very similar test to the one before.  It seems like the goal is to ensure that, no matter where `RBENV_ROOT` falls in the path, `RBENV_TEST_DIR` (i.e. the path we're currently running the command from) is the path that's returned from the `rbenv which` command.  Not sure why, but I hope we'll find out.

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

Another confusing test to me.  The fact that `PATH` includes `RBENV_ROOT/shims` multiple times (both before and after the original `PATH` value) shouldn't be any different from the test where it appears one time before the original value.  Either way, the shell will use the first instance of an executable file which matches the name it's searching for.  Once again, let's wait and see.

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

We make a directory with an executable inside of it, and navigate into that directory.  We ensure that `PATH` doesn't include the current directory, and we run the program.  We assert that `rbenv which` fails, and that the error message indicates that no executable with the specified name was found.

Next spec:

```
@test "version not installed" {
  create_executable "2.0" "rspec"
  RBENV_VERSION=1.9 run rbenv-which rspec
  assert_failure "rbenv: version \`1.9' is not installed (set by RBENV_VERSION environment variable)"
}
```

This test creates an executable named "rspec" which is compatible with Ruby v2.0.  We then run the `which` command to retrieve the path for this command, but first we set the Ruby version to 1.9.  We then assert that the command fails, and the error message indicates that v1.9 is not yet installed.

Next test:

```
@test "no executable found" {
  create_executable "1.8" "rspec"
  RBENV_VERSION=1.8 run rbenv-which rake
  assert_failure "rbenv: rake: command not found"
}
```

This test creates an executable named "rspec" which is compatible with Ruby 1.8.  It then runs the `which` command for that same version number, but specifying a different (non-installed) executable file.  The test asserts that the command fails, and that the specified executable was not found.

Next test:

```
@test "no executable found for system version" {
  PATH="$(path_without "rake")" RBENV_VERSION=system run rbenv-which rake
  assert_failure "rbenv: rake: command not found"
}
```

This test seems to cover the same edge case as the one before it- asserting that a specific error is returned and the command fails when a given executable requested but has not been installed.  I was wondering why this might be the case, so I checked the `git blame` history for these two tests:

```
969af156 (Mislav Marohnić 2013-04-06 12:30:21 +0200  74) @test "no executable found" {
969af156 (Mislav Marohnić 2013-04-06 12:30:21 +0200  75)   create_executable "1.8" "rspec"
969af156 (Mislav Marohnić 2013-04-06 12:30:21 +0200  76)   RBENV_VERSION=1.8 run rbenv-which rake
969af156 (Mislav Marohnić 2013-04-06 12:30:21 +0200  77)   assert_failure "rbenv: rake: command not found"
969af156 (Mislav Marohnić 2013-04-06 12:30:21 +0200  78) }
969af156 (Mislav Marohnić 2013-04-06 12:30:21 +0200  79)
3405c4d0 (Mislav Marohnić 2015-11-13 22:57:22 -0500  80) @test "no executable found for system version" {
a9ca72ab (Daniel Hahler   2017-06-05 15:27:58 +0200  81)   PATH="$(path_without "rake")" RBENV_VERSION=system run rbenv-which rake
3405c4d0 (Mislav Marohnić 2015-11-13 22:57:22 -0500  82)   assert_failure "rbenv: rake: command not found"
3405c4d0 (Mislav Marohnić 2015-11-13 22:57:22 -0500  83) }
```

I see that they were introduced about several years apart (`2013-04-06` vs `2015-11-13`), which was probably long enough for the author to have forgotten their prior work on the first test when introducing the 2nd one.

(stopping here for the day; 86204 words)

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

Here we create 3 executables, one in each of Ruby versions 1.8, 1.9, and 2.0.  We set our current Ruby version to 1.8 via an environment variable and run the `which` command, passing as an argument the name of the executable that is *not* installed in Ruby 1.8.  We assert that the command fails because the executable was not found in our current Ruby version, and we also assert that the printed error includes not only the 'command not found' message, but also a message stating which Ruby versions *do* contain the requested executable.

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

We've seen a test like this before, for other commands.  We create a hook (in this case, for the `which` command) which relies on the internal field separator env var (`IFS`) to do its job.  We then set `IFS` to something that will produce a certain string (a list of strings separated by colons), and run the `which` command with an arbitrary, throw-away parameter.  We assert that the command exited successfully and that the printed output is equal to the expected string.

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

Here we set up our environment to include a global Ruby version file containing "1.8", and we create an executable within that version called "ruby".  We then make and navigate into a directory named `$RBENV_TEST_DIR` (this is the same directory that's usually created in the `setup()` hook method that we've seen in other test files).  Lastly, we run the command with no previously-specified Ruby version, passing the name of our "ruby" executable as the argument.  We assert that the command was successful and that the global Ruby version file was used to locate the Ruby executable.

NOTE: I'm not sure why the `RBENV_TEST_DIR` setup is done in-line instead of with a similar hook method, but I try replacing the latter with the former and the tests all pass, so I make a quick commit on my local repo to push up later.

On to the code itself:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-which){:target="_blank" rel="noopener"}

First block of code:

```
#!/usr/bin/env bash
#
# Summary: Display the full path to an executable
#
# Usage: rbenv which <command>
#
# Displays the full path to the executable that rbenv will invoke when
# you run the given command.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
#!/usr/bin/env bash
#
# Summary: Display the full path to an executable
#
# Usage: rbenv which <command>
#
# Displays the full path to the executable that rbenv will invoke when
# you run the given command.

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

 - The `bash` shebang
 - The "Summary", "Usage", and "help" comments.  Looks like the purpose of `rbenv which` is to "Display the full path to an executable", and that the first (and only) argument is meant to be the name of the command whose full path the user is requesting.
 - `set -e` to tell the shell to exit immediately upon reaching an exception
 - `set -x` to tell the shell to print to STDOUT in verbose mode, in this case only when the `RBENV_DEBUG` env var is set

Next block of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  exec rbenv-shims --short
fi
```

If the first argument that the user provided to `rbenv which` is `--complete`, then we use `rbenv-shims --short` to print a list of the user's installed shims.  These shim names all represent valid arguments that the user can pass to `rbenv which`.

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

Here we create a helper function named `remove_from_path`.  As a first step inside the function, we create 3 local variables:


 - `path_to_remove`, which we set to the first argument to the function.
 - `path_before`, which we leave unset for now.
 - `result`, which we initialize to the value of `$PATH`, with any values of `~` replaced with the value of `$HOME`.  I found this by looking for the GNU "parameter expansion" docs [here](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}, and searching for the string "//":

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-18mar2023-1145am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Next we create a `while` loop that repeatedly removes instances of `path_to_remove` from `result`, until there are no more instances left to remove.  I'm not sure why we need *both* a `while` loop and the following line:

```
result="${result//:$path_to_remove:/:}"
```

This is because the docs which are linked above say the following:

If there are two slashes separating parameter and pattern (the second form above), all matches of pattern are replaced with string.

This seems to indicate that the double-"//" syntax does the same job as repeatedly iterating over `PATH`.

To test this, I paste the following function in my `bash` shell:

```
remove_from_path() {
  local path_to_remove="$1"
  local path_before
  local result=":${PATH//\~/$HOME}:"
  declare -i counter                              # I added this
  counter=0                                       # I added this
  while [ "$path_before" != "$result" ]; do
    counter+=1                                    # I added this
    echo "counter: $counter"                      # I added this
    path_before="$result"
    result="${result//:$path_to_remove:/:}"
  done
  result="${result%:}"
  echo "${result#:}"
}
```

I then set up my `PATH` variable like so:

```
$ PATH="/foo/bar/baz:/foo/bar/baz:/foo/bar/baz:$PATH"

~/Workspace/OpenSource ()  $ echo "$PATH"

/foo/bar/baz:/foo/bar/baz:/foo/bar/baz:/Users/myusername/.nvm/versions/node/v18.12.1/bin:/Users/myusername/.rbenv/shims:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/Users/myusername/.rbenv/shims:/Users/myusername/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/Users/myusername/.cargo/bin:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Users/myusername/.asdf/shims:/Users/myusername/.asdf/bin:/Users/myusername/.rbenv/shims:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Applications/Postgres.app/Contents/Versions/latest/bin
```

When I run `remove_from_path "/foo/bar/baz"`, I get the following:

```
$ remove_from_path "/foo/bar/baz"
counter: 1
counter: 2
counter: 3
counter: 4
/Users/myusername/.nvm/versions/node/v18.12.1/bin:/Users/myusername/.rbenv/shims:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/Users/myusername/.rbenv/shims:/Users/myusername/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/Users/myusername/.cargo/bin:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Users/myusername/.asdf/shims:/Users/myusername/.asdf/bin:/Users/myusername/.rbenv/shims:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/myusername/.yarn/bin:/Users/myusername/.config/yarn/global/node_modules/.bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Applications/Postgres.app/Contents/Versions/latest/bin

```

My `counter` variable shows me how many iterations occurred.  And this is more iterations than I expected!  I thought there would be only one iteration because of the "//" syntax, but it looks like there were 4 iterations!

I post [a StackExchange question](https://unix.stackexchange.com/questions/722939/bash-parameter-expansion-how-to-replace-all-instances-of-pattern-with-stri){:target="_blank" rel="noopener"} about this, and am waiting for an answer.

At any rate, the result is our previous value of `$PATH`, minus a specific path specified as the first arg to the helper function.  The lines `  result="${result%:}"` and `echo "${result#:}"` just strip off leading and trailing `:` characters.

Next block of code:

```
RBENV_COMMAND="$1"
```

This just stores the first argument to `rbenv which` in a variable named `RBENV_COMMAND`.

Next block of code:

```
if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage which >&2
  exit 1
fi
```

If the user didn't provide that first argument (which then gets stored in the `RBENV_COMMAND` variable), then we print the "Usage" comments from the beginning of the file to STDERR, and we exit with a non-zero return code.

Next block of code:

```
RBENV_VERSION="${RBENV_VERSION:-$(rbenv-version-name)}"
```

Here we test whether the environment variable `RBENV_VERSION` is undefined or null, using the `:-` parameter expansion syntax mentioned in [the GNU docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}:

> ${parameter:-word}
>
> If parameter is unset or null, the expansion of word is substituted. Otherwise, the value of parameter is substituted.

If the value was previously set, that value is used.  If not, we set it equal to the value returned from the `rbenv version-name` command.

Next block of code:

```
if [ "$RBENV_VERSION" = "system" ]; then
  PATH="$(remove_from_path "${RBENV_ROOT}/shims")" \
    RBENV_COMMAND_PATH="$(command -v "$RBENV_COMMAND" || true)"
else
  RBENV_COMMAND_PATH="${RBENV_ROOT}/versions/${RBENV_VERSION}/bin/${RBENV_COMMAND}"
fi
```

If we're using our machine's default version of Ruby instead of a version installed via RBENV, then we remove RBENV's "shims/" path from our machine's `$PATH` environment variable using our `remove_from_path` helper function from earlier.  We also create a variable named `RBENV_COMMAND_PATH` and set it equal to the filepath to the user's requested executable.  If no such path is found, we set `RBENV_COMMAND_PATH` equal to the boolean value `true`.  Note that, by removing "shims/" from `$PATH`, the value to which we set `RBENV_COMMAND_PATH` will not be the path to an RBENV shim.

If we're *not* using our machine's default version of Ruby, we still create a new variable named `​​RBENV_COMMAND_PATH`, but this time we set it equal to the expected path to the RBENV shim corresponding to the user's requested executable.

Next block of code:

```
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks which`)
IFS="$OLDIFS"
for script in "${scripts[@]}"; do
  source "$script"
done
```

Here is where we initialize any and all hooks that the user has installed for the `rbenv which` command.  We've seen this syntax before, so we won't go into depth again here.

Last block of code:

```
if [ -x "$RBENV_COMMAND_PATH" ]; then
  echo "$RBENV_COMMAND_PATH"
elif [ "$RBENV_VERSION" != "system" ] && [ ! -d "${RBENV_ROOT}/versions/${RBENV_VERSION}" ]; then
  echo "rbenv: version \`$RBENV_VERSION' is not installed (set by $(rbenv-version-origin))" >&2
  exit 1
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

(stopping here for the day; 87654 words)

First we check whether the constructed command path is executable by the user.  If it is, we echo it back and exit the command.  This is the happy path of this command.

If it's not executable by the user, we check whether:

The user's current Ruby version is set to something *other than* the non-RBENV (aka "system") version, *and*
The user's current Ruby version does *not* correspond to a version that's currently installed within RBENV.

Both these things could be true if, for example, the directory that the user is currently in has a ".ruby-version" file which specifies a certain Ruby version, but the user doesn't have that version installed via RBENV.  In this case, we print a helpful error message saying which Ruby version is missing, along with the source which is telling RBENV to use that version (so that the user can potentially investigate whether that requested version is correct or not).  Lastly,  we exit with a non-zero return code.

If one or the other of these conditions are false, it means that either:

The user is using "system" Ruby, or
the user is using a non-system Ruby version (i.e. a version installed via RBENV), but *does not* have the requested Ruby command installed *for their Ruby version*.

In either case, we first let the user know that the command was not found by printing an error message to STDERR.  We then use the `rbenv whence` command to check which Ruby versions *do* include the requested command.  If there are any such versions, we print them to the screen.  Whether or not we found Ruby versions with the requested command, we exit with a return code of 127.  This exit code [tells the user's shell](https://web.archive.org/web/20220930064126/https://linuxconfig.org/how-to-fix-bash-127-error-return-code){:target="_blank" rel="noopener"} that the command was not found.

Holy cow!  We're finally done with the `libexec/` folder and its tests!  Now we can move on to the next folder in the main project directory: "rbenv.d/exec/".
