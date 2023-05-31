As per usual, we'll look at the tests first, and the code afterward.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/completions.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_command() {
  bin="${RBENV_TEST_DIR}/bin"
  mkdir -p "$bin"
  echo "$2" > "${bin}/$1"
  chmod +x "${bin}/$1"
}
```

Here we create a helper function called `create_command`, which does the following:

 - makes a string variable corresponding to a subdirectory of our test directory, named `bin/`
 - makes an actual directory with that name.
 - makes a file whose name is the first argument provided to `create_command`, and whose code is the 2nd argument.
 - makes that new file executable.

### Running `rbenv completions` on a command with no completions

Next block of code is our first test:

```
@test "command with no completion support" {
  create_command "rbenv-hello" "#!$BASH
    echo hello"
  run rbenv-completions hello
  assert_success "--help"
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-completions#L21){:target="_blank" rel="noopener"}.  We make a simple command file containing only the `bash` shebang and an `echo` statement.  Because the file doesn't include any completion comments, when the `completions` command is passed the name of our new file, it should only output the standard completions which are common to all files (i.e. `--help`).  When we run the command, we assert that this is exactly what happens.

### Running `rbenv completions` on a command with completions

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

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-completions#L23-L26){:target="_blank" rel="noopener"}.  We do the following:

 - We again create a fake command named "hello".
 - This time our command contains the comment `# Provide rbenv completions` as well as some logic to conditionally print "hello" when the command is passed the "--complete" flag.
    - If that flag is not passed to our fake command, the exit code will be non-zero and the test will fail.
    - If that flag is passed, the exit code will be zero, the test will pass, and the output will include the string "hello".
 - We then pass the name of the "hello" command to `rbenv completions`, and assert that;
    - the exit code is 0, and
    - the printed output contains both the "hello" string and the "--help" completion that all commands have.

Notice that our fake command checked whether the user passed the `--complete` flag, but when we ran the command, we didn't pass this flag explicitly.  Because we still expected the output to include "hello", this implies that something in the command's code still passes this flag anyway.

As we'll see below, when the command file we create includes the comment `# Provide rbenv completions`, then running `rbenv completions` for that command causes the `completions` file to run that command and also pass it the "--complete" flag.

### Handling extra arguments

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

We have a test which is very similar to the one before:

 - We create a fake command file named `rbenv-hello` which contains a bash script with completions logic.  The logic tests for the presence of the "--complete" flag, and responds accordingly.
 - In contrast to the previous test, however, this test's script prints out each argument passed to `rbenv-hello`, instead of just printing out "hello".
 - We run the `rbenv completions` command for "hello", passing two additional args, and assert that those two args are printed to STDOUT, in addition to the "--help" flag.

Now that we've finished the tests, let's move on to the code.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-completions){:target="_blank" rel="noopener"}

First few lines of code:

```
#!/usr/bin/env bash
# Usage: rbenv completions <command> [arg1 arg2...]

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

No surprises here:

 - A `bash` shebang
 - Some usage comments
 - Telling bash to exit on the first error
 - Setting "verbose" mode if the user has set the `RBENV_DEBUG` environment variable

### Storing the command argument and printing usage instructions

Next few lines of code:

```
COMMAND="$1"
if [ -z "$COMMAND" ]; then
  rbenv-help --usage completions >&2
  exit 1
fi
```

We saw this same logic when we read the code for `rbenv hooks`.

 - We store the user's first argument to "completions" in a variable named `COMMAND`.
 - If that variable is empty (i.e. if the user just typed `rbenv completions` without any further argument), then we print the usage instructions for this command (taken from the `rbenv help` command) and exit with an error code of 1.

### Generating completions

Next few lines of code:

```
# Provide rbenv completions
if [ "$COMMAND" = "--complete" ]; then
  exec rbenv-commands
fi
```

 - If the user typed `rbenv completions --complete`, then they want to know what arguments are possible to pass to `rbenv completions`.
 - Since the purpose of `rbenv completions` is to tell the user which arguments are possible for which rbenv commands, that means it's possible to pass any valid rbenv command to `rbenv completions`.
 - So if the user types `rbenv completions --complete`, we print out all valid rbenv commands.

### Storing the path to the command's file

Next line of code:

```
COMMAND_PATH="$(command -v "rbenv-$COMMAND" || command -v "rbenv-sh-$COMMAND")"
```

Here we store the full filename of the command the user is entering.  For example:

 - If the user typed `rbenv commands global`, Then we'd store the value `/Users/myusername/.rbenv/libexec/rbenv-global` in `COMMAND_PATH`.
 - If the user types `rbenv completions shell`, we'd store `/Users/myusername/.rbenv/libexec/rbenv-sh-shell` instead.

### Printing `--help`

Next line of code:

```
echo --help
```

Looks like we always include `--help` in the `completions` output, no matter what, because every command accepts the `--help` flag.

### Conditionally printing the completion instructions

The final block of code is:

```
if grep -iE "^([#%]|--|//) provide rbenv completions" "$COMMAND_PATH" >/dev/null; then
  shift
  exec "$COMMAND_PATH" --complete "$@"
