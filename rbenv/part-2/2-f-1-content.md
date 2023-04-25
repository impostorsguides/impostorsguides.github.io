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

Given what we know about the BATS library's API and the helper methods exposed by the `test_helper` file, this test is relatively easy to read.  We first perform some sanity-check assertions stating that the `${RBENV_ROOT}/shims` and `${RBENV_ROOT}/versions` directories do not exist.  We then run the command with the `-` flag ([if this flag is missing](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L46){:target="_blank" rel="noopener"}, then `rbenv init` prints out usage instructions and [exits with a failure return code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L83){:target="_blank" rel="noopener"}, which we'll see in the next section).  Lastly, we assert that the command ran successfully and that the two formerly-missing directories have been created.

I was curious why the default behavior (i.e. the behavior when no "-" flag is passed) is to exit with a non-success return code.  I looked up [the commit which introduced this flag](https://github.com/rbenv/rbenv/commit/4ee92fca43805a3d4a04f453e79a06e85b9810e9){:target="_blank" rel="noopener"}, however unfortunately it was added by the original author back when he was likely the only person maintaining the repo, and he didn't include an issue or a PR description other than the commit message itself.  This commit message doesn't reveal the author's intention, so it's anyone's guess as to why the change was introduced.

Next test:

```
@test "auto rehash" {
  run rbenv-init -
  assert_success
  assert_line "command rbenv rehash 2>/dev/null"
}
```

(stopping here for the day; 91710 words)

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L104){:target="_blank" rel="noopener"}.  If the value of a variable named `no_rehash` hasn't been set by the time we reach this block, then we print the string 'command rbenv rehash 2>/dev/null' to STDOUT.  This string looks like a command that you might type into your terminal, and in fact it is.  This particular command, `rbenv rehash`, is a command we'll get into down the road, but for now suffice it to say that "rehashing" means generating a new instance of the shim file that RBENV inserts between the user and the gem they're trying to run when they type a certain command.  Fun fact- when you try to run a program that's installed via "gem install", you're really running an RBENV file called a "shim" which tells RBENV to run that program for you, using your currently-installed Ruby version.  Shims are a big part of how RBENV does its job of cleanly managing your Ruby version.

When we start analyzing the command file, we'll see that these commands which are printed to STDOUT are actually captured by something called [command substitution](https://web.archive.org/web/20221010044921/https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html){:target="_blank" rel="noopener"}, and executed by `bash`.  So when we see an assertion that expects a certain string to be printed, and when that string looks like shell code, that's what's happening.

Note that at the time of this writing, I'm still not sure why we print stringified versions of the commands to STDOUT, to be later evaluated by command substitution.  I suspect the same goal could have been accomplished by:

having a file for each supported shell type containing the actual code to execute when the user types `rbenv` (as opposed to the stringified version of that code),
detecting which shell program the user is using, and
executing the right file for the user's shell type

Of course, I can't *prove* that this 2nd approach would work without re-writing RBENV the way I envision.  That could be a super-useful learning exercise to see if I could get it to work, but it would also be a huge time commitment and one that I don't think I can manage now.  I don't doubt that the core team had great reasons for writing the library the way they did, it's just that those reasons aren't immediately obvious to me right now.  It may be a question that I have to punt on until later.

Next test:

```
@test "setup shell completions" {
  root="$(cd $BATS_TEST_DIRNAME/.. && pwd)"
  run rbenv-init - bash
  assert_success
  assert_line "source '${root}/test/../libexec/../completions/rbenv.bash'"
}
```

This test covers the 4-line block of code starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L97){:target="_blank" rel="noopener"}.  We store the value of our root directory, and run `rbenv-init` while specifying `bash` as our shell.  We assert that the command completed successfully and that the line which `source`s the completion file is `echo`ed to the screen.  The completion files were some of the first files we covered in this document.

Next test:

```
@test "detect parent shell" {
  SHELL=/bin/false run rbenv-init -
  assert_success
  assert_line "export RBENV_SHELL=bash"
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L36){:target="_blank" rel="noopener"} and the lines after it.  We purposely set the `SHELL` env var to be a falsy value, and run the command with no argument after the "-" character.  Because of these facts, initially the `$shell` variable inside our script is empty.  But after the relevant line of code, we've detected that our parent shell is `bash`, and we use that as the value for `$shell` from then on.  We can see this by adding a bunch of `echo` statements to this block of code, like so:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-725am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I run the test, and print out `foo.txt`, I get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-726am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Once the correct shell program has been detected and stored in a string, our script just whittles the string down until it has just the shell program's name.  Once we have just the name, we can construct our shell function to suit the user's shell type.

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

We create and navigate into a test directory, and in that directory we create a test script which contains an `sh` shebang and a call to `eval` RBENV's `init` command with no explicit shell set.  Lastly, it prints out the value of `RBENV_SHELL` (which should be set when `rbenv init -` is run).  We make the script executable and run it, and assert that `sh` was indeed printed to the screen.

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

We store a directory path in a variable named `root`, quite similar to a previous test.  I actually think this is a copy-paste mistake, because `root` is not subsequently used anywhere in the test.  We'll ignore it for now.

We run `rbenv init`, passing `fish` as the explicit shell.  We first assert that the command succeeded.  We then search the lines of output (which `bats` stores for us in a variable named `$output`) for the string `source`.  We store any matches we find in a variable named `line`.  We then assert that this variable is empty, and we fail the test if it is not.

Next test:

```
@test "posix shell instructions" {
  run rbenv-init bash
  assert [ "$status" -eq 1 ]
  assert_line 'eval "$(rbenv init - bash)"'
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L77){:target="_blank" rel="noopener"}, as well as [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L83){:target="_blank" rel="noopener"}.  We specify `bash` as the shell type for `rbenv-init` and run it.  Because we didn't specify the "-" before the shell type, we find ourselves inside the `if` code of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L46){:target="_blank" rel="noopener"}.  We assert that one of the lines of text printed to STDOUT contains the command that we need to add to our shell profile in order to enable shell integration (i.e. the `eval` command *with* the "-" hyphen included).

