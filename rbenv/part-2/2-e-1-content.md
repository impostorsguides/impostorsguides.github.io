Before reading the code for each command, we'll start by looking at the command's tests.  In the spirit of ["tests as executable documentation"](https://web.archive.org/web/20230321145910/https://subscription.packtpub.com/book/application-development/9781788836111/1/ch01lvl1sec13/executable-documentation){:target="_blank" rel="noopener"}, reading the tests first should give us a sense of what the expected behavior is.  The headers for the `Tests` and `Code` section are also links to the code we'll be looking at.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/rbenv.bats){:target="_blank" rel="noopener"}

The first line of code is:

```
#!/usr/bin/env bats
```

This is a shebang, but it's not a `bash` shebang.  Instead, it's a `bats` shebang.  [`bats` is a test-runner program](https://github.com/sstephenson/bats){:target="_blank" rel="noopener"} that Sam Stephenson (the original author of RBENV) wrote, and it's used here as RBENV's test framework.  But it's not RBENV-specific; you could technically use it to test any shell script.

### Experiment: running the BATS tests

To run these tests, we'll need to install `bats` first.  The installation instructions are [here](https://github.com/sstephenson/bats#installing-bats-from-source){:target="_blank" rel="noopener"}.  Once that's done, we can navigate to the home directory of our cloned RBENV codebase, and run the following:

```
$ bats ./test/rbenv.bats

 ✓ blank invocation
 ✓ invalid command
 ✓ default RBENV_ROOT
 ✓ inherited RBENV_ROOT
 ✓ default RBENV_DIR
 ✓ inherited RBENV_DIR
 ✓ invalid RBENV_DIR
 ✓ adds its own libexec to PATH
 ✓ adds plugin bin dirs to PATH
 ✓ RBENV_HOOK_PATH preserves value from environment
 ✓ RBENV_HOOK_PATH includes rbenv built-in plugins

11 tests, 0 failures

$
```

They all pass, as we'd expect.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
load test_helper
```

This `load` method comes from [this line of code](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L32){:target="_blank" rel="noopener"} in `bats`.  Here we're loading a helper file called `test_helper`, which lives [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash){:target="_blank" rel="noopener"}.

Loading `test_helper` does lots of things for us that help our tests run as expected, such as:

- [updating the value of `PATH`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L22){:target="_blank" rel="noopener"} to include the `rbenv` commands that we want to test,
- `export`ing the environment variables that we'll need, [such as `RBENV_ROOT`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L18){:target="_blank" rel="noopener"}
- [giving us access to helper functions](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L45){:target="_blank" rel="noopener"} that let us run those commands and assert that the results succeeded or failed.

The next block of code is also our first test:

```
@test "blank invocation" {
  run rbenv
  assert_failure
  assert_line 0 "$(rbenv---version)"
}
```

### Annotations and Regexes

The first thing I notice is the `@test` snippet.  I'm not sure what Sam Stephenson would call this, but I would call it an "annotation", because I have a bit of experience with the Java language and the Java community [uses similar syntax](https://web.archive.org/web/20230309020001/https://en.wikipedia.org/wiki/Java_annotation){:target="_blank" rel="noopener"}, which they also refer to as annotations.

Annotations are used as metadata, to help BATS identify which code represents tests that should be run.  If we search the BATS codebase for the string `@test` and look through the results, eventually we find [this line of code](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-preprocess#L34){:target="_blank" rel="noopener"}.  This is a regular expression (or a regex for short).  If you aren't familiar with regexes, they're a very powerful tool for finding and parsing strings.  See [here](https://web.archive.org/web/20221024181745/https://linuxtechlab.com/bash-scripting-learn-use-regex-basics/){:target="_blank" rel="noopener"} for more information.

This isn't a walk-through of the BATS codebase so I want to keep this part short, but essentially what's happening here is we're providing a pattern for `bash` to use when searching for lines of code.  `bash` will read each line of code in a test file (for example, `test/rbenv.bats`) and see if it matches the pattern.  If it does, we know we've found a test.  The pattern includes the string `@test`, which is why each of the tests in our file start with `@test`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Back to our test block.  Here we're verifying that an attempt to run `rbenv` without any arguments will fail:

 - We use `test_helper`'s [`run` command](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L50){:target="_blank" rel="noopener"} to execute the `rbenv` command without any arguments or flags.
 - Then we call `test_helper`'s `assert_failure` function, which checks to make sure the last command which was run (i.e. `run rbenv`) had a non-zero exit code.
 - If this is true (i.e. if something went wrong), the test passes.  If not, the test fails.

I would call this a "sad-path test".  When testing our code, we not only want to test what happens when things go right (i.e. the "happy-path"), but also what happens when things go wrong.  This gives us confidence that our code will work as expected in all scenarios, not just the good ones.

Running the command `rbenv` by itself, with no arguments, is considered a "sad-path" because the `rbenv` command needs you to pass it the name of another command, before it can do anything.  For example, if you give it the `versions` command by running `rbenv version`, RBENV knows that you want to see a list of all the Ruby versions which are installed on your system.  But by itself, the `rbenv` command does nothing.  Therefore, running `rbenv` by itself would be considered a user error.

There is also a 2nd assertion below the first one:

```
  assert_line 0 "$(rbenv---version)"
```

This line states that the 1st line of the printed output (the indexing here is 0-based) should be equal to the output of the `rbenv --version` command.  So when the user runs `rbenv` without any arguments, the first line of printed output they should see is the version number for their RBENV installation.  I try this on my machine, and it works as expected:

```
$ rbenv
rbenv 1.2.0-16-gc4395e5
Usage: rbenv <command> [<args>]

Some useful rbenv commands are:
   commands    List all available rbenv commands
   local       Set or show the local application-specific Ruby version
   global      Set or show the global Ruby version
   shell       Set or show the shell-specific Ruby version
   install     Install a Ruby version using ruby-build
   uninstall   Uninstall a specific Ruby version
   rehash      Rehash rbenv shims (run this after installing executables)
   version     Show the current Ruby version and its origin
   versions    List installed Ruby versions
   which       Display the full path to an executable
   whence      List all Ruby versions that contain the given executable

See `rbenv help <command>' for information on a specific command.
For full documentation, see: https://github.com/rbenv/rbenv#readme
```

Here we can see that the first line of printed output is `rbenv 1.2.0-16-gc4395e5`.

### Experiment: writing our own BATS test

I create a file called `foo.bats` inside the same `test/` folder as `rbenv.bats`, with the following content:

```
#!/usr/bin/env bats

@test "testing out the bats commands" {
  run echo "Hello world"
  assert_success
}
```

When I try to run it with the `bats` command, I get:

```
$ bats foo.bats
 ✗ testing out the bats commands
   (in test file foo.bats, line 5)
     `assert_success' failed with status 127
   /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/bats.84975.src: line 5: assert_success: command not found

1 test, 1 failure
```

Hmm I'm missing the `assert_success` command, which I know exists because we can see it further down in `tests/rbenv.bats`.  Where is that method in the codebase?

I search the `bats` Github repo, thinking it would be there, but it's not.  I then search the RBENV repo, and I find it [here](https://github.com/rbenv/rbenv/blob/117a38157537eeb59d73bf8a958363688fdf6383/test/test_helper.bash){:target="_blank" rel="noopener"}, inside `test_helper.bash`.

OK, so we need to load `test_helper`, just like the other tests do.  I update the test file to look like the following:

```
#!/usr/bin/env bats

load test_helper

@test "testing out the bats commands" {
  run echo "Hello world"
  assert_success
}
```

I then run it again:

```
$ bats ./foo.bats
 ✓ testing out the bats commands

1 test, 0 failures
```

Now, I want to purposely generate a failure, but not the kind we just saw (i.e. a failure caused by a failure to import a dependency).  Instead, I want it to fail because the test completed, but the result wasn't what we expect.  I change `assert_success` in my test to `assert_failure` and re-run it:

```
$ bats ./foo.bats
 ✗ testing out the bats commands
   (from function `flunk' in file test_helper.bash, line 42,
    from function `assert_failure' in file test_helper.bash, line 55,
    in test file foo.bats, line 7)
     `assert_failure' failed
   expected failed exit status

1 test, 1 failure
```

Now we see a `✗` character instead of a `✓` character next to the test description.  We also see which assertion failed:

```
`assert_failure' failed
```

Lastly, we see `expected failed exit status`, which tells us why `assert_failure` failed.

Great, that's a (very preliminary) introduction to writing our own BATS test.  We'll see lots more BATS syntax in the subsequent tests.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "invalid command" {
  run rbenv does-not-exist
  assert_failure
  assert_output "rbenv: no such command \`does-not-exist'"
}
```

This test covers the sad-path case of when a user tries to run an RBENV command that doesn't exist.  We do the following:

- run a fake RBENV command called `rbenv does-not-exist`,
- call our `assert_failure` helper function to ensure that the previous command failed, and
- check that the output which was printed to STDOUT contained the line "rbenv: no such command \`does-not-exist'".

I try this on my machine as well:

```
$ rbenv foo
rbenv: no such command `foo'
```

Looks good!

One question, though- what's the difference between `assert_output` and `assert_line 0`?  Could we have replaced the `assert_line 0` in our previous test with `assert_output`?

### Experiment- replacing `assert_line 0` with `assert_output`

I try it out, making the above-mentioned replacement in test #1:

```
@test "blank invocation" {
  run rbenv
  assert_failure
  assert_output "$(rbenv---version)"
}
```

When I run this, I get the following:

```
$ bats test/rbenv.bats

 ✗ blank invocation
   (from function `assert_equal' in file test/test_helper.bash, line 65,
    from function `assert_output' in file test/test_helper.bash, line 74,
    in test file test/rbenv.bats, line 8)
     `assert_output "$(rbenv---version)"' failed
   expected: rbenv 1.2.0-16-gc4395e5
   actual:   rbenv 1.2.0-16-gc4395e5
   Usage: rbenv <command> [<args>]

   Some useful rbenv commands are:
      commands    List all available rbenv commands
      local       Set or show the local application-specific Ruby version
      global      Set or show the global Ruby version
      shell       Set or show the shell-specific Ruby version
      install     Install a Ruby version using ruby-build
      uninstall   Uninstall a specific Ruby version
      rehash      Rehash rbenv shims (run this after installing executables)
      version     Show the current Ruby version and its origin
      versions    List installed Ruby versions
      which       Display the full path to an executable
      whence      List all Ruby versions that contain the given executable

   See `rbenv help <command>' for information on a specific command.
   For full documentation, see: https://github.com/rbenv/rbenv#readme
```

OK, so it failed because we expected `rbenv 1.2.0-16-gc4395e5` to be the only output for that command (which is what `assert_output` apparently means).  But it wasn't; in addition to the string from the expeted output, the actual output included things like:

- usage instructions for the command,
- some common rbenv commands,
- a link to the docs, etc.

So our experiment taught us that these two BATS helpers are not, in fact, interchangeable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test is:

```
@test "default RBENV_ROOT" {
  RBENV_ROOT="" HOME=/home/mislav run rbenv root
  assert_success
  assert_output "/home/mislav/.rbenv"
}
```

At first I thought it was strange that we're including a call to the `root` command inside the test file for the `rbenv` command.  I would have expected the test file for `rbenv` to only include calls to `rbenv`, not to other commands as well.  Otherwise, if such a test fails, it could be because of a failure in that other command, as opposed to in the `rbenv` command.

After giving this some thought, I suspect it's because:
 - we want to test how `rbenv` responds to a known-valid command (unlike the previous test, which tested a known-invalid command), and
 - this command's implementation is only a single line of code, so it allows us to accomplish this goal with minimal added complexity.

I skipped ahead a bit because I was curious where `RBENV_ROOT` and `HOME` are used.  Judging by the environment variables which are passed to the `run rbenv root` command, this test appears to cover the behavior beginning at [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54){:target="_blank" rel="noopener"}.

The test does the following:

- passes an empty value for `RBENV_ROOT` and an arbitrary but unsurprising value for `HOME` as environment variables, and
- asserts that:
  - the command succeeded, and
  - that the printed output included the `.rbenv/` directory, prepended with the value we set for `HOME`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "inherited RBENV_ROOT" {
  RBENV_ROOT=/opt/rbenv run rbenv root
  assert_success
  assert_output "/opt/rbenv"
}
```

This test is similar to the previous test, except this time we set a non-empty value for `RBENV_ROOT` and assert that that value is used as the output for the `root` command.  We leave `HOME` blank because `HOME` is only needed to help construct `RBENV_ROOT` if `RBENV_ROOT` doesn't already exist, again according to [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "default RBENV_DIR" {
  run rbenv echo RBENV_DIR
  assert_output "$(pwd)"
}
```

Here we appear to be testing [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61){:target="_blank" rel="noopener"}.  We assert that, if no prior value has been set for `RBENV_DIR`, we set it equal to the value of the shell's `PWD` environment variable (which is also the same as the output of the `pwd` shell command, which is what "$(pwd)" resolves to here).

Note that we won't be able to run `rbenv echo` in our shell unless we manually update our `PATH` environment variable to include RBENV's `test/libexec/` directory.  The `test_helper` file does this for us when we run our test, but if we're not running a test then we have to do this ourselves.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "inherited RBENV_DIR" {
  dir="${BATS_TMPDIR}/myproject"
  mkdir -p "$dir"
  RBENV_DIR="$dir" run rbenv echo RBENV_DIR
  assert_output "$dir"
}
```

This test covers the same block of code as the previous test, except this time we're testing the `else` branch instead of the `if` branch:

- We create a variable named `dir` and set it equal to `BATS_TMPDIR` with "/myproject" appended to the end.
  - The value of the `BATS_TMPDIR` env var is set [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L305){:target="_blank" rel="noopener"} if it's not already set.
  - More info on `BATS_TMPDIR` and other BATS-specific environment variables can be found [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/README.md#special-variables){:target="_blank" rel="noopener"}.
- We then create a directory whose name is the value of our `dir` variable.
- We set the `RBENV_DIR` env var equal to this directory.
- We then run `rbenv echo RBENV_DIR`.
- Lastly, we assert that the command printed the value that we specified for the `RBENV_DIR` env var, since that's the env var that we passed to `rbenv echo`.
  - In other words, we assert that [the block of code that we're testing](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61){:target="_blank" rel="noopener"} didn't modify the value of `RBENV_DIR` in any way.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "invalid RBENV_DIR" {
  dir="${BATS_TMPDIR}/does-not-exist"
  assert [ ! -d "$dir" ]
  RBENV_DIR="$dir" run rbenv echo RBENV_DIR
  assert_failure
  assert_output "rbenv: cannot change working directory to \`$dir'"
}
```

Here we're testing the same [block of logic](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61){:target="_blank" rel="noopener"} as the last test, but this time we're testing a different edge case.

Inside that block's `else` branch, we try to `cd` into the directory specified by `RBENV_DIR`.  As of this point, the value of `RBENV_DIR` is not known to be a valid directory, so this may or may not work.

If it *does* work, [we reset `RBENV_DIR`](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv#L35){:target="_blank" rel="noopener"} to be equal to our current directory.  But if it fails, we abort and print the error message `rbenv: cannot change working directory to '$dir'`.  That's the edge case we're testing- when the navigation into the specified directory fails, the command fails and the expected error message is printed to STDERR.

Why do we reset `RBENV_DIR`?  My guess is that this is to ensure the value of `RBENV_DIR` is formatted in a readable manner.  For example, let's see what happens if I call the `rbenv` command and pass in `RBENV_DIR=..` in the command line.  I add a few `echo` statements to the code:

```
...
if [ -z "${RBENV_DIR}" ]; then
  RBENV_DIR="$PWD"
else
  echo "RBENV_DIR 1: $RBENV_DIR" >> /Users/myusername/Workspace/OpenSource/rbenv/test/log4tests

  [[ $RBENV_DIR == /* ]] || RBENV_DIR="$PWD/$RBENV_DIR"

  echo "RBENV_DIR 2: $RBENV_DIR" >> /Users/myusername/Workspace/OpenSource/rbenv/test/log4tests

  cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"

  RBENV_DIR="$PWD"

  echo "RBENV_DIR 3: $RBENV_DIR" >> /Users/myusername/Workspace/OpenSource/rbenv/test/log4tests

  cd "$OLDPWD"
fi
...
```

I added 3 loglines above (the ones containing `RBENV_DIR 1`, `RBENV_DIR 2`, and `RBENV_DIR 3`), so we can see what the value of `RBENV_DIR` is after each line of code.  Notice the line `RBENV_DIR="$PWD"` is *not* commented-out yet.

I then write the following test:

```
#!/usr/bin/env bats

load test_helper

@test "attempt to run foo" {
  RBENV_DIR=".." run rbenv echo RBENV_DIR
  assert_success
}
```

When I run this test and view the `log4tests` file, I see:

```
RBENV_DIR 1: ..
RBENV_DIR 2: /Users/myusername/Workspace/OpenSource/rbenv/test/..
RBENV_DIR 3: /Users/myusername/Workspace/OpenSource/rbenv
```

Next, when I comment out `RBENV_DIR="$PWD"` and re-run the test, I see the following in `log4tests`:

```
RBENV_DIR 1: ..
RBENV_DIR 2: /Users/myusername/Workspace/OpenSource/rbenv/test/..
RBENV_DIR 3: /Users/myusername/Workspace/OpenSource/rbenv/test/..
```

The paths `/Users/myusername/Workspace/OpenSource/rbenv/test/..` and `/Users/myusername/Workspace/OpenSource/rbenv` both refer to the same location in the directory structure, even though they look different, since the `test/` and `..` from the first path cancel each other out.  The command `RBENV_DIR="$PWD"` simply ensures that `RBENV_DIR` stores the 2nd, more readable path.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "adds its own libexec to PATH" {
  run rbenv echo "PATH"
  assert_success "${BATS_TEST_DIRNAME%/*}/libexec:$PATH"
}
```

After some digging, I discovered that  this test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79){:target="_blank" rel="noopener"}.  I ran the test with this line of code in-place, and then re-ran it with the code commented-out, and the test failed when the line was commented out.  I consider that to be pretty solid proof that this is the line of code under test.

We will dive into what this line of code does when we get to the code itself, further down.  But from the description of this test (`adds its own libexec to PATH`), we can deduce that the `libexec/` folder contains commands that we'll want to execute from the terminal.  We know this because we learned from Part 1 that `PATH` is the list of folders which UNIX checks when we give it a command to execute.  Adding more folders to `PATH` (such as `libexec/`) means we'll have access to more commands.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test is:

```
@test "adds plugin bin dirs to PATH" {
  mkdir -p "$RBENV_ROOT"/plugins/ruby-build/bin
  mkdir -p "$RBENV_ROOT"/plugins/rbenv-each/bin
  run rbenv echo -F: "PATH"
  assert_success
  assert_line 0 "${BATS_TEST_DIRNAME%/*}/libexec"
  assert_line 1 "${RBENV_ROOT}/plugins/ruby-build/bin"
  assert_line 2 "${RBENV_ROOT}/plugins/rbenv-each/bin"
}
```

This test covers the 4-line block of code starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L76){:target="_blank" rel="noopener"}.  Inside the test, we create two directories, one named `ruby-build` and one named `rbenv-each`.  From the name of the directory ( `plugins/`), we can assume that this is where RBENV plugins are stored, so we can deduce that creating these two sub-directories means we're creating two RBENV plugins for the purposes of our test.  Since there's no additional setup (such as creating files inside of those directories), we can assume that's all we need to do in order to make our test think these plugins actually exist.

We then call `run rbenv echo -F: "PATH"`, which tells RBENV to `echo` `$PATH`.  We pass the `-F:` flag to tell `rbenv echo` to use ":" as a separator.  This will cause each item in `$PATH` to print on its own line.  We could have called `run rbenv echo "PATH"` without the `-F:` flag, but then our entire `PATH` will print on one line, which will make it really hard to call `assert_line 0` etc. further down in the code.

Lastly, we assert that the command was successful, and that the first item in `$PATH` is the value prepended to `$PATH` [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79){:target="_blank" rel="noopener"}, and that the next two items in `$PATH` are the paths to the two plugins that we "installed" when we ran `mkdir` twice at the start of our test.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "RBENV_HOOK_PATH preserves value from environment" {
  RBENV_HOOK_PATH=/my/hook/path:/other/hooks run rbenv echo -F: "RBENV_HOOK_PATH"
  assert_success
  assert_line 0 "/my/hook/path"
  assert_line 1 "/other/hooks"
  assert_line 2 "${RBENV_ROOT}/rbenv.d"
}
```

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81){:target="_blank" rel="noopener"}.  It takes any previously-set value of `RBENV_HOOK_PATH`, and adds `${RBENV_ROOT}/rbenv.d` to the end of that value.

To test this, we set the value of `RBENV_HOOK_PATH` so that it includes two hard-coded paths, `/my/hook/path` and `/other/hooks`.  We then run `rbenv echo` on this env var, again telling `rbenv echo` to use `:` as a separator via the `-F` flag.  We assert that the command was successful and that our two paths are printed, followed by `${RBENV_ROOT}/rbenv.d`.

We can increase our confidence that this test covers the above line of code by simply commenting out that line in the `rbenv` command, and seeing whether the test fails:

```
# RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

When I re-run the test, I get:

```
$ bats rbenv.bats
 ✓ blank invocation
 ✓ invalid command
 ✓ default RBENV_ROOT
 ✓ inherited RBENV_ROOT
 ✓ default RBENV_DIR
 ✓ inherited RBENV_DIR
 ✓ invalid RBENV_DIR
 ✓ adds its own libexec to PATH
 ✓ adds plugin bin dirs to PATH
 ✗ RBENV_HOOK_PATH preserves value from environment
   (from function `assert_equal' in file test_helper.bash, line 65,
    from function `assert_line' in file test_helper.bash, line 79,
    in test file rbenv.bats, line 69)
     `assert_line 2 "${RBENV_ROOT}/rbenv.d"' failed
   expected: TEST_DIR/root/rbenv.d
   actual:   /Users/myusername/Workspace/OpenSource/rbenv/rbenv.d
 ✗ RBENV_HOOK_PATH includes rbenv built-in plugins
   (from function `assert_equal' in file test_helper.bash, line 65,
    from function `assert_output' in file test_helper.bash, line 74,
    from function `assert_success' in file test_helper.bash, line 49,
    in test file rbenv.bats, line 75)
     `assert_success "${RBENV_ROOT}/rbenv.d:${BATS_TEST_DIRNAME%/*}/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"' failed
   expected: TEST_DIR/root/rbenv.d:/Users/myusername/Workspace/OpenSource/rbenv/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks
   actual:   /Users/myusername/Workspace/OpenSource/rbenv/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks

11 tests, 2 failures
```

The above 2 failures include the test we're currently examining as well as the next one, meaning that test also covers this same line of code.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Last test:

```
@test "RBENV_HOOK_PATH includes rbenv built-in plugins" {
  unset RBENV_HOOK_PATH
  run rbenv echo "RBENV_HOOK_PATH"
  assert_success "${RBENV_ROOT}/rbenv.d:${BATS_TEST_DIRNAME%/*}/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
}
```

Here we do the following:

 - unset `RBENV_HOOK_PATH`,
 - run the command,
 - assert that it was successful, and
 - assert that the printed output references the following directories, delimited by the ":" character:
    - `${RBENV_ROOT}/rbenv.d`
    - `${BATS_TEST_DIRNAME%/*}/rbenv.d`
    - `/usr/local/etc/rbenv.d`
    - `/etc/rbenv.d`
    - `/usr/lib/rbenv/hooks`

This test covers the block of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81-L91){:target="_blank" rel="noopener"}.  We can see that the order of the above directories matches the order in which they're added to `RBENV_HOOK_PATH` by the code:

 - [This line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81){:target="_blank" rel="noopener"} adds `${RBENV_ROOT}/rbenv.d` to the front of `RBENV_HOOK_PATH`.  It would also add any previously-set value of `RBENV_HOOK_PATH` before `${RBENV_ROOT}/rbenv.d` if we had previously set such a value, but we didn't in this test.
 - [This block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L82-L85){:target="_blank" rel="noopener"} adds `${BATS_TEST_DIRNAME%/*}/rbenv.d` to `RBENV_HOOK_PATH`.
 - Lastly, [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L86){:target="_blank" rel="noopener"} adds `/usr/local/etc/rbenv.d`, `/etc/rbenv.d`, and `/usr/lib/rbenv/hooks` to `RBENV_HOOK_PATH`.

That's all for the `rbenv` command's tests.  Let's move onto the code.