fi
```
Here we're using the `grep` command.  Out of all the commands I've used while working in the command line, `grep` is one of the more common ones.

If we run `man grep`, we see the `man` entry starts with the following:

```
GREP(1)                                                              General Commands Manual                                                             GREP(1)

NAME
     grep, egrep, fgrep, rgrep, bzgrep, bzegrep, bzfgrep, zgrep, zegrep, zfgrep – file pattern searcher

SYNOPSIS
     grep [-abcdDEFGHhIiJLlMmnOopqRSsUVvwXxZz] [-A num] [-B num] [-C[num]] [-e pattern] [-f file] [--binary-files=value] [--color[=when]] [--colour[=when]]
          [--context[=num]] [--label] [--line-buffered] [--null] [pattern] [file ...]

DESCRIPTION
     The grep utility searches any given input files, selecting lines that match one or more patterns.  By default, a pattern matches an input line if the
     regular expression (RE) in the pattern matches the input line without its trailing newline.  An empty expression matches every line.  Each input line that
     matches at least one of the patterns is written to the standard output.

     grep is used for simple patterns and basic regular expressions (BREs); egrep can handle extended regular expressions (EREs).  See re_format(7) for more
     information on regular expressions.  fgrep is quicker than both grep and egrep, but can only handle fixed patterns (i.e., it does not interpret regular
     expressions).  Patterns may consist of one or more lines, allowing any of the pattern lines to match a portion of the input.

...
```

The part of the above entry to zero in on is the description:

```
The grep utility searches any given input files, selecting lines that match
one or more patterns.
```

So we're searching an input file for a regex pattern.  We do so by invoking the command as follows:

- `grep` (the name of the command we're using)
  - The `-i` flag tells us to ignore case sensitivity
  - The `-E` flag tells `grep` that we'll be passing a regular expression pattern, instead of a plain string
- the string or pattern to search for.
- The filepath that we're searching for this string.  In this case, it's the filepath we stored in `$COMMAND_PATH`.

Lastly, we send the results to `/dev/null`.  We don't actually care what the results are, only whether or not there was a match.

### Breaking down the regex expression

The pattern that we pass to `grep` is:

```
"^([#%]|--|//) provide rbenv completions"
```

This translates to:

 - the pattern `^([#%]|--|//)`,
 - a space,
 - the plain string `provide rbenv completions`.

The plain string is easy to reason about, so let's focus on the pattern.

 - Here the `^` character means that regex pattern which follows should appear at the start of the string.
- `(#|-|/)` means `# or - or /`.  More generally, the `|` syntax means "or", and the parentheses with several `|` characters (i.e. `(...|...|...)` ) means that we're looking for one of 3 possible patterns to start the string.
- The syntax `[...]` means "any one of the characters inside the square brackets.  So `[#%]` means `either # or %`.  Source [here](https://tldp.org/LDP/abs/html/x17129.html){:target="_blank" rel="noopener"}.

So to sum up the pattern, we're looking for:

 - a leading `#`, `%`, `--`, or `//`, followed by
 - a space, followed by
 - the string `provide rbenv completions`.

If there was a match, then we shift off the first argument from our list of arguments and run the command itself, passing it the `--complete` option that we've encountered before, for example [here](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-commands#L9){:target="_blank" rel="noopener"}.  This displays the possible completions just for that one command, then exits.

### Why do we use *this* regex pattern?

The original regex pattern used in `rbenv-completions` was much simpler- just `^#`.  It was updated to this particular regex pattern (`^\([#%]\|--\|//\)`) as part of [this commit](https://github.com/rbenv/rbenv/commit/497911d6c093341cc1420f1f3f6f1fae5f64d0f5){:target="_blank" rel="noopener"}, in order to support Javascript, Lua, and Erlang comments as well as `bash` comments.  Unfortunately we don't have any discussion around this commit, so we don't know why support was added for these languages, and not others.

I'll admit I'm a bit confused about why this was necessary.  If I had to speculate, I'd say that some people prefer to write their RBENV plugins in one of these languages, and the core team felt that this was a popular enough choice that it warranted support, in the form of this update to the regex pattern.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for this file!  Let's move on to the next one.