Next test:

```
@test "fish instructions" {
  run rbenv-init fish
  assert [ "$status" -eq 1 ]
  assert_line 'status --is-interactive; and rbenv init - fish | source'
}
```

(stopping here for the day; 92723 words)

This is a similar test to the previous one, except here we pass the argument "fish" instead of "bash".  We once again assert that the command exited with a status code of 1, and that the proper shell integration script is printed to STDOUT.  This time, the script syntax is "fish"-specific, rather than "bash"-specific.

Next test:

```
@test "option to skip rehash" {
  run rbenv-init - --no-rehash
  assert_success
  refute_line "rbenv rehash 2>/dev/null"
}
```

This test appears to test [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L28){:target="_blank" rel="noopener"}, as well as [this block](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L104){:target="_blank" rel="noopener"}.  We run the `init` command, passing the "-" and "--no-rehash" flags.  We assert that a) the test was successful, and b) that the code to rehash RBENV's shims (`"rbenv rehash 2>/dev/null"`) does *not* get printed to STDOUT.

Next test:

```
@test "adds shims to PATH" {
  export PATH="${BATS_TEST_DIRNAME}/../libexec:/usr/bin:/bin:/usr/local/bin"
  run rbenv-init - bash
  assert_success
  assert_line 0 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L94){:target="_blank" rel="noopener"}.  We set `$PATH` to a known value, then run `init` with the arguments "-" and "bash".  We assert that the test was successful, and that the path was prepended with `{RBENV_ROOT}'/shims`.

Next test:

```
@test "adds shims to PATH (fish)" {
  export PATH="${BATS_TEST_DIRNAME}/../libexec:/usr/bin:/bin:/usr/local/bin"
  run rbenv-init - fish
  assert_success
  assert_line 0 "set -gx PATH '${RBENV_ROOT}/shims' \$PATH"
}
```

This is a similar test to the previous one, except that it passes "fish" as an argument instead of "bash" (the line of code that's tested is [this one](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L90){:target="_blank" rel="noopener"}).  We perform the same setup, and as before the assertion tests that the `PATH` env var is re-exported to include `{RBENV_ROOT}'/shims` before its original value.

Next test:

```
@test "can add shims to PATH more than once" {
  export PATH="${RBENV_ROOT}/shims:$PATH"
  run rbenv-init - bash
  assert_success
  assert_line 0 'export PATH="'${RBENV_ROOT}'/shims:${PATH}"'
}
```

This test asserts that, when the value of `PATH` already includes RBENV's `shims/` directory, a subsequent call to "rbenv init" results in `PATH` being prepended with additional copies of the `shims/` directory.  We set `PATH` to include `shims/`, run `rbenv init` with the arguments "-" and "bash", assert that the test is successful, and assert that the new value of `PATH` to be exported includes the original value (with `shims/`), plus a duplicate value of the `shims/` path at the front of the env var.

I was curious why we'd explicitly want to ensure that duplication within `PATH` is acceptable.  I would have thought that we'd want to actively *prevent* such duplication, since it makes `PATH` harder to read and debug.

As it turns out, this test appears to cover a problem presented by some of RBENV's users [here](https://github.com/rbenv/rbenv/issues/369){:target="_blank" rel="noopener"}.  When certain users attempted to run the `tmux` command, their version of Ruby was changed unintentionally.  According to RBENV's core team, the reason for this was as follows:

<p style="text-align: center">
  <img src="/assets/images/screenshot-13mar2023-729am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So by running `tmux`, the shell configuration files `.bashrc` or `.zshrc` get `source`'ed a 2nd time.  In the case of these users, this action caused `$PATH` to be prepended with a duplicate copy of the path to "system" Ruby.  Since the same config files presumably contained the `rbenv init` command, this normally would have caused `$PATH` to be prepended with a duplicate of the path to RBENV Ruby versions as well.

However, at the time of this bug, RBENV included a line of logic which prevented duplicate copies of the paths to its Ruby versions from being added to `$PATH`.  This was meant to avoid polluting `$PATH` with duplicate directory paths, for the reasons I mentioned earlier.

By including this logic to prevent duplication, RBENV inadvertently contributed to the existence of this unexpected behavior for `tmux` users.  The core team appears to have decided that the best of several less-than-ideal solutions was to allow the `$PATH` duplication after all, since the existing logic was causing problems for too many users.  The PR to "revert back to simpler times" is located [here](https://github.com/rbenv/rbenv/commit/e2173df4aa91c8d365ca1596fb857fcac9fdd787){:target="_blank" rel="noopener"}.

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

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147){:target="_blank" rel="noopener"}.  It asserts that, when we run `rbenv init` for both the `bash` and `zsh` shells, the shell function that `rbenv init` helps create includes a certain `case` statement which determines which RBENV file to execute based on which RBENV command the user typed.

Last test:

```
@test "outputs fish-specific syntax (fish)" {
  run rbenv-init - fish
  assert_success
  assert_line '  switch "$command"'
  refute_line '  case "$command" in'
}
```

This test covers the blocks of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L116){:target="_blank" rel="noopener"} and [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L139){:target="_blank" rel="noopener"}, and covers the alternate path to the previous test.  When the user invokes `rbenv init` with `fish` as the shell argument instead of `bash` or `zsh`, we need very different syntax for our shell function.

Now that the tests are done, let's look at the code:
