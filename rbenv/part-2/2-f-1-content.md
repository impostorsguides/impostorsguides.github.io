As with the `rbenv` command, let's start by looking at this command's tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/init.bats){:target="_blank" rel="noopener"}

After the `bats` shebang and the loading of the `test_helper` file, the first test is:

```
@test "creates shims and versions directories" {
  assert [ ! -d "${RBENV_ROOT}/shims" ]
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-init -
  assert_success
  assert [ -d "${RBENV_ROOT}/shims" ]
  assert [ -d "${RBENV_ROOT}/versions" ]
}
```

We first perform some sanity-check assertions stating that the `${RBENV_ROOT}/shims` and `${RBENV_ROOT}/versions` directories do not exist.

We then run the command with the `-` flag.  [If this flag is missing](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L46){:target="_blank" rel="noopener"}, then `rbenv init` prints out usage instructions and [exits with a failure return code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L83){:target="_blank" rel="noopener"}, which we'll see in the next section.

Lastly, we assert that the command ran successfully and that the two formerly-missing directories have been created.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "auto rehash" {
  run rbenv-init -
  assert_success
  assert_line "command rbenv rehash 2>/dev/null"
}
```

We explicitly avoid passing the `--no-rehash` argument, which means that we don't set the value of the `no_rehash` variable [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L28){:target="_blank" rel="noopener"}.  Because of that, [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L104){:target="_blank" rel="noopener"} prints the string `command rbenv rehash 2>/dev/null` to STDOUT.

When we start analyzing the command file, we'll see that these commands which are printed to STDOUT are actually captured by [command substitution](https://web.archive.org/web/20221010044921/https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html){:target="_blank" rel="noopener"}, and executed by `bash`.  So when we see an assertion that expects a certain string of code to be printed, that's what's happening.

This particular line of code, `command rbenv rehash 2>/dev/null`, means that we're trying to "rehash" (or regenerate) our shim files.  As we discussed in our read-through of the `rbenv` file, the use of the `command` command means that we bypass our `rbenv` shell function, and instead directly call our `rbenv` script.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "setup shell completions" {
  root="$(cd $BATS_TEST_DIRNAME/.. && pwd)"
  run rbenv-init - bash
  assert_success
  assert_line "source '${root}/test/../libexec/../completions/rbenv.bash'"
}
```

This test covers the 4-line block of code starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L97){:target="_blank" rel="noopener"}:

 - We store the value of our root directory, and run `rbenv-init` while specifying `bash` as our shell.
 - We assert that:
   - the command completed successfully and that
   - the output contains a line of code which `source`s a certain file called `completions/rbenv.bash`.

The file that gets `source`'ed lives [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/completions/rbenv.bash){:target="_blank" rel="noopener"}.  This action only takes place when the user passes `bash` as the argument to `rbenv init -`, as shown in the test.  We haven't read through this file yet, but we'll do so in the future.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "detect parent shell" {
  SHELL=/bin/false run rbenv-init -
  assert_success
  assert_line "export RBENV_SHELL=bash"
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L36){:target="_blank" rel="noopener"} and the lines after it.  We purposely set the `SHELL` env var to be a falsy value, and run the command with no argument after the "-" character.

At [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L34){:target="_blank" rel="noopener"}, the `$shell` variable is initialized to the first argument in our current list of args.  In our case, we didn't pass a specific shell name (like we did with `bash` in the previous test), so this variable will be empty.

As the block of code executes, the value of `shell` is populated and then progressively whittled down until we are left with just the shell's name.

We can see this by adding a bunch of `echo` statements to this block of code, like so:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-13mar2023-725am.png">
    <img src="/assets/images/screenshot-13mar2023-725am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

When I run the test, and print out `foo.txt`, I get:

<center style="margin-bottom: 3em">
  <a target="_blank" href="/assets/images/screenshot-13mar2023-726am.png">
    <img src="/assets/images/screenshot-13mar2023-726am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

You can see that, on my machine, the canonical shell name had been fully-resolved by the time we get to the 4th `echo` statement.  But that's not necessarily true on every possible computer.  Since the output of `ps -p "$PPID" -o 'args='` will be different depending on the machine you run this command on, multiple lines of parameter expansion are necessary in order to accomodate all machine types.

Once we know which shell the user is using, we can construct our shell function to suit their shell type, which is the point of the `rbenv-init` command.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "detect parent shell from script" {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
  cat > myscript.sh <<OUT
#!/bin/sh
eval "\$(rbenv-init -)"
echo \$RBENV_SHELL
OUT
  chmod +x myscript.sh
  run ./myscript.sh
  assert_success "sh"
}
```

In the first part of the test, we create and navigate into a test directory:

```
mkdir -p "$RBENV_TEST_DIR"
cd "$RBENV_TEST_DIR"
```

In that directory we create a test script which contains an `sh` shebang and a call to `eval` RBENV's `init` command with no explicit shell set.  We also run `chmod +x` on the file, to make it executable:

```
cat > myscript.sh <<OUT
  #!/bin/sh
  eval "\$(rbenv-init -)"
  echo \$RBENV_SHELL
