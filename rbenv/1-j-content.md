As per usual, we’ll look at the tests 1st and the code 2nd.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/completions.bats)

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_command() {
  bin="${RBENV_TEST_DIR}/bin"
  mkdir -p "$bin"
  echo "$2" > "${bin}/$1"
  chmod +x "${bin}/$1"
}
```

Here we create a helper function called `create_command`, which creates an executable file whose name is set by the first argument to this function, and whose content is the 2nd argument.  Skipping ahead to some of the tests which call this function, it looks like the 2nd command is a multi-line string containing executable code.

Next block of code is our first test:

```
@test "command with no completion support" {
  create_command "rbenv-hello" "#!$BASH
    echo hello"
  run rbenv-completions hello
  assert_success "--help"
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-completions#L21).  We make a simple command file containing only the `bash` shebang and an `echo` statement.  Because the file doesn’t include any completion comments, when the `completions` command is passed the name of our new file, it should only output the standard completions which are common to all files.  When we run the command, we assert that this is exactly what happens.

Next test:

```
@test "command with completion support" {
  create_command "rbenv-hello" "#!$BASH
# Provide rbenv completions
if [[ \$1 = --complete ]]; then
  echo hello
else
  exit 1
fi"
  run rbenv-completions hello
  assert_success
  assert_output <<OUT
--help
hello
OUT
}
```

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-completions#L23-L26).  We once again create a fake command named “hello”, this time containing the comment `# Provide rbenv completions` as well as some logic to conditionally print “hello” when the command is passed the “--complete” flag.  If that flag is not passed to our fake command, the exit code will be non-zero and the test will fail.  We then pass the name of the “hello” command to `rbenv completions`, and assert that a) the exit code is 0, and b) the printed output contains both the “hello” string and the “--help” completion that all commands have.

This test implies that, even though we don’t explicitly pass the “--complete” flag to “rbenv completions hello”, something in the code still passes this flag anyway.  That logic is part of `rbenv completions`.  When the command file we create includes the comment `# Provide rbenv completions`, then running `rbenv completions` for that command causes the `completions` file to run that command and also pass it the “--complete” flag.

Next test:

```
@test "forwards extra arguments" {
  create_command "rbenv-hello" "#!$BASH
# provide rbenv completions
if [[ \$1 = --complete ]]; then
  shift 1
  for arg; do echo \$arg; done
else
  exit 1
fi"
  run rbenv-completions hello happy world
  assert_success
  assert_output <<OUT
--help
happy
world
OUT
}
```

We have a test which is very similar to the one before.  We create a fake command file named `rbenv-hello` which contains a bash script with completions logic.  The logic tests for the presence of the “--complete” flag, and responds accordingly.  The difference is, this script prints out each argument passed to `rbenv-hello`, instead of just printing out “hello”.  We run the `rbenv completions` command for “hello”, passing two additional args, and assert that those two args are printed to STDOUT, in addition to the “--help” flag.

Now that we’ve finished the tests, let’s move on to the code.

(stopping here for the day; 95768 words)

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-completions)

First few lines of code:

```
#!/usr/bin/env bash
# Usage: rbenv completions <command> [arg1 arg2...]

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

No surprises here:

A `bash` shebang
Some usage comments
Telling bash to exit on the first error
Setting “verbose” mode (at least, that’s what I call it) if the user has set the `RBENV_DEBUG` environment variable

Next few lines of code:

```
COMMAND="$1"
if [ -z "$COMMAND" ]; then
  rbenv-help --usage completions >&2
  exit 1
fi
```
Here we store the user’s first argument to “completions” in a variable named `COMMAND`.  If that variable is empty (i.e. if the user just typed `rbenv completions` without any further argument), then we print the usage instructions for this command (taken from the `rbenv help` command) and exit with an error code of 1.

Next few lines of code:

```
# Provide rbenv completions
if [ "$COMMAND" = "--complete" ]; then
  exec rbenv-commands
fi
```

If the user typed `rbenv completions --complete`, then they want to know what arguments are possible to pass to `rbenv completions`.  Since the purpose of `rbenv completions` is to tell the user which arguments are possible for which rbenv commands, that means it’s possible to pass any valid rbenv command to “rbenv completions”.  So if the user types `rbenv completions --complete`, we print out all valid rbenv commands.

Next line of code:

```
COMMAND_PATH="$(command -v "rbenv-$COMMAND" || command -v "rbenv-sh-$COMMAND")"
```

Here we store the full filename of the command the user is entering.  For example, if the user typed `rbenv commands global`, Then we’d store the value “rbenv-global” in `COMMAND_PATH`.  If the user types `rbenv completions shell`, we’d store `rbenv-sh-shell` in `COMMAND_PATH`.

Next line of code:

```
echo --help
```

Looks like we always include `--help` in the `completions` output, no matter what.

Next and final lines of code:

```
if grep -iE "^([#%]|--|//) provide rbenv completions" "$COMMAND_PATH" >/dev/null; then
  shift
  exec "$COMMAND_PATH" --complete "$@"
fi
```
Here we’re using the `grep` command.  The usage is:

`grep` (the name of the command we’re using)
Any flags we want to pass
The `-i` flag tells us to ignore case sensitivity
The `-E` flag tells `grep` that we’ll be passing a regular expression pattern, instead of a plain string
string or pattern to search for (i.e. `"^([#%]|--|//) provide rbenv completions"`)
Here the `^` character means that the following characters should begin the string
The `(...|...|...)` pattern means that we’re looking for one of 3 possible patterns to start the string (the `|` syntax means “or”).  So “(#|-|/)” means “# or - or /”.
The syntax [...] means “any one of the characters inside the square brackets.  So `[#%]` means “either # or %”.
Source [here](https://tldp.org/LDP/abs/html/x17129.html).
I’m guessing that we’re using this particular regex, at the start of the string, because these are the various ways that a comment can be started in bash, zsh, fish, and any other shells that rbenv supports.
The filepath that we’re searching for this string.  In this case, it’s the filepath we stored in `$COMMAND_PATH`.
Lastly, we send the results to `/dev/null`.  We don’t actually care what the results are, only whether or not there was a match.

If there was a match, then we shift off the first argument from our list of arguments and run the command itself, passing it the `--complete` option that we’ve encountered before, for example [here](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-commands#L9).  This displays the possible completions just for that one command, then exits.

TODO- do an experiment which tests my theory about the above regex.

That’s it for this file!