OUT

chmod +x myscript.sh
```

Lastly, we run the script and assert that a) it completed successfully, and b) it printed out the value of `RBENV_SHELL` (which should be set when `rbenv init -` is run):

```
run ./myscript.sh
assert_success "sh"
```

### Heredocs

We've seen the `cat` command before, but it wasn't used in the way we're seeing here.  The `cat > myscript.sh` bit means we're printing to a new file that we're creating, called `myscript.sh`.  The `<<OUT` syntax, along with everything below it until the closing `OUT` statement, is called a Here document, or [heredoc](https://web.archive.org/web/20230405230515/https://linuxize.com/post/bash-heredoc/){:target="_blank" rel="noopener"} for short.  It's used to pass multiple lines of text to a command (in this case, the `cat` command).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "skip shell completions (fish)" {
  root="$(cd $BATS_TEST_DIRNAME/.. && pwd)"
  run rbenv-init - fish
  assert_success
  local line="$(grep '^source' <<<"$output")"
  [ -z "$line" ] || flunk "did not expect line: $line"
}
```

We store a directory path in a variable named `root`, quite similar to a previous test.  I actually think this is a copy-paste mistake, because `root` is not subsequently used anywhere in the test.  We'll ignore it for now.  Making a PR to remove it is left as an exercise for the reader. 😉

We then run `rbenv init`, passing `fish` as our shell.

We first assert that the command succeeded.  We then search the lines of output (which `bats` stores for us in a variable named `$output`) for the string `source`.  We store any matches we find in a variable named `line`.  We then assert that this variable is empty (i.e. we found 0 matches), and we fail the test if any such lines were found.

The test implies that, if any of our output contains `source` when we pass `fish` as our preferred shell, an error has occurred somewhere.  This makes sense, given that:

 - the test description is `skip shell completions (fish)`, and
 - we saw in a previous test that shell completions are enabled by `source`ing a script in the `completions/` folder.

This test ensures that there is no `fish` shell equivalent for the block of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L97-L100){:target="_blank" rel="noopener"}, which handles shell completions for all other shell programs.

### Here strings

In the declaration of the local variable `line`, we see `<<<"$output"`.  This is similar to the `<<OUT` syntax that we saw in the last test, except in the current test we're passing a string variable instead of a multi-line block of text.  Strings that use the `<<<` syntax are called here strings.  Unlike heredocs (which use the `<<` syntax), they do not require a delimiter (such as `OUT`, from the last test).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "posix shell instructions" {
  run rbenv-init bash
  assert [ "$status" -eq 1 ]
  assert_line 'eval "$(rbenv init - bash)"'
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L77){:target="_blank" rel="noopener"}, as well as [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L83){:target="_blank" rel="noopener"}.

We specify `bash` as the shell type for `rbenv-init` and run it.  Importantly, when running `run rbenv-init bash`, we leave out the `-` argument.

Doing so means that we end up inside the `if` code of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L46){:target="_blank" rel="noopener"}.  The purpose of this `if` block is to tell the user how to enable shell integration, i.e.:

 - what code to paste into their config file, and
 - where that config file lives.

We assert that one of the lines of text printed to STDOUT contains the command that we need to add to our shell profile, i.e. `eval "$(rbenv init - bash)"`.

We also assert that the exit code returned by `rbenv-init` was a non-zero code, indicating that the printing of these instructions is considered a non-happy-path use case.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "fish instructions" {
  run rbenv-init fish
  assert [ "$status" -eq 1 ]
  assert_line 'status --is-interactive; and rbenv init - fish | source'
}
```

This is a similar test to the previous one, except here we pass the argument `fish` instead of `bash`.  We once again assert that the command exited with a status code of 1, and that the proper shell integration script is printed to STDOUT.  This time, the script syntax is `fish`-specific, rather than `bash`-specific.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "option to skip rehash" {
  run rbenv-init - --no-rehash
  assert_success
  refute_line "rbenv rehash 2>/dev/null"
}
```

This test appears to cover [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L28){:target="_blank" rel="noopener"}, as well as [this block](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L104){:target="_blank" rel="noopener"}.  We run the `init` command, passing the "-" and "--no-rehash" flags.  We assert that:

 - the command exited successfully, and
 - that the code to rehash RBENV's shims (`"rbenv rehash 2>/dev/null"`) does *not* get printed to STDOUT.

Observant readers will notice that this test covers the opposite scenario covered by [this earlier test](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/init.bats#L14){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "adds shims to PATH" {
  export PATH="${BATS_TEST_DIRNAME}/../libexec:/usr/bin:/bin:/usr/local/bin"
  run rbenv-init - bash
  assert_success
  assert_line 0 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L94){:target="_blank" rel="noopener"}.  We set `$PATH` to a known value, then run `init` with the arguments "-" and "bash".  We assert that:

 - the test was successful, and that
 - the path was prepended with `{RBENV_ROOT}'/shims`.

We'll talk about why shims are added to `PATH` when we look at `rbenv-init`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "adds shims to PATH (fish)" {
  export PATH="${BATS_TEST_DIRNAME}/../libexec:/usr/bin:/bin:/usr/local/bin"
  run rbenv-init - fish
  assert_success
  assert_line 0 "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
}
```

This is a similar test to the previous one, except that it passes `fish` as an argument instead of `bash`.  The line of code that's tested is [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L90){:target="_blank" rel="noopener"}.  We perform the same setup, and we make the same assertions:

 - the command completed successfully, and
 - the `PATH` env var is re-exported to include `{RBENV_ROOT}'/shims` before its original value.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "can add shims to PATH more than once" {
  export PATH="${RBENV_ROOT}/shims:$PATH"
  run rbenv-init - bash
  assert_success
  assert_line 0 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
}
```

This test asserts that, when the value of `PATH` already includes RBENV's `shims/` directory, a subsequent call to `rbenv init` results in `PATH` being prepended with additional copies of the `shims/` directory:

 - We set `PATH` to include `shims/`.
 - We run `rbenv init` with the arguments "-" and "bash".
 - Finally, we assert that:
   - the test is successful, and
   - the new value of `PATH` to be exported includes the original value (with `shims/`), plus a duplicate value of the `shims/` path at the front of the env var.

I was curious why we'd explicitly want to ensure that duplication within `PATH` is acceptable.  I would have thought that we'd want to actively *prevent* such duplication, since it makes `PATH` harder to read and debug.

As it turns out, this test appears to cover a problem presented by some of RBENV's users [here](https://github.com/rbenv/rbenv/issues/369){:target="_blank" rel="noopener"}.  When certain users attempted to run the `tmux` command, their version of Ruby was changed unintentionally.  According to RBENV's core team, the reason for this was as follows:

> Your problem is due to $PATH ordering... Your PATH in your regular terminal session is something like:
>
> ```
>rbenv shims : rbenv bin : system paths
> ```
>
> By entering tmux, you spawned a nested interactive subshell. That means that your .bashrc or .zshrc get sourced again, and the same paths get added to the already prepared PATH. You finish up with something like:
>
> `rbenv bin : system paths : rbenv shims : rbenv bin : system paths`
>
> The master branch of rbenv avoids adding shims to the PATH twice. So you finished with ruby from system paths (/usr/bin/ruby) having precedence over rbenv's shims (~/.rbenv/shims/ruby).

So by running `tmux`, the shell configuration files `.bashrc` or `.zshrc` get `source`'ed a 2nd time.

In the case of these users, this action caused `$PATH` to be prepended with a duplicate copy of the path to "system" Ruby.  Since the same config files presumably contained the `rbenv init` command, this normally would have caused `$PATH` to be prepended with a duplicate of the path to RBENV Ruby versions as well.

However, at the time of this bug, RBENV included a line of logic which prevented duplicate copies of the paths to its Ruby versions from being added to `$PATH`.  This was meant to avoid polluting `$PATH` with duplicate directory paths, for the reasons I mentioned earlier.

By including this logic to prevent duplication, RBENV inadvertently contributed to the existence of this unexpected behavior for `tmux` users.  The core team appears to have decided that the best of several less-than-ideal solutions was to allow the `$PATH` duplication after all, since the existing logic was causing problems for too many users.  The PR to "revert back to simpler times" is located [here](https://github.com/rbenv/rbenv/commit/e2173df4aa91c8d365ca1596fb857fcac9fdd787){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "can add shims to PATH more than once (fish)" {
  export PATH="${RBENV_ROOT}/shims:$PATH"
  run rbenv-init - fish
  assert_success
  assert_line 0 "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
}
```

This test covers the same edge case as the previous test, but for the `fish` shell instead of the `bash` shell.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "outputs sh-compatible syntax" {
  run rbenv-init - bash
  assert_success
  assert_line '  case "$command" in'

  run rbenv-init - zsh
  assert_success
  assert_line '  case "$command" in'
}
```

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147){:target="_blank" rel="noopener"}.  It asserts that, when we run `rbenv init` for both the `bash` and `zsh` shells, the shell function that `rbenv init` checks whether the user's command is related to shell integration (i.e. it's either `rbenv shell` or `rbenv rehash`).

These are the two commands that will be included in the `commands[*]` array, the line directly below the line `case "$command" in` which begins the case statement.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Last test:

```
@test "outputs fish-specific syntax (fish)" {
  run rbenv-init - fish
  assert_success
  assert_line '  switch "$command"'
  refute_line '  case "$command" in'
}
```

This test covers the blocks of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L116){:target="_blank" rel="noopener"} and [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L139){:target="_blank" rel="noopener"}.  It covers the same behavior, but for `fish` (as opposed to the `bash` and `zsh` shells, which the previous test covered).  The `fish` shell uses much different syntax from `bash` or `zsh`, so we need separate tests to cover that edge case.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's move on to the code.
