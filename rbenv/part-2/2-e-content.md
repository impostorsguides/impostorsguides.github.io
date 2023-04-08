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

## [Code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv){:target="_blank" rel="noopener"}

This file's first line is:

```
#!/usr/bin/env bash
```

This is the shebang, which we're already familiar with from Part 1.  This tells us that UNIX will use `bash` to process the script.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next line of code is:

```
`set -e`
```

We recognize this line from Part 1 as well- it tells the interpreter to immediately exit with a non-zero status code as soon as the first error is raised (as opposed to continuing on executing the rest of the file).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
if [ "$1" = "--debug" ]; then
...
fi
```

We recognize the `if` statement and the `[[` syntax from Part 1- we're testing whether `$1` evaluates to the string "--debug".  I suspect that `$1` represents the first argument that gets passed to the command, but I'm not sure if the indexing is 0-based or 1-based.  A quick Google should leads me [here](https://web.archive.org/web/20211006091051/https://stackoverflow.com/questions/29258603/what-do-0-1-2-mean-in-shell-script){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/stackoverflow-answer-positional-arguments.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer about positional arguments">
</p>

My guess was correct.  Based on this, we can conclude that if the first argument is equal to "--debug", then... what?  Next line of code:

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
  export RBENV_DEBUG=1
```

We recognize the `export` statement from Part 1.  We set `RBENV_DEBUG` equal to 1, and then export it.

We know from [here](https://unix.stackexchange.com/a/28349/142469){:target="_blank" rel="noopener"} that an `export`ed variable is available in the same script, in a child script, and in a function which is called inside that same script, but not in another sibling script or in a parent process.

[We also know](https://unix.stackexchange.com/a/27568/142469){:target="_blank" rel="noopener"} that the processes in which scripts run are organized like a tree, and that an environment variable which is set in process `A` will be accessible in process `A`'s script and in any child processes, but not in any parent processes.

Next line of code.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
shift
```

What does `shift` do?  According to [the docs](https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_09_07.html){:target="_blank" rel="noopener"}, when called without params, it trims off the first arg from the array of args passed to the script:

> This command takes one argument, a number. The positional parameters are shifted to the left by this number, N. The positional parameters from N+1 to $# are renamed to variable names from $1 to $# - N+1.
>
> Say you have a command that takes 10 arguments, and N is 4, then $4 becomes $1, $5 becomes $2 and so on.  $10 becomes $7 and the original $1, $2 and $3 are thrown away.
>
> ...
>
> If N is not present, it is assumed to be 1.

I did a test script to see how it works.

### Experiment- the `shift` command

I write a script containing the following code:

```
#!/usr/bin/env bash

echo "old arg length: $#"
echo "old args: $@"

echo
echo "Calling shift..."
echo
shift

echo "new arg length: $#"
echo "new args: $@"
```

I run it, passing it the args `foo`, `bar`, and `baz`, and I get:

```
$ ./foo bar baz buzz
old arg length: 3
old args: bar baz buzz

Calling shift...

new arg length: 2
new args: baz buzz
```

Great, it does what I thought it would- decreases the argument count by 1, and lops the first argument off the front of the list.

So to summarize the entire `if` block: if the user passes `--debug` as their first arg to `rbenv`, we set RBENV_DEBUG and trim the `--debug` flag off the list of args.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line:

```
if [ -n "$RBENV_DEBUG" ]; then
```

Since the `-n` flag is passed to the `[` command, I run `man test` and search for `-n`.  I see:

```
-n string     True if the length of string is nonzero.
```

So if the length of `$RBENV_DEBUG` is non-zero (i.e. if we just set it), then execute the code inside this `if`-block.  Which is:

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
# https://wiki-dev.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
```

The first line of code is a comment, containing [a link to an article](https://wiki-dev.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful){:target="_blank" rel="noopener"} about a program named `xtrace`.  Inside the article, we see the following:

> #### Making xtrace more useful
> (by AnMaster)
>
> xtrace output would be more useful if it contained source file and line number. Add this assignment PS4 at the beginning of your script to enable the inclusion of that information:
>
> `export PS4='+(${BASH_SOURCE:-}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'`
>
> Be sure to use single quotes here!
>
> The output would look like this when you trace code outside a function:
>
> `+(somefile.bash:412): echo 'Hello world'`
>
> ...and like this when you trace code inside a function:
>
> `+(somefile.bash:412): myfunc(): echo 'Hello world'`
>
> That helps a lot when the script is long, or when the main script sources many other files.
```

The article mentions that, by setting an environment variable called `PS4` equal to some complicated string, the output of our command line will look different.

So what is PS4, and what does it do?

I try `man PS4` but get no answer.  I Google "PS4 bash", and I open up [the first result I see](https://web.archive.org/web/20230304080135/https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/){:target="_blank" rel="noopener"}.  It mentions not only PS4, but also PS1, PS2, and PS3.  I scroll down to the section on PS4 and I see:

> PS4 – Used by "set -x" to prefix tracing output
>
> The PS4 shell variable defines the prompt that gets displayed, when you execute a shell script in debug mode as shown below.

OK, so we're updating the prompt which is displayed when `set -x` is executed.  That makes sense, because right after we set `PS4` inside our file, the next line is `set -x`.

But what are we updating `PS4` to?

Judging by the dollar-sign-plus-curly-brace syntax, there appears to be some parameter expansion happening here.  On a hunch, I try an experiment.

### Experiment- `BASH_SOURCE` and `LINENO`

I make a script named `foo` with the first half of our `PS4` value, i.e. everything before the space in the middle:

```
#!/usr/bin/env bash

echo "+(${BASH_SOURCE}:${LINENO}):"
```

When I `chmod` and run it, I get:

```
$ chmod +x foo

$ ./foo

+(./foo:3):
```

So the `+(`, `:`, and `):` don't do anything special- they're literal characters which get printed directly to the screen.  That leaves `${BASH_SOURCE}`, which looks like it gets evaluated to `./foo`, and `${LINENO}`, which looks like it resolves to `3`.

What about the 2nd half of `PS4`?

```
${FUNCNAME[0]:+${FUNCNAME[0]}(): }
```

After Googling `FUNCNAME`, I find [the online `man` page entry](https://web.archive.org/web/20230322221925/https://www.man7.org/linux/man-pages/man1/bash.1.html){:target="_blank" rel="noopener"} for `FUNCNAME`:

```
FUNCNAME
              An array variable containing the names of all shell
              functions currently in the execution call stack.  The
              element with index 0 is the name of any currently-
              executing shell function.  The bottom-most element (the
              one with the highest index) is "main".  This variable
              exists only when a shell function is executing.
              Assignments to FUNCNAME have no effect.  If FUNCNAME is
              unset, it loses its special properties, even if it is
              subsequently reset.
```

So `FUNCNAME` is an array variable.  That explains why we're invoking `FUNCNAME[0]` inside the parameter expansion syntax.  And it "contain(s) the names of all shell functions currently in the execution call stack."  Lastly, it "...exists only when a shell function is executing."

So how can I reproduce this behavior?  Let's try another experiment.

### Experiment- attempting to print `FUNCNAME`

I make a script named `foo`, which looks like this:

```
#!/usr/bin/env bash

bar() {
  for method in "${FUNCNAME[@]}"; do
    echo "$method"
  done
  echo "-------"
}

foo() {
  for method in "${FUNCNAME[@]}"; do
    echo "$method"
  done
  echo "-------"
  bar
}

foo
```

It implements two functions, one named `foo` and one named `bar`.  Each function iterates over `FUNCNAME` call stack and prints each item in the call stack.  In addition, `foo` calls `bar`, so `bar` should have one more item in its callstack than `foo` does.

When I run `foo`, I get:

```
$ ./foo
foo
main
-------
bar
foo
main
-------
```

Success- `bar` had one more item printed than `foo` did, just like we hoped.

Getting back to the 2nd half of the `PS4` value:

```
${FUNCNAME[0]:+${FUNCNAME[0]}(): }
```

We see `${ ... }`, so we know we're dealing with parameter expansion again.  And if we take out the two references to `FUNCNAME[0]` (which we know will equal the current function **if we're currently inside a function**), then we're left with `${__:+__():}`.

I'm curious what `:+` means, so I look for these two characters in [the parameter expansion docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"}.  I see:

> ${parameter:+word}
>
> If parameter is null or unset, nothing is substituted, otherwise the expansion of word is substituted.
>
> ```
> $ var=123
> $ echo ${var:+var is set and not null}
> var is set and not null
> ```

So you can pass in a variable, and if that variable is set, `bash` will print whatever string you give it.  That seems to be what's happening here, except instead of checking for `var`, we're checking for `FUNCNAME[0]`.  If it's set, we print its value, followed by `():`.

And that actually fits with what we were told by the article that was linked in the code comment.  It said the terminal would appear...

> ...like this when you trace code inside a function:
>
> `+(somefile.bash:412): myfunc(): echo 'Hello world'`

The `myfunc():` before `echo 'Hello world'` is our value of `FUNCNAME[0]` in the example.

Does all that pan out when we actually run `rbenv` with the `--debug` flag?  Let's try with `rbenv --debug version`:

```
$ rbenv --debug version
```

There's a ton of output.  Below is one line from that output which comes from *outside* of a function...

```
+(/Users/myusername/.rbenv/bin/rbenv:73): shopt -s nullglob
```

...and another which comes from *inside* a function:

```
++(/Users/myusername/.rbenv/bin/rbenv:41): abs_dirname(): local path=/Users/myusername/.rbenv/bin/rbenv
```

Although we haven't yet reached these lines of code and don't yet know what they do, the format of the output does line up with what we've learned about our new `PS4` value.

### Aside- what is `xtrace`?

I kept noticing the phrase `xtrace` being thrown around on some of the links I encountered while trying to solve the above.  I Googled "what is xtrace bash", and found [this link](https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_02_03.html){:target="_blank" rel="noopener"}, which says:

<p style="text-align: center">
  <img src="/assets/images/stackoverflow-answer-12mar2023-138pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer about `xtrace`">
</p>

That's a lot, but the bottom table shows the short notation of `set -x` corresponds to the long notation of `set -o xtrace`, or "set the xtrace option".  So `xtrace` is the name of a mode in bash.

And the cool thing is, you don't have to enable `set -x` only at the beginning of the script, like RBENV's code does.  According to the above link from TLDP, you can enable it and disable it anywhere you want in your code, as many times as you want.

So if you're trying to debug something tricky and you want to avoid getting overloaded with `PS4` output for every line of your code, you can turn it on for just the buggy section of your code, and turn it off immediately after.  Sounds useful!

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So summarizing the first 2 blocks of code: we first check if the user passed `--debug` as the first argument.  If they do:

 - we set the `RBENV_DEBUG` env var.
 - Then in the 2nd block, if the `RBENV_DEBUG` env var has been set:
    - we change the terminal prompt to output more useful version of `PS4`, and
    - we call `set -x` to put bash into debug mode.

But why do we need to separate these steps into different blocks of code?  Why didn't we just combine them, like so:

```
if [ "$1" = "--debug" ]; then
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi
```

The reason is because we need to `export` the `RBENV_DEBUG` environment variable so that other commands can access it for their own purposes.

If we look for `RBENV_DEBUG` throughout the codebase, we can see it used in multiple locations:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-24mar2023-623pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</center>

All of the line numbers are pretty low: I see lines 4, 5, 6, 11, 10, 4, etc.  So it looks like at the start of all these files, we check if `RBENV_DEBUG` has been set, and if it has, we invoke `xtrace` via the `set -x` command.  This implies that you can't just turn on `xtrace` in an entry script and expect it to remain on in any child scripts that the parent invokes.  Rather, you need to turn it on for each file that you expect to run.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
abort() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
  } >&2
  exit 1
}
```

This declares a function named `abort`.  There's a block of code surrounded with curly braces, with `>&2` appended to the end:

```
  { if [ "$#" -eq 0 ]; then cat -
  ...  } >&2
```

I'm a bit thrown off by this syntax here. Why is this code...

```
if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
```

...wrapped inside this code?

```
{
...
} >&2
```

Let's start on the outside and work our way in.  What is the function of the curly braces?

I Google "curly braces bash", and the first result I get is [this one from Linux.com](https://web.archive.org/web/20230306114329/https://www.linux.com/topic/desktop/all-about-curly-braces-bash/){:target="_blank" rel="noopener"}, which sounds promising.  I scan through the article looking for syntax which is similar to what we're doing, and along the way I learn some interesting but unrelated stuff (for instance, `echo {10..0..2}` will print every 2nd number from 10 down to 0 in your terminal).

Finally I get to the last section of the article, called "Output Grouping".  It's here that I learn that "...you can also use `{ ... }` to group the output from several commands into one big blob."

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-937am.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="...you can also use `{ ... }` to group the output from several commands into one big blob.">
</center>

Cool, mystery solved- we're capturing the output of everything inside the curly braces, so we can output it all together (instead of just the last statement).

Next question- what is `>&2` at the end there?  In the above example, we were redirecting all the output to a file, but that doesn't look like what we're doing here since there's no filename to send things to.

I Google ">&2 bash".  The first result is from [StackExchange](https://askubuntu.com/questions/1182450/what-does-2-mean-in-a-shell-script){:target="_blank" rel="noopener"}:

> Using > to redirect output is the same as using 1>. This says to redirect stdout (file descriptor 1).
>
> Normally, we redirect to a file. However, we can use >& to redirect to stdout (file descriptor 1) or stderr (file descriptor 2) instead.
>
> Therefore, to redirect stdout (file descriptor 1) to stderr (file descriptor 2), you can use >&2

Looks like we're redirecting the output of whatever is inside the curly braces, and sending it to stderr.  I happen to know from prior experience that `stdout` is short-hand for "standard out", and "stderr" means "standard error".  I have a vague notion of what these terms mean, but I'm not sure I could verbalize what they actually refer to.

I Google "stdout stdin stderr" and get [this link](https://web.archive.org/web/20230309084428/https://www.tutorialspoint.com/understanding-stdin-stderr-and-stdout-in-linux){:target="_blank" rel="noopener"} as the first result.  From reading it, I learn that:

 - these three things are called "data streams".
 - "...a data stream is something that gives us the ability to transfer data from a source to an outflow and vice versa. The source and the outflow are the two end points of the data stream."
 - "...in Linux all these streams are treated as if they were files."
 - "...linux assigns unique values to each of these data streams:
    - 0 = stdin
    - 1 = stdout
    - 2 = stderr"

One additional thing to call out is from [the 2nd Google result, from Microsoft](https://web.archive.org/web/20230225220140/https://learn.microsoft.com/en-us/cpp/c-runtime-library/stdin-stdout-stderr?view=msvc-170){:target="_blank" rel="noopener"}:

> By default, standard input is read from the keyboard, while standard output and standard error are printed to the screen.

So... the output of the code between our curly braces would normally be printed to the screen, but instead we're printing it to... the screen?  That doesn't make sense- why would we redirect something from one place and to the same place?

It's helpful to stop associating `stdout` and `stderr` with "the screen" and *start* thinking of them as two ends of a pipe.  We can chain this pipe to other pipes any way we want.  And, importantly, **so can other people**.  So if we redirect the output of our `abort` function to `stderr`, then someone else can pick up where we left off, and send the output of `stderr` anywhere they want.

This idea of chaining and composing things together using (among other things) `stdin`, `stdout`, and `stderr` makes our job as `bash` programmers way easier, and is one of the Big Ideas™ of UNIX.

A website called Guru99 seems to have [some good content on redirection](https://web.archive.org/web/20230309072616/https://www.guru99.com/linux-redirection.html){:target="_blank" rel="noopener"}.  For example:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-1039am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

Here we're taking the output of the `ls -al` command (which would normally be sent to the screen via `stdout`) and redirecting it to a file instead via the `>` character.

But wait, I've also previously seen the `|` character used to send output from one place to another.  Why are we using `>` here instead?

I Google "difference between < > \| unix", but the special characters confuse Google and I get a bunch of irrelevant results.  I try my luck with ChatGPT, with the understanding that I'll need to double-check its answers after:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-1052am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
</center>

ChatGPT tells me that `>` and `<` are used for "redirection", i.e. sending output to or pulling input from **a file**.  On the other hand, `|` is used for "piping" output to a **command**.

Based on this, I Google "difference between redirection and piping unix", and one of the first results I get is [this StackExchange post](https://web.archive.org/web/20220630113310/https://askubuntu.com/questions/172982/what-is-the-difference-between-redirection-and-pipe){:target="_blank" rel="noopener"} which says something quite similar to ChatGPT:

<center style="margin-bottom: 3em">
  <img src="/assets/images/screenshot-25mar2023-1101am.png" width="80%" style="border: 1px solid black; padding: 0.5em">
</center>

I like that this person explains how it's possible (but clunky) to use `>` to redirect to a file, and then use `<` to grab the content of that file and redirect it to another command.  So instead, we just use `|` instead.  That somehow makes things much clearer for me.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So what exactly is the output that we're reirecting to `stderr`?  Let's move on to the code inside the curlies.

First question- what does `$#` evaluate to?  According to [StackOverflow](https://web.archive.org/web/20211120050118/https://askubuntu.com/questions/939620/what-does-mean-in-bash){:target="_blank" rel="noopener"}:

> `echo $#` outputs the number of positional parameters of your script.

So `[ "$#" -eq 0 ]` means "if the # of positional parameters is equal to zero"?  Let's test that with an experiment.

### Experiment- counting parameters

I write the following script, named `foo`:

```
#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
  echo "no args given"
else
  echo "$# args given"
fi
```

When I run it with no args, I see:

```
$ ./foo

no args given
```

When I run it with one arg, I see:

```
$ ./foo bar

1 args given
```

And when I run it with multiple args, I see:

```
$ ./foo bar baz

2 args given
```

Good enough for me!  I think we can conclude that `[ "$#" -eq 0 ]` returns true if the number of args is equal to zero.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

But whose positional parameters are we talking about- the `abort` function's params, or rbenv's params?

I try wrapping my experiment code in a simple function definition:

```
#!/usr/bin/env bash

function myFunc() {
  if [ "$#" -eq 0 ]; then
    echo 'no args given';
  else
    echo "$# args given";
  fi
}

echo "$# args given to the file";

myFunc foo bar baz buzz
```

I'm passing 4 args to `myFunc`, but I'm planning to call my script with only 2 args, with the intention that:

 - If `$#` refers to the number of args sent to the file, then we should see the same counts from the `echo` statements outside vs. inside the function.
 - But if `$#` refers to the # of args sent to `myFunc`, then we'll see different counts for these two `echo` statements.

When I run the script file with multiple args, I see:

```
$ ./foo bar baz

2 args given to the file
4 args given
```

We see different counts for the # of args passed to the file vs. to `myFunc`.  So when `$#` is inside a function, it *must* be refer to the # of args passed to that same function.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Back to our block of code:

```
  { if [ "$#" -eq 0 ]; then cat -
  ...  } >&2
```

So if the number of args we pass to `abort` is 0, then we execute `cat -`.  What is `cat -`?

I type `help cat` in my terminal, and get the following:

> The `cat` utility reads files sequentially, writing them to the standard output.  The file operands are processed in command-line order.  If file is a single dash ('-') or absent, `cat` reads from the standard input.

OK, so if there are no args passed to `abort`, then we read from standard input.  Interesting.  Based on what we learned earlier about redirection and piping, I wonder if the caller of the `abort` function is piping its `stdout` to the `stdin` here, so that `abort` can read it via `cat -`.

I search for `| abort` in this file, and I find [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L99-L101){:target="_blank" rel="noopener"}:

```
  { rbenv---version
    rbenv-help
  } | abort
```

It looks like we're doing something similar with curly braces (i.e. capturing the output from a block of code) and piping it to `abort`.  So, yeah, it looks like we were right about the purpose of `cat -`- it lets us capture arbitrary input from `stdin` and print it to the screen.

Let's try to replicate that and see what happens:

```
#!/usr/bin/env bash

function foo() {
  {
    if [ "$#" -eq 0 ]; then cat -
    fi
  } >&2
  exit 1
}

echo "Whoops" | foo
```

When I run this script, I see:

```
$ ./foo

Whoops
```

Gotcha- so the logic inside the `if` clause is meant to allow the user (aka the caller of the "abort" function) to be able to send text into the function via piping.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
    else echo "rbenv: $*"
```

What does `$*` do?  This time, it's [O'Reilly to the rescue](https://web.archive.org/web/20230323072228/https://www.oreilly.com/library/view/learning-the-bash/1565923472/ch04s02.html){:target="_blank" rel="noopener"}:

<p style="text-align: center">
  <img src="/assets/images/screenshot-25mar2023-1137am.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow - what does `$*` do?">
</p>

So `$*` expands to a single string containing all the arguments passed to the script.  We can verify that by writing our own simple script:

```
#!/usr/bin/env bash

echo "args passed in are: $*"
```

When we call it, we get:

```
$ ./foo bar baz

args passed in are: bar baz
```

No surprises here.

While we're at it, let's try a similar experiment that we did with `cat -`, but with the "else" case here.  Going back into my "foo" script, I make the following changes:

 - I add an identical `else` clause to our `foo` function, and
 - I replace the previous pipe invocation of `foo` with a new one that passes a string as a parameter:

```
#!/usr/bin/env bash

foo() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
  } >&2
  exit 1
}

foo "cannot find readlink - are you missing GNU coreutils?"
```

Running the script gives us:

```
$ ./foo

rbenv: cannot find readlink - are you missing GNU coreutils?
```

So it just concatenates "rbenv: " at the front of whatever error message you pass it.

So to sum up the "abort" function:

 - if you don't pass it any string as a param, it assumes you are piping in the error, and it reads from STDIN and prints the input to STDERR.  Otherwise...
 - It assumes that whatever param you passed is the error you want to output, and...
 - It prints THAT to STDERR.
 - Lastly, it terminates with a non-zero exit code.

We were lucky here, because the function we were studying is called throughout the file, and those usage examples were helpful (to me at least) in understanding how the function worked.  It's not always possible to use this strategy, but when it IS possible, it's a good tool for our toolbelt.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

[Next line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23){:target="_blank" rel="noopener"} is:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

Reading this line, I ask myself a few questions:

 - What does the `enable` command do?
 - What does its `-f` flag mean?
 - What are the command's positional arguments?
 - What does `2>/dev/null` do?
 - What kind of file extension is `.dylib`?  What does that imply about the contents of the file?

I'll try to answer these one-by-one.

I type both `man enable` and `help enable` in my terminal, but each time I see `No manual entry for enable`.

Luckily, [the first result](https://web.archive.org/web/20220529121055/https://ss64.com/bash/enable.html){:target="_blank" rel="noopener"} when I Google "enable command bash" looks like a good one, even if it's not part of the official docs:

<p style="text-align: center">
  <img src="/assets/images/enable-docs-12mar2023-157pm.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="Docs on the `enable` keyword">
</p>

This actually answers my first three questions:

 - What does the `enable` command do?
    - The `enable` command can take builtin shell commands (like `which`, `echo`, `alias`, etc.) and turn them on or off.
    - The link mentions that this could be useful if you have a script which shares the same name as a builtin command, and which is located in one of your $PATH directories.
    - Normally, the shell would check for builtin commands first, and only search in $PATH if no builtins were found.
    - You can ensure your shell won't find any builtin command by disabling the builtin using the `enable` command.
    - [Here's a link explaining more](https://web.archive.org/web/20230407091137/https://www.oreilly.com/library/view/bash-cookbook/0596526784/ch01s09.html){:target="_blank" rel="noopener"}, from O'Reilly's Bash Cookbook.

 - What does the `-f` flag do?
    - You would pass this flag if you want to change the source of your new command from its original source (the builtin) to a file whose path you specify after the `-f` flag.
    - In other words, you want to [monkey-patch](https://web.archive.org/web/20221229064458/https://stackoverflow.com/questions/394144/what-does-monkey-patching-exactly-mean-in-ruby){:target="_blank" rel="noopener"} the command (or even rebuild it entirely, from scratch).

 - What are the command's positional arguments?
    - In the case of our line of code, the first positional argument is the filepath containing the new version of the command we're over-riding.
    - The 2nd positional argument is the name of the command we're over-riding.

TODO- add experiment on using the `enable` command, possibly including the `-f` flag.

My 4th out of 5 questions was "What does `2>/dev/null` do?"

According to [StackOverflow](https://web.archive.org/web/20220801111727/https://askubuntu.com/questions/350208/what-does-2-dev-null-mean){:target="_blank" rel="noopener"}:

 - The `2>` tells the shell to take the output from file descriptor #2 (aka `stderr`) and send it to the destination specified after the `>` character.
 - Further, "`/dev/null` is the null device it takes any input you want and throws it away. It can be used to suppress any output."
 - So here we're suppressing any error which is output by the `enable` command, rather than showing it.

If I had to guess, I'd say we're doing that because this is part of an `if` check, and if the `enable` command fails, we don't want to see the error, we just want to move on and execute the code in the `else` block.

TODO- add experiment on using `/dev/null`.

Final question: what kind of file extension is `.dylib`, and what does that imply about the contents of the file?

I Googled "what is dylib extension" and read a few different results ([here](https://web.archive.org/web/20211023152003/https://fileinfo.com/extension/dylib){:target="_blank" rel="noopener"} and [here](https://web.archive.org/web/20211023142331/https://www.lifewire.com/dylib-file-2620908){:target="_blank" rel="noopener"}, in particular).  They tell me that:
 - "dylib" is a contraction of "dynamic library", and that this means it's a library of code which can be loaded on-the-fly (aka "dynamically").
 - Loading things dynamically (as opposed to eagerly, when the shell or the application which relies on it is first booted up) means you can wait until you actually need the library before loading it.
 - This, in turn, means you're not taking up memory with code that you're not actually using yet.

So to summarize:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

Means:

 - If we're successful in monkey-patching the `realpath` command with a new implementation which lives in the `rbenv-realpath.dylib` file, then do the thing inside the `if` block.
 - If we're *not* successful in doing that, ignore any `stderr` output rather than printing it to the screen.

Speaking of the `realpath` command- what does it normally do?

Typing `man realpath` into our terminal reveals the following:

```
REALPATH(1)                                                                       User Commands                                                                      REALPATH(1)

NAME
       realpath - print the resolved path

SYNOPSIS
       realpath [OPTION]... FILE...

DESCRIPTION
       Print the resolved absolute file name; all but the last component must exist
```

The phrase "print the resolved path" is confusing to me.  In what sense is the path that the user provides "resolved"?  What would "unresolved" mean?

I search for "what is realpath unix" and find [the internet equivalent of the same man page](https://web.archive.org/web/20220608150749/https://man7.org/linux/man-pages/man1/realpath.1.html){:target="_blank" rel="noopener"}.  But then I find [the `man(3)` page](https://web.archive.org/web/20220629161112/https://man7.org/linux/man-pages/man3/realpath.3.html){:target="_blank" rel="noopener"} for a *function* named `realpath`.  Among other things, it says:

> realpath() expands all symbolic links and resolves references to `/./`, `/../` and extra `/` characters in the null-terminated string named by `path` to produce a canonicalized absolute pathname.

OK, so the `realpath()` function takes something like `~/foo/../bar` and changes it to `/Users/myusername/bar`.  That must mean a path like...
```
~/Desktop/my-company/projects/..
```

...is an "unresolved" path, and calling `realpath` on that unresolved path would return...

```
/Users/myusername/Desktop/my-company
```

I quickly test this out in my terminal:

```
$ mkdir ~/foo
$ mkdir ~/bar
$ realpath ~/foo/../bar

/Users/myusername/bar
```

Side-note: I initially tried to run the `realpath` command first, without having created the directories, but I got `realpath: /Users/myusername/foo/../bar: No such file or directory`.  So it looks like the file or directory does actually have to exist in order for `realpath` to work.

So this `if` block overrides the existing `realpath` command, but only if the `"${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib` file exists.

This makes me wonder:
 - **Why** did the authors feel the need to override the existing `realpath` command?
 - Wouldn't it have been safer to just call their imported function something else?
- And what was wrong with the original `realpath`, anyway?

### Why over-ride `realpath`?

To answer question #1, I decide to search the repo's `git` history.

I start by running the following command in the terminal, in the home directory of the `rbenv` repo that I pulled down from Github:

```
$ git blame libexec/rbenv
```

I get the following output (click the image to expand):

<center style="margin-bottom: 3em">
  <a href="/assets/images/git-blame-output-12mar2023-213pm.png" target="_blank">
    <img src="/assets/images/git-blame-output-12mar2023-213pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

This output is organized into columns:

 - Column #1 is the SHA of the commit that added this line to the codebase.
 - Column #2 is the author of the commit.
 - Column #3 is the timestamp when the code was committed.
 - Column #4 is the line number in the file, and
 - Column #5 is the actual line of code itself.

The code I'm trying to research is on [line 23 of the file](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv#L23){:target="_blank" rel="noopener"}, so I scan down to the right line number based on the values in column #4, and I see the following:

```
6e02b944 (Mislav Marohnić   2015-10-26 15:53:20 +0100  23) if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
```

We can parse this line as follows:

 - The SHA of the commit we're looking for is 6e02b944.
 - The author of this code is someone named Mislav Marohnić.
 - This code was committed on Oct 26, 2015 at 15:53pm +0100 (aka Central European Standard Time, I think?).
 - `23)` is the line number of our code.
 - Everything after `23)` is just the original line of code itself.

If we were to run `git checkout 6e02b944`, we'd be telling git to roll all the way back to 2015, making this commit the latest one in our repo.

I plug this SHA into Github's search bar from within the repo's homepage, and I see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-459pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-459pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github search results">
  </a>
</p>

I click on the one commit that comes back, and see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-500pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-500pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github search results part 2">
  </a>
</p>

Clicking through once again, I see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-501pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-501pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github search results part 2">
  </a>
</p>


This shows us what the code was like before this commit, and what it was like after.  In this case, it's not super-helpful, because this commit changed the line of code but not in a way that makes clear what's going on.

Let's try a different strategy:

 - I'll roll back my local version of this repo to an earlier commit.
 - But that earlier commit will **not** be the one we're looking at now (i.e. `6e02b944`).
 - Instead, I'll use the commit *before* this commit.
 - If I then re-run `git blame` on this same line of code, **with that older commit checked-out via `git checkout <older_commit_sha>`**, I can see the diff and the SHA which led to **that change**.
 - Repeating this process as necessary, I will eventually get to the commit which introduced the monkey-patching of `realpath`, (hopefully) along with an explanation of why this was done.

I run `git checkout 6e02b944~`.  Note the single `~` at the end, which means "the commit just prior to `6e02b94`.  You can say "two commits prior" by running `git checkout 6e02b944~~`, or alternately `git checkout 6e02b944~2`.

From the last screenshot above, we can see that the old line of code was #15, so let's look for that line in the `git blame` output:

```
$ git checkout 6e02b944~

Note: switching to '6e02b944~'.
...

$ git blame libexec/rbenv
```

...results in:

```
6938692c (Andreas Johansson 2011-08-12 11:33:45 +0200   1) #!/usr/bin/env bash
6938692c (Andreas Johansson 2011-08-12 11:33:45 +0200   2) set -e
e3f72eba (Sam Stephenson    2013-01-25 12:02:11 -0600   3) export -n CDPATH
43624943 (Joshua Peek       2011-08-02 18:01:46 -0500   4)
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   5) if [ "$1" = "--debug" ]; then
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   6)   export RBENV_DEBUG=1
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   7)   shift
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600   8) fi
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600   9)
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  10) if [ -n "$RBENV_DEBUG" ]; then
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  11)   export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] '
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  12)   set -x
892aea13 (Sam Stephenson    2013-01-23 19:05:26 -0600  13) fi
3cb95b4d (Sam Stephenson    2013-01-23 19:06:08 -0600  14)
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  15) if enable -f "${0%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  16)   abs_dirname() {
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  17)     local path="$(realpath "$1")"
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  18)     echo "${path%/*}"
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  19)   }
5287e2eb (Mislav Marohnić   2014-01-04 16:36:02 +0100  20) else
```


The SHA is `5287e2eb`.  Let's again plug this into Github's search history:

When we click on the "Commits" section, we see:

<p style="text-align: center">
  <a href="/assets/images/searching-for-a-commit-12mar2023-444pm.png" target="_blank">
    <img src="/assets/images/searching-for-a-commit-12mar2023-444pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Searching for a commit in the Github repo">
  </a>
</p>

And when we click on the "Issues" section, we see:

<p style="text-align: center">
  <a href="/assets/images/searching-for-gh-issues-12mar2023-444pm.png" target="_blank">
    <img src="/assets/images/searching-for-gh-issues-12mar2023-444pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Searching for a commit in the Github repo">
  </a>
</p>

OK, so judging by the title of the issue, this change has something to do with making rbenv's performance faster.

Clicking on [the issue link](https://github.com/rbenv/rbenv/pull/528){:target="_blank" rel="noopener"} first, I see:

<p style="text-align: center">
  <a href="/assets/images/screenshot-25mar2023-519pm.png" target="_blank">
    <img src="/assets/images/screenshot-25mar2023-519pm.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Github issue on speeding up rbenv by dynamically loading a compiled command">
  </a>
</p>

Looks like that's correct- the goal of this change was to address a bottleneck in rbenv's performance, i.e. "resolving paths to their absolute locations without symlinks".

To make sure this is the right change, I still think it's a good idea to look at [the Commit link](https://github.com/rbenv/rbenv/commit/5287e2ebf46b8636af653c1c61d4dc0dffd65796){:target="_blank" rel="noopener"} too:

<p style="text-align: center">
  <a href="/assets/images/gh-commit-for-issue-528.png" target="_blank">
    <img src="/assets/images/gh-commit-for-issue-528.png" width="100%" style="border: 1px solid black; padding: 0.5em" alt="Code for Github issue on speeding up rbenv by dynamically loading a compiled command">
  </a>
</p>

Here we see that the original code only had one definition of the `abs_dirname` function.  This commit added a 2nd definition, as well as the `if/else` logic that checks if the `realpath` re-mapping is successful.  If that re-mapping fails, we use the old `abs_dirname` function as before.

I'm still not sure what the difference is between the old and new versions of `realpath`, but I think we can safely assume that the only difference is that it uses a faster algorithm, not that it actually has different output.  If there were such a difference, the dynamic library might well be unsafe to use as a substitute.

Great!  This makes way more sense now.  Before moving on, let's roll our local copy of the repo forward, back to the one we originally cloned.  The SHA for that commit is `c4395e58201966d9f90c12bd6b7342e389e7a4cb`.  If you don't have this SHA saved under a branch name yet, you'll have to do something like:

```
git checkout c4395e58201966d9f90c12bd6b7342e389e7a4cb
```

For the sake of convenience, I have that SHA checked out under the branch name `impostor`, so all I have to do is:

```
$ git co impostor
```

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

We're now in a position to move on to the logic inside the `if` clause.  Here we define a function called `abs_dirname`, whose implementation contains just 3 lines of code:

```
  abs_dirname() {
    local path
    path="$(realpath "$1")"
    echo "${path%/*}"
  }
```

Those 3 lines of code are:

 - We create a local variable named `path`.
 - We call our (possibly) monkey-patched `realpath` builtin, passing it the first argument given to the `abs_dirname` function.
 - We set the local variable equal to the return value of the above.
 - We `echo` the contents of the local variable.

By `echo`'ing the value of our `path` local variable at the end of the `abs_dirname` function, we make the value of `path` into the return value of `abs_dirname`.  This means the caller of `abs_dirname` can do whatever it wants with that resolved path.

TODO: I think this is the first time we've seen the use of `local`, as well as the use of `echo` to return something from a function.  Should I do an experiment to demonstrate these techniques further?

The "%/*" after `path` inside the parameter expansion just deletes off any trailing "/" character, as well as anything after it.  We can reproduce that in the terminal:

```
$ path="/foo/bar/baz/"
$ echo ${path%/*}
/foo/bar/baz

$ path="/foo/bar/baz"
$ echo ${path%/*}
/foo/bar
```

### Aside- nested double-quotes

Let's briefly return to line 2 of the body of `abs_dirname`:

```
path="$(realpath "$1")"
```

I see two sets of double-quotes, one nested inside the other, wrapping both "$(...)" and "$1".

This is unexpected to me.  I would have thought that:

 - The 2nd `"` character would close out the 1st `"`, meaning `"$(realpath "` would be wrapped in one set of double-quotes, and
 - The 4th `"` would close out the 3rd one, meaning `")"` would be wrapped in a separate set of quotes.
 - Therefore, the `$1` in the middle would then be completely unwrapped.

When I Google "nested double-quotes bash", the first result I get is [this StackOverflow post](https://web.archive.org/web/20220526033039/https://unix.stackexchange.com/questions/289574/nested-double-quotes-in-assignment-with-command-substitution){:target="_blank" rel="noopener"}:

> Once one is inside `$(...)`, quoting starts all over from scratch.

OK, simple enough!

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on to the `else` block:

```
[ -z "$RBENV_NATIVE_EXT" ] || abort "failed to load \`realpath' builtin"

READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
[ -n "$READLINK" ] || abort "cannot find readlink - are you missing GNU coreutils?"

resolve_link() {
  $READLINK "$1"
}

abs_dirname() {
  local cwd="$PWD"
  local path="$1"

  while [ -n "$path" ]; do
    cd "${path%/*}"
    local name="${path##*/}"
    path="$(resolve_link "$name" || true)"
  done

  pwd
  cd "$cwd"
}
```

This is a lot.  We'll process it in steps, but it looks like we're doing something similar here (defining a function named `abs_dirname`), albeit this time with a bit of setup beforehand.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

First line of this block of code is:

```
[ -z "$RBENV_NATIVE_EXT" ] || abort "failed to load \`realpath' builtin"
```

Judging by the `||` symbol, we know that if the test inside the single square brackets is falsy, then we `abort` with the quoted error message.

But what is that test?  To find out, we run `help test` in our terminal again, and search for `-z` using the forward-slash syntax.  We get:

>  -z string     True if the length of string is zero.

OK, so if the `$RBENV_NATIVE_EXT` environment variable is empty, then the test is truthy.  If that env var has already been set, then the test is falsy, and we would abort using our previously-defined function, which triggers a non-zero exit.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
  READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
```

So we're setting a variable called `READLINK` equal to...something.

I decide to look up the commit which introduced this line of code.  I do my `git blame / git checkout` dance until [I find it in Github](https://github.com/rbenv/rbenv/commit/81bb14e181c556e599e20ca6fdc86fdb690b8995){:target="_blank" rel="noopener"}.  The commit message reads:

> `readlink` comes from GNU coreutils.  On systems without it, rbenv used to spin out of control when it didn't have `readlink` or `greadlink` available because it would re-exec the frontend script over and over instead of the worker script in libexec.

That's somewhat helpful.  Although I don't yet know which `worker script` they're referring to, it's not crazy that RBENV might want to exit with a warning that a dependency is missing, rather than silently suffer from performance issues.

Back to the main question: what value are we assigning to the `READLINK` variable?

I start with that `type -p` command.  I try `help type` in the terminal, and because I'm using the `zsh` shell (and my `help` command is aliased to `run-help`), I get the following:

```
whence [ -vcwfpamsS ] [ -x num ] name ...
       For each name, indicate how it would be interpreted if used as a
       command name.

       If  name  is  not  an alias, built-in command, external command,
       shell function, hashed command, or a  reserved  word,  the  exit
       status  shall be non-zero, and -- if -v, -c, or -w was passed --
       a message will be written to standard output.  (This is  differ-
       ent  from  other  shells that write that message to standard er-
       ror.)

       whence is most useful when name is only the last path  component
       of  a  command, i.e. does not include a `/'; in particular, pat-
       tern matching only succeeds if just the non-directory  component
       of the command is passed.

       ...

       -p     Do a path search for name even if it  is  an  alias,  re-
              served word, shell function or builtin.
```

Looks like `type` and `whence` share the same documentation in `zsh`.  They might be aliases of each other.  I'm not sure, but I trust the authors of my shell's docs so I let it go.

These docs are a bit confusing, however.  I'm not sure what `indicate how it would be interpreted` means.  I decide to do an experiment with the `type` command and its `-p` flag.

### Experiment- the `type -p` command

I see that `name` is the first argument of the `type` command, but I'm not sure what kind of `name` the command expects.  From the above docs, I see `If  name  is  not  an alias, built-in command, external command, shell function, hashed command, or a  reserved  word,  the  exit status  shall be non-zero,...`.  I interpret this to mean that `name` refers to the name of a command, alias, reserved word, etc.

I make a `foo` script, which looks like so and uses `ls` as the value of `name`:

```
#!/usr/bin/env bash

echo $(type -p ls)
```

When I run it, I get:

```
$ ./foo

/bin/ls
```

When I change `ls` in the script to `chmod` and re-run it, I see:

```
$ ./foo

/bin/chmod
```
As a final experiment, I create a directory named `~/foo`, containing a script named `bar`, and make it executable:

```
$ mkdir ~/foo
$ touch ~/foo/bar
$ chmod +x ~/foo/bar
$ touch ~/foo/baz
$ chmod +x ~/foo/baz
```
I then try the `type -p` command on my new script, from within my `foo` bash script:
```
#!/usr/bin/env bash

echo $(type -p ~/foo/bar ~/foo/baz ls)
```

When I run it, I get:

```
$ ./foo

/Users/myusername/foo/bar /Users/myusername/foo/baz /bin/ls
```

I see the 3 paths I expected.  Great, I think this all makes sense.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on, we already know what `2>/dev/null` is from earlier- here we redirect any error output from `type -p` to `/dev/null`, aka [the black hole of the console](https://web.archive.org/web/20230116003037/https://linuxhint.com/what_is_dev_null/){:target="_blank" rel="noopener"}.

TODO: experiment w/ `/dev/null`?

But what do we do with any non-error output?  That's answered by the last bit of code from this line: `| head -n1`.  Running `man head` gives us:

```
head – display first lines of a file
...-n count, --lines=count
             Print count lines of each of the specified files.
```
So it seems like `| head -n1` means that we just want the first line of the input that we're piping in from `type -p`?  Let's test this hypothesis.

### Experiment- the `head` command

I make a simple script that looks like so:

```
#!/usr/bin/env bash

echo "Hello"
echo "World"
```

When I run it by itself, I get:

```
$ ./foo

Hello
World
```

Next, I run it a 2nd time, but this time with `| head -n1` at the end:

```
$ ./foo | head -n1

Hello
```

This time I only see 1 of the 2 lines I previously saw.  Looks like our hypothesis is correct!

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So to sum up this line of code:

```
READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
```

 - We print out the paths to two commands, one named `greadlink` and one named `readlink`, in that order.
 - We take the first value we find, preferring `greadlink` since it comes first in the argument order.
 - Finally, we store that value in a variable named `READLINK` (likely capitalized to avoid a name collision with the `readlink` command).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next line of code is:

```
[ -n "$READLINK" ] || abort "cannot find readlink - are you missing GNU coreutils?"
```

We already learned what `[ -n ...]` does from reading about `$RBENV_DEBUG`.  It returns true if the length of (in our case) `$READLINK` is non-zero.  So if the length of `$READLINK` *is* zero, then we `abort` with the specified error message.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's look at the next 3 lines of code together, since it's just a simple function declaration:

```
  resolve_link() {
    $READLINK "$1"
  }
```

When we call this `resolve_link` function, we invoke either the `greadlink` command or (if that doesn't exist) the `readlink` command.  When we do this, we pass any arguments which were passed to `resolve_link`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
abs_dirname() {
  local cwd="$PWD"
  local path="$1"

  while [ -n "$path" ]; do
    cd "${path%/*}"
    local name="${path##*/}"
    path="$(resolve_link "$name" || true)"
  done

  pwd
  cd "$cwd"
}
```

So here's where we're declaring the version of `abs_dirname` from the `else` block (as an alternative to the `abs_dirname` function in our `if` block above).

The first two lines of code in our function body are:

```
    local cwd="$PWD"
    local path="$1"
```

We declare two local variables:

 - A var named `cwd`.
    - This likely stands for "current working directory".
    - Here we store the absolute directory of whichever directory we're currently in when we run the `rbenv` command.
 - A var named `path`, which contains the first argument we pass to `abs_dirname`.

Next line of code:

```
while [ -n "$path" ]; do
...
done
```

In other words, while the length of our `path` local variable is greater than zero, we do...something.  That something is:

```
cd "${path%/*}"
local name="${path##*/}"
path="$(resolve_link "$name" || true)"
```

The above 3 lines of code are inside the aforementioned `while` loop.  Taken together, they are pretty hard for me to get my head around.

To see what's actually happening at each step in this loop, I try adding multiple `echo` statements to the `while` loop's code:

<p style="text-align: center">
  <a href="/assets/images/screenshot-12mar2023-655pm.png" target="_blank">
    <img src="/assets/images/screenshot-12mar2023-655pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

Note that I make the above change inside the code for my RBENV installation (i.e. the code at `~/.rbenv/libexec/rbenv`), **not** the code I've pulled down from Github.

I prefaced the `echo` statements with `>&2` because I don't want these `echo` statements to be interpreted as the output of the `abs_dirname` function.

Another change I need to make in this same file is to temporarily comment out the `if`-block that we just finished reading, to make sure that our `else`-block gets evaluated:

<p style="text-align: center">
  <a href="/assets/images/screenshot-12mar2023-653pm.png" target="_blank">
    <img src="/assets/images/screenshot-12mar2023-653pm.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

Re-running the `rbenv init` command:

<p style="text-align: center">
  <img src="/assets/images/much-output-12mar2023-656pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

And when I run `rbenv commands`, I get the logging statements above, plus a list of commands I can run from `rbenv`:

<p style="text-align: center">
  <img src="/assets/images/much-echo-12mar2023-702pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The first thing I notice is that I don't know how many iterations of the `while` loop took place.  I can figure it out, because there are 2 references to `new path:`, but it's kind of hard to read because everything is muddled together.  This would be easier to read if each iteration included some sort of demarcation or delimiter.  I add one now:

<p style="text-align: center">
  <img src="/assets/images/new-path-echo-12mar2023-703pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

While I'm at it, I decide to change one of my tracer statements from `>&2 echo "path%/*: ${path%/*}"` to `>&2 echo "path that we will cd into: ${path%/*}"`.  I also remove all the tracer statements outside of the `while` loop.  I made both these changes for added readability.

Re-running `rbenv init`:

<p style="text-align: center">
  <img src="/assets/images/more-tracers-12mar2023-704pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

And re-running `rbenv commands`:

<p style="text-align: center">
  <img src="/assets/images/yet-moar-tracers-12mar2023-705pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So at a certain point the condition in our `while` loop becomes falsy, which means we no longer execute further loops.  What is it inside the loop which causes that condition to *become* falsy, and what can we infer about the purpose of the code from that change?

The `while` loop's condition is true as long as `[ -n "$path" ]` is true.  In other words, the `while` loop continues looping until the length of `"$path"` becomes 0.  But the length of `"$path"` will be greater than zero as long as the length of `$(resolve_link "$name" || true)` is greater than zero.

Out of curiosity, I check the length of `$(true)` in my "foo" bash script:

```
#!/usr/bin/env bash

foo="$(true)"

echo "length: ${#foo}"
```

Remember that the `#` in `${#foo}` means that we're checking for the *length* of `foo`.

Running this script, I get:

```
$ ./foo

length: 0
```

The `while` loop continuously re-sets the value of `$path` to be `resolve_link "$name"`, until the value becomes empty.  At that point, it sets the value of `$path` to the boolean `true`.  Since the length of the `true` boolean is zero (as is the length of the `false` boolean, FYI), this causes the `while` loop to exit.

It seems like the purpose of this loop is to keep `cd`ing into successive values of `path` until the value of `resolve_link` is falsy.  And as we learned earlier, the value of `resolve_link` is determined by the value of either the `greadlink` or `readlink` commands.

These commands return output if the param you pass it is a symlink pointing to another file, and don't return output if the param you pass it is a non-symlink file.

We can verify this by taking the following steps:

- create an executable file named `bar`, and place it inside a directory named `foo`.
- create a symlink to the `foo/bar` file in the same directory as the `foo` directory.  I name the symlink file `baz`.  The command for this is `ln -s foo/bar baz`.
- From the directory containing the symlink, run `readlink baz`.
- Verify that the output is `foo/bar`.
- From the same directory, run `readlink foo/bar`.
- Verify that nothing is output.
- Repeat the above `readlink` steps, but with `greadlink` instead.
- Verify the same output appears.

Here are the above steps in action:

```
$ mkdir foo

$ touch bar

$ chmod +x bar

$ ln -s foo/bar baz

$ readlink baz

foo/bar

$ readlink foo/bar

$

$ greadlink baz

foo/bar

$ greadlink foo/bar

$
```

So the purpose of the `while` link is to allow us to keep `cd`ing until we've arrived at the real, non-symlink home of the command represented by the `$name` variable (in our case, `rbenv`).  When that happens, we exit the `while` loop and run the next two lines of code:

```
pwd
cd "$cwd"
```

`pwd` stands for `print working directory`, which means we `echo` the directory we're currently sitting in.  After we `echo` that, we `cd` back into the directory we were in before we started the `while` loop.

I'm confused about why we do this.  Here are the questions I have in my head right now:

- Coming from Ruby, I'm accustomed to looking at the last statement of a function as the return value of that function.  So why is the last statement of this function a call to navigate to our original directory?
- Given that the `cd` call is the last item in our function, doesn't that make the return value of the `cd` operation also the return value of our `abs_dirname` function?
- Why do we need to print the current working directory beforehand?

At this point I started to wonder whether all these weird things were related.

I suspect that the purpose of the final call to `cd` is to undo the directory changes that we made while inside the `while` loop.  If that's true, I wonder whether the function is using `echo` to return the value output by `pwd`.

<!-- Once we've output that, we wouldn't need to be inside its canonical directory anymore, so it's best to `cd` back into where we started from.  If we didn't do this final `cd`, then calling `abs_dirname` would have an undesirable side effect- we'd be left in a different directory after calling the function, compared to where we were before calling it.

But how could the value of `pwd` be captured?  True, it's being sent to STDOUT, but that's just like `echo`'ing it to the screen.  It's not actually getting `return`ed, is it?  And at any rate, it's not the last line of code in the function, so it can't possibly be the `return` value, can it? -->

Let's test this out by writing our own function which does something similar.  I re-write my `~/foo/bar` script to look like this:

```
#!/usr/bin/env bash

function foo() {
  local currDir
  currDir="$PWD"

  cd /Users/myusername
  pwd

  cd "$currDir"
}

myVar="$(foo)";
echo "myVar: $myVar";

echo "current directory: $PWD"
```

I then create two new directories in my `~/` parent directory, named `bar` and `buzz`.  First I `cd` into `~/bar` and run `../foo/bar`.  I get:

```
$ cd ../bar
$ ../foo/bar
myVar: /Users/myusername
current directory: /Users/myusername/bar
```

Then I `cd` into `~/buzz` and repeat:

```
$ cd buzz
$ ../foo/bar
myVar: /Users/myusername
current directory: /Users/myusername/buzz
```

Then I comment out the `pwd`...

```
#!/usr/bin/env bash

function foo() {
  local currDir
  currDir="$PWD"

  cd /Users/myusername
  # pwd             # commented-out code

  cd "$currDir"
}

myVar="$(foo)";
echo "myVar: $myVar";

echo "current directory: $PWD"
```

...and re-run:

```
$ ../foo/bar
myVar:
current directory: /Users/myusername/buzz
```

OK, so `pwd` *does* in fact control what the return value of this function is.  This implies that the return value of a function in `bash` is *not necessarily* the last line of code in the function.  Instead, it appears to be dictated by what's output to STDOUT.

I un-comment the call to `pwd`, and out of curiosity, I add an `echo` statement just beforehand:

```
#!/usr/bin/env bash

function foo() {
  local currDir
  currDir="$PWD"

  cd /Users/myusername
  echo "Hello world"
  pwd

  cd "$currDir"
}

myVar="$(foo)";
echo "myVar: $myVar";

echo "current directory: $PWD"
```


When I run this, I get:

```
$ ../foo/bar
myVar: Hello world
/Users/myusername
current directory: /Users/myusername/buzz
```

So when we print both "Hello world" and the current working directory, the return value of `foo()` changes to be both the lines we printed.

My current working hypothesis is therefore that the return value of a function is the sum of all things that it `echo`s.

When I Google "bash return value of a function", the first result I see is [a blog post in LinuxJournal.com](https://web.archive.org/web/20220718223538/https://www.linuxjournal.com/content/return-values-bash-functions){:target="_blank" rel="noopener"}.  Among other things, it tells me:

- "Bash functions, unlike functions in most programming languages do not allow you to return a value to the caller.  When a bash function ends its return value is its status: zero for success, non-zero for failure."
- "To return values, you can:
  - set a global variable with the result, or
  - use command substitution, or
  - pass in the name of a variable to use as the result variable."

Let's try each of these out:

### Experiment- setting a global variable inside a function

I create a script with the following contents:

```
#!/usr/bin/env bash

foo() {
  myVarName="Hey there"
}

echo "value before: $myVarName"     # should be empty

foo

echo "value after: $myVarName"      # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before:
value after: Hey there
```

So it looks like, when we don't make a variable local inside a function, its scope does indeed become global, and we can access it outside the function.

### Experiment- using command substitution to return a value from a function

I update my script to read as follows:

```
#!/usr/bin/env bash

foo() {
  echo "Hey there"
}

echo "value before function call: $myVarName" # should be empty

myVarName=$(foo)

echo "value after function call: $myVarName" # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before function call:
value after function call: Hey there
```

So by using command substitution (aka the `"$( ... )"` syntax), we can capture anything `echo`'ed from within the function.

### Experiment- passing in the name of a variable to use

I update the script one last time to read as follows:

```
#!/usr/bin/env bash

foo() {
  local varName="$1"
  local result="Hey there"
  eval $varName="'$result'"
}

echo "value before function call: $myVarName" # should be empty

foo myVarName

echo "value after function call: $myVarName" # should be non-empty
```

When I run it, I get:

```
$ ./foo

value before function call:
value after function call: Hey there
```

Credit for these experiments goes to [the LinuxJournal link from earlier](https://www.linuxjournal.com/content/return-values-bash-functions){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
if [ -z "${RBENV_ROOT}" ]; then
  RBENV_ROOT="${HOME}/.rbenv"
else
  RBENV_ROOT="${RBENV_ROOT%/}"
fi
export RBENV_ROOT
```

We've seen the `-z` flag for `[` before- it checks whether a value has a length of zero.

So if the RBENV_ROOT variable has not been set, then we set it equal to "${HOME}/.rbenv", i.e. the ".rbenv" hidden directory located as a subdir of our UNIX home directory.  If it *has* been set, then we just trim off any trailing "/" character.  Then we export it as a environment variable.

The purpose of this code seems to be ensuring that `RBENV_ROOT` is set to some value, whether it's the value that the user specified or the default value.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
if [ -z "${RBENV_DIR}" ]; then
  RBENV_DIR="$PWD"
else
...
fi
export RBENV_DIR
```

Let's examine everything *except* the code inside the `else` block, which we'll look at next.

This block of code is similar to the block before it.  We check if a variable has not yet been set (in this case, `RBENV_DIR` instead of `RBENV_ROOT`).  If it's not yet set, then we set it equal to the current working directory.  Once we've exited the `if/else` block, we export `RBENV_DIR` as an environment variable.

Now the code inside the `else` block:

```
  [[ $RBENV_DIR == /* ]] || RBENV_DIR="$PWD/$RBENV_DIR"
  cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"
  RBENV_DIR="$PWD"
  cd "$OLDPWD"
```

The first line of code tries to execute one piece of code (`[[ $RBENV_DIR == /* ]]`), and if that fails, executes a 2nd piece (`RBENV_DIR="$PWD/$RBENV_DIR"`).  The first command it tries is a pattern-match, [according to StackExchange](https://web.archive.org/web/20220628171954/https://unix.stackexchange.com/questions/72039/whats-the-difference-between-single-and-double-equal-signs-in-shell-compari){:target="_blank" rel="noopener"}:

> `[[ $a == $b ]]` is not comparison, it's pattern matching.

The particular pattern that we're matching against returns true if `$RBENV_DIR` **starts with** the `/` character.

Hypothesizing that we're checking to see if `$RBENV_DIR` is a string that represents an absolute path, I write the following test script:

```
#!/usr/bin/env bash

foo='/foo/bar/baz'

if [[ "$foo" == /* ]]; then
  echo "True"
else
  echo "False"
fi
```

I get `True` when I run this script, and `False` when I remove the leading `/` char.  So we can confidently say that this first line of code appends the absolute path to the current working directory to the front of `RBENV_DIR`, if that variable doesn't start with a `/`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next block of code is:

```
cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"
RBENV_DIR="$PWD"
cd "$OLDPWD"
```

Here we're attempting to `cd` into our latest version of `$RBENV_DIR`, sending any error message to `/dev/null`, and aborting with a helpful error message if that `cd` attempt fails.  We then set the value of `RBENV_DIR` to the value of `$PWD` (the directory we're currently in), before `cd`ing into `OLDPWD`, an environment variable [that `bash` maintains ](https://web.archive.org/web/20220127091111/https://riptutorial.com/bash/example/16875/-oldpwd){:target="_blank" rel="noopener"} which comes with `bash` and which stores the directory we were in prior to our current one:

```
$ cd /home/user

$ mkdir directory

$ echo $PWD

/home/user

$ cd directory

$ echo $PWD

/home/user/directory

$ echo $OLDPWD

/home/user
```

I'm honestly not sure why we're doing this.  Assuming we've reached this line of code, that means we've just `cd`'ed into our current location using the same value of `$RBENV_DIR` that we currently have.  So (to me) this just seems like setting the variable's value to the value it already contains.  Given the previous `cd` command succeeded, when would the value of `$PWD` be anything different from the current value of `RBENV_DIR`?

After submitting [this PR](https://github.com/rbenv/rbenv/pull/1493){:target="_blank" rel="noopener"}, I discovered the answer.  This sequence of code is doing two things:

 - It ensures that the value we store in `RBENV_DIR` is a valid directory, by attempting to `cd` into it and aborting if this fails.
 - It [normalizes](https://web.archive.org/web/20220619163902/https://www.linux.com/training-tutorials/normalizing-path-names-bash/){:target="_blank" rel="noopener"} the value of `RBENV_DIR`, "...remov(ing) unneeded /./ and ../dir sequences."

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
export RBENV_DIR
```
Here we just make the result of our `RBENV_DIR` setting into an environment variable, so that it's available elsewhere in the codebase.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
[ -n "$RBENV_ORIG_PATH" ] || export RBENV_ORIG_PATH="$PATH"
```

Here we check if `$RBENV_ORIG_PATH` has been set yet.  If not, we set it equal to our current path and export it as an environment variable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
shopt -s nullglob
```

I've never seen the `shopt` command before.  I try looking up the docs on my machine, but I get `No manual entry for shopt` for `man` and `shopt not found` for `help`.

I try Google, and [the first result](https://web.archive.org/web/20220815163336/https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html){:target="_blank" rel="noopener"} is from GNU.org, which says:

```
shopt

shopt [-pqsu] [-o] [optname ...]

Toggle the values of settings controlling optional shell behavior.

...

-s

Enable (set) each optname.
```

[The next Google result](https://web.archive.org/web/20220714115608/https://www.computerhope.com/unix/bash/shopt.htm){:target="_blank" rel="noopener"}, from ComputerHope.com, adds the following:

> On Unix-like operating systems, shopt is a builtin command of the Bash shell that enables or disables options for the current shell session.

It adds that the job of the `-s` flag is:

> If optnames are specified, set those options. If no optnames are specified, list all options that are currently set.

The option name that we're passing is `nullglob`.  Further down, in the descriptions of the various options, I see the following entry for `nullglob`:

> If set, bash allows patterns which match no files to expand to a null string, rather than themselves.

Lastly, [StackExchange](https://unix.stackexchange.com/a/504591/142469){:target="_blank" rel="noopener"} has an example of what would happen before and after `nullglob` is set:

> Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.
>
> ```
> $ echo my*file
> my*file
> $ shopt -s nullglob
> $ echo my*file
>
> $
> ```

This code sets a shell option so that we can change the way we pattern-match against files.  In particular, if a pattern doesn't match any files, it will expand to nothing.  This indicates that we'll be attempting to match files against a pattern in the near future.

To figure out why we're doing this, I dig into the git history using my `git blame / git checkout` dance again.  There's only one issue and one commit.  [Here's the issue](https://github.com/rbenv/rbenv/pull/102){:target="_blank" rel="noopener"} with its description:

> The purpose of this branch is to provide a way to install self-contained plugin bundles into the $RBENV_ROOT/plugins directory without any additional configuration. These plugin bundles make use of existing conventions for providing rbenv commands and hooking into core commands.
>
> ...
>
> Say you have a plugin named foo. It provides an `rbenv foo` command and hooks into the `rbenv exec` and `rbenv which` core commands. Its plugin bundle directory structure would be as follows:
>
>```
>foo/
>  bin/
>    rbenv-foo
>  etc/
>    rbenv.d/
>      exec/
>        foo.bash
>      which/
>        foo.bash
>```
>
> When the plugin bundle directory is installed into `~/.rbenv/plugins`, the `rbenv` command will automatically add `~/.rbenv/plugins/foo/bin` to `$PATH` and `~/.rbenv/plugins/foo/etc/rbenv.d/exec:~/.rbenv/plugins/foo/etc/rbenv.d/which` to `$RBENV_HOOK_PATH`.

I think this clarifies not only the `shopt` line, but the next few lines after that:

```
shopt -s nullglob

bin_path="$(abs_dirname "$0")"
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
export PATH="${bin_path}:${PATH}"
```

Let's address these two lines first:

```
bin_path="$(abs_dirname "$0")"
...
export PATH="${bin_path}:${PATH}"
```

On my machine, `bin_path` resolves to `/Users/myusername/.rbenv/libexec` when I `echo` it to the screen.  By adding this path to our `PATH` variable, we're implying that one or more files inside `/libexec` should be executable, since (I believe) that's what the `PATH` directory is for.

The `libexec/` folder contains both the file we're looking at now (`rbenv`) and the other rbenv command files (`libexec/rbenv-version`, `libexec/rbenv-help`, etc.).  Skipping ahead to the end of the file, I suspect the reason we're adding `libexec/` to `PATH` is because, later on, we call [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L127){:target="_blank" rel="noopener"}:

```
exec "$command_path" "$@"
```

I added an `echo` statement to this line of code, so I can tell you that `$command_path` resolves to the filename of the command you pass to `rbenv`.  For example, if you run `rbenv help` in your terminal, then `$command_path` resolves to `rbenv-help`.  And when we `exec rbenv-help`, we're able to run that file, since `libexec/` is now in our `PATH`.

Now onto the middle part of the above code, the `for` loop:

```
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
```

[The above Github issue](https://github.com/rbenv/rbenv/pull/102){:target="_blank" rel="noopener"} posited a world where we have an RBENV plugin named `foo`.  It exposes a command named `rbenv foo`.  When the GH issues says:

```
...the `rbenv` command will automatically add `~/.rbenv/plugins/foo/bin` to `$PATH`...
```

...it's telling us that this process (and any child processes) will be able to call `rbenv-foo`, because the `rbenv-foo` file is located in `~/.rbenv/plugins/foo/bin`, a folder which is now being added to `PATH`.

Since this takes place inside a `for` loop which iterates over the contents of `"${RBENV_ROOT}/plugins/"*/bin;`, this is true for any plugins which are installed within `"${RBENV_ROOT}/plugins/"`.

And the reason for `shopt -s nullglob`?  Remember what the StackExchange post said:

```
Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.
```

I suspect that, with the `nullglob` option turned on, the pattern `"${RBENV_ROOT}/plugins/"*/bin;` expands to nothing **if no plugins are installed**.  So turning this option on means our `for` loop will iterate 0 times if the `plugins/` directory is empty.

I decide to do an experiment to see if I'm right.

### Experiment- testing the behavior of `nullglob`

I write a script to try and emulate what we see in the `for` loop above:

```
#!/usr/bin/env bash

for plugin_dir in "$PWD"/foo/*; do
  echo "plugin_dir: $plugin_dir"
done
```

When I create a directory with a few subdirectories and run this test script, I get:

```
$ mkdir foo
$ mkdir foo/bar
$ mkdir foo/baz
$ mkdir foo/buzz
$ ./script
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/bar
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/baz
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/buzz
```

So far, that's what I expected.  But what if there are no directories?  I delete the three sub-directories and re-run it:

```
$ rm -r foo/bar
$ rm -r foo/baz
$ rm -r foo/buzz
$ ./script
plugin_dir: /Users/myusername/Workspace/OpenSource/foo/*
```

OK, this makes sense, given that I didn't run that `shopt` line first.  If I add that to my script:

```
#!/usr/bin/env bash

shopt -s nullglob

for plugin_dir in "$PWD"/foo/*; do
  echo "plugin_dir: $plugin_dir"
done
```

...and re-run it, I get:

```
$ ./script

```

No output when `shopt -s nullglob` is set.  Based on this experiment, I think we can safely say that our hypothesis is correct.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

This appears to add `${RBENV_ROOT}/rbenv.d` to the end of the current value of `RBENV_HOOK_PATH`.  But what is "${RBENV_ROOT}/rbenv.d"?  I run `find . -name rbenv.d` and get:

```
$ find . -name rbenv.d
./rbenv/rbenv.d
```

I inspect it, and see that it's a directory, containing a directory named `exec`:

```
$ ls -la rbenv/rbenv.d
total 0
drwxr-xr-x   3 myusername  staff   96 Sep  5 15:47 .
drwxr-xr-x  15 myusername  staff  480 Sep  5 09:13 ..
drwxr-xr-x   4 myusername  staff  128 Sep  4 10:13 exec
```

The `exec` directory, in turn contains the following:

```
$ ls -la rbenv/rbenv.d/exec
total 8
drwxr-xr-x  4 myusername  staff  128 Sep  4 10:13 .
drwxr-xr-x  3 myusername  staff   96 Sep  5 15:47 ..
drwxr-xr-x  3 myusername  staff   96 Sep  4 10:13 gem-rehash
-rw-r--r--  1 myusername  staff   47 Sep  4 10:13 gem-rehash.bash
```
And the `gem-rehash` directory contains the following:

```
$ ls -la rbenv/rbenv.d/exec/gem-rehash
total 8
drwxr-xr-x  3 myusername  staff    96 Sep  4 10:13 .
drwxr-xr-x  4 myusername  staff   128 Sep  4 10:13 ..
-rw-r--r--  1 myusername  staff  1427 Sep  4 10:13 rubygems_plugin.rb
```

I Google "gem-rehash", and the first thing I find is [this deprecated Github repo](https://github.com/rbenv/rbenv-gem-rehash){:target="_blank" rel="noopener"}.  The description says:

> Never run rbenv rehash again. This rbenv plugin automatically runs rbenv rehash every time you install or uninstall a gem.
>
> This plugin is deprecated since its behavior is now included in rbenv core.

I notice that:

 - The deprecated repo contains a file named `rubygems_plugin.rb`, just like our `rbenv/rbenv.d/exec/gem-rehash` directory does.
 - The deprecated repo contains a file named `etc/rbenv.d/exec/~gem-rehash.bash`, which is very similar (but not identical) to the `rbenv.d/exec/gem-rehash.bash` file that we saw in the RBENV repo above.

In the `rbenv-gem-rehash` README file, I also see the following:

> rbenv-gem-rehash consists of two parts: a RubyGems plugin and an rbenv plugin.
>
> The RubyGems plugin hooks into the gem install and gem uninstall commands to run rbenv rehash afterwards, ensuring newly installed gem executables are visible to rbenv.
>
> The rbenv plugin is responsible for making the RubyGems plugin visible to RubyGems. It hooks into the rbenv exec command that rbenv's shims use to invoke Ruby programs and configures the environment so that RubyGems can discover the plugin.

Based on this, I think we can now determine the reason for this line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```

The reason is that we don't want to re-run the `rbenv rehash` command every time we install a new Ruby gem.  We want RBENV to do that for us, automatically.  The way it does that is by hooking into the Rubygems `gem install` and `gem uninstall` commands.  And the way it hooks in is by updating `RBENV_HOOK_PATH`.

### The `.d` extension

We've seen `rbenv.d` a few times now, and I thought the `.d` looked funny.  It looks like a file extension, but it's being used on a directory.  Furthermore, I don't know what I'm supposed to infer from that `.d`.

I Google 'what does ".d" stand for bash', and the first result I see is ([this](https://web.archive.org/web/20220619172419/https://unix.stackexchange.com/questions/4029/what-does-the-d-stand-for-in-directory-names){:target="_blank" rel="noopener"}:

> The .d suffix here means directory. Of course, this would be unnecessary as Unix doesn't require a suffix to denote a file type but in that specific case, something was necessary to disambiguate the commands (/etc/init, /etc/rc0, /etc/rc1 and so on) and the directories they use (/etc/init.d, /etc/rc0.d, /etc/rc1.d, ...)
>
> This convention was introduced at least with Unix System V but possibly earlier.

Another answer from that same post:

> Generally when you see that *.d convention, it means "this is a directory holding a bunch of configuration fragments which will be merged together into configuration for some service."

OK, I think I see now.  So the `.d` suffix means:

- This is a directory containing configuration files.
- These files are meant to be bundled up together into a single aggregate configuration file.
- This file likely has the same name as the directory.

Does this jive with what we see in the RBENV folders?

### Do the files within these directories count as configuration files?

If we refer back to what we read in the "How It Works" section of the `rbenv-gem-rehash` readme, we saw that "rbenv-gem-rehash consists of two parts: a RubyGems plugin and an rbenv plugin."  It seems like a safe bet that the "RubyGems plugin" part corresponds to the file `rubygems_plugin.rb`, and I would bet money that the `rbenv plugin` part corresponds to the `rbenv-gem-rehash/etc/rbenv.d/exec/~gem-rehash.bash` part.

If we look at that file, it's pretty short, containing only the following:

```
# Remember the current directory, then change to the plugin's root.
cwd="$PWD"
cd "${BASH_SOURCE%/*}/../../.."

# Make sure `rubygems_plugin.rb` is discovered by RubyGems by adding
# its directory to Ruby's load path.
export RUBYLIB="$PWD:$RUBYLIB"

cd "$cwd"
```

It looks like all this file does is prepend the root `rbenv-gem-rehash` folder to the `RUBYLIB` environment variable and export it.  And judging by the comments above the `export` statement, `RUBYLIB` sounds a Ruby-specific equivalent to `PATH`, which we've already learned about.

Googling `RUBYLIB`, I find [an excerpt of a book](https://web.archive.org/web/20220831132623/https://www.oreilly.com/library/view/ruby-in-a/0596002149/ch02s02.html){:target="_blank" rel="noopener"} written by Yukihiro Matsumoto (aka Matz), the creator of Ruby:

> In addition to using arguments and options on the command line, the Ruby interpreter uses the following environment variables to control its behavior.  The ENV object contains a list of current environment variables.
>
> ...
>
> RUBYLIB
>
> Search path for libraries. Separate each path with a colon (semicolon in DOS and Windows).

So `RUBYLIB` helps Ruby search for libraries.  Sounds like we were right about that.

To summarize, the files inside `rbenv.d` help ensure that we can automatically run `rbenv rehash` whenever we install or uninstall Ruby gems.  That sounds more like configuration logic to me, rather than application logic (which I would define as logic which a user would invoke directly, like a command such as `rbenv version`).

### Are the files in these directories being merged together somehow?

Well, neither the RBENV nor the `rbenv-gem-rehash` READMEs mention any "merging of configuration files".  And so far, we've only seen these directories being added to `PATH` or the `RBENV_HOOK_PATH` env vars.  Perhaps we will see these files being merged later, but also, perhaps not.

### Is there a file with the same name as the `rbenv.d` directory?

As a matter of fact, yes- it's the one we're currently reading!

Having thoroughly examined this block of code, let's mode onto the next one.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next block of code is:

```
if [ "${bin_path%/*}" != "$RBENV_ROOT" ]; then
  # Add rbenv's own `rbenv.d` unless rbenv was cloned to RBENV_ROOT
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${bin_path%/*}/rbenv.d"
fi
```

Based on the comment and the logic of the test in the `if` statement, we can conclude that `"${bin_path%/*}"` would equal `"$RBENV_ROOT"` if "rbenv was cloned to `RBENV_ROOT`".  But I'm not sure under what circumstances rbenv would be "cloned to `RBENV_ROOT`".

As you may recall, `bin_path` resolves to `/Users/myusername/.rbenv/libexec` on my machine, so `"${bin_path%/*}"` will resolve to `/Users/myusername/.rbenv` when the `%/*` bit of the parameter expansion does its job and removes the final `/` and anything after it.  When I add another `echo` statement here, I see that `RBENV_ROOT` resolves to the same path- `/Users/myusername/.rbenv`.  So these two paths are equal for me, and I won't reach the code inside the `if` check.

When *would* someone reach that code?  Apparently, when "rbenv was cloned to RBENV_ROOT".  I'm not sure what that means, but I know that `[ "${bin_path%/*}" != "$RBENV_ROOT" ]` would have to be false in order for us to reach that code.  And this test would be false if we passed in a different value for `RBENV_ROOT` when running our code, i.e. `RBENV_ROOT="~/my/other/directory/rbenv" rbenv version`.  You might do this if, for example, you pulled down the RBENV code from Github into a project directory, and wanted to run a command with `RBENV_ROOT` set to that directory.  But then why wouldn't `bin_path` *also* get updated?

Taking a step back, I know that this `if` block was added as part of [this PR](https://github.com/rbenv/rbenv/pull/638){:target="_blank" rel="noopener"}, which was the PR responsible for bringing in the `gem-rehash` logic into RBENV core.  Therefore, we can probably assume that this logic was part of that effort.  So how does this `if` block fit into the effort to bring `gem-rehash` into core?

I don't see it.  I may have to punt on this question until later.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on to the next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
```
This just means we're further updating RBENV_HOOK_PATH to include more `rbenv.d` directories, including those inside `/usr/local/etc`, `/etc`, and `/usr/lib/`.  These directories may or may not even exist on the user's machine (for example, I don't currently have a `/usr/local/etc/rbenv.d` directory on mine).  They're just directories where the user *might* have installed additional hooks.

Why these specific directories?  They appear to be a part of a convention known as the [Filesystem Hierarchy Standard](https://web.archive.org/web/20230326013203/https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard){:target="_blank" rel="noopener"}, or the conventional layout of directories on a UNIX system.  Using this convention means that developers on UNIX machines can trust that the files they're looking for are likely to live in certain places.

For example, the two main directories we're using in this line of code are `/usr/` and `/etc/`.  The FHS describes these directories as follows:

 - `/etc/`- "Host-specific system-wide configuration files."
 - `/usr/`- "Secondary hierarchy for read-only user data; contains the majority of (multi-)user utilities and applications. Should be shareable and read-only."
    - `/usr/local/`- "Tertiary hierarchy for local data, specific to this host. Typically has further subdirectories (e.g., bin, lib, share)."
    - `/usr/lib/`- "Libraries for the binaries in /usr/bin and /usr/sbin."

Honestly, the above is a bit too abstract for me.  I did find [this link](https://archive.is/hXKpL){:target="_blank" rel="noopener"} which has more concrete examples.  It mentions that it refers to the FHS for Linux, not for UNIX, but [this StackOverflow post](https://web.archive.org/web/20150928165243/http://unix.stackexchange.com/questions/98751/is-the-filesystem-hierarchy-standard-a-unix-standard-or-a-gnu-linux-standard/){:target="_blank" rel="noopener"} says that both Linux and UNIX follow the same FHS, so I think we're OK.  The site says these directories might contain the following types of files:

#### /etc

 - the name of your device
 - password files
 - network configuration
 - DNS configuration
 - crontab configuration
 - date and time configuration

It also notes that `/etc` should only contain static files; no executable / binary files allowed.

#### /usr

> Over time, this directory has been fashioned to store the binaries and libraries for the applications that are installed by the user. So for example, while bash is in /bin (since it can be used by all users) and fdisk is in /sbin (since it should only be used by administrators), user-installed applications like vlc are in /usr/bin.

##### /usr/lib

> This contains the essential libraries for packages in /usr/bin and /usr/sbin just like /lib.

##### /usr/local

> This is used for all packages which are compiled manually from the source by the system administrator.
This directory has its own hierarchy with all the bin, sbin and lib folders which contain the binaries and applications of the compiled software.

In summary, though I can't yet quote chapter-and-verse of what each folder's purpose is on a UNIX machine, for now it's enough to know that there's a concept called the Filesystem Hierarchy Standard, and that it specifies the purposes of the different folders in your UNIX system.  I can always refer to the official docs if I need to look up this information.  The homepage of the standard is [here](https://www.pathname.com/fhs/){:target="_blank" rel="noopener"}, and the document containing the standard is [here](https://www.pathname.com/fhs/pub/fhs-2.3.pdf){:target="_blank" rel="noopener"}.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
for plugin_hook in "${RBENV_ROOT}/plugins/"*/etc/rbenv.d; do
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${plugin_hook}"
done
```

In an earlier `for` loop, we updated the `PATH` variable to include any executables which were provided by any RBENV hooks that we've installed.  This was so that we could run that hook's commands from our terminal.

Here, we appear to be telling RBENV which hooks the user has installed.  This is not so that we can run that hook's commands, but so that a hook's logic will be executed when we run an *RBENV* command.  By adding a path to `RBENV_HOOK_PATHS`, we give an RBENV command another directory to search through when that command executes its hooks.

We're skipping ahead a bit, but [here is an example](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L12){:target="_blank" rel="noopener"} of that process in action.  The `version-name` command calls `rbenv-hooks version-name`, which internally relies on the `RBENV_HOOKS_PATH` variable to print out a list of hooks for (in this case) the `version-name` command.  For each of those paths, we look for any `.bash` scripts, and then we run `source` on each of those scripts, so that those scripts are executed in our current shell environment.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH#:}"
export RBENV_HOOK_PATH
```

This syntax is definitely parameter expansion, but I haven't seen the `#:` syntax before.  I don't know if `#:` is a specific command in parameter expansion (like `:+` or similar), or if `:` is a character that we're performing the `#` operation on.

I search [the GNU docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html){:target="_blank" rel="noopener"} for `#:`, since it looks like a specific kind of expansion pattern, but I don't see those two characters used together anywhere in the docs.  Maybe it's just the `#` pattern we've seen before, for instance when we saw `parameter#/*`?  In that case, we were removing any leading `/` character from the start of the parameter.  Maybe here we're doing the same, but with the `:` character instead?

As an experiment, I update my test script to read as follows:

```
#!/usr/bin/env bash

FOO='foo:bar/baz/buzz:quox'

echo "${FOO#:}"
```

When I run it, I see:

```
$ ./bar
foo:bar/baz/buzz:quox
```

Nothing has changed- the output is the same as the input.

When I update FOO to add a `:` at the beginning (i.e. ':foo:bar/baz/buzz:quox'), and I re-run the script, I see:

```
$ ./bar
foo:bar/baz/buzz:quox
```

The leading `:` character has been removed.  So yes, it looks like our hypothesis was correct, and that the parameter expansion is just removing any leading `:` symbol from `RBENV_HOOK_PATH`.

The last line of code in this block is just us `export`ing the `RBENV_HOOK_PATH` variable, so that it can be used by child processes.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code is:

```
shopt -u nullglob
```

This just turns off the `nullglob` option in our shell that we turned on before we started adding plugin configurations.  This is a cleanup step, not too surprising to see it here.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next few lines of code:

```
command="$1"
case "$command" in
...
esac
```

Here's where we get to the meat of this file.  We're grabbing the first argument sent to the `rbenv` command, and we're deciding what to do with it via a `case` statement.  Everything else we've done in this file, from loading plugins to setting up helper functions like `abort`, has led us to this point.  The internals of that case statement will dictate how RBENV responds to the command the user has entered.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Let's take each branch of the `case` statement in turn:

```
"" )
  { rbenv---version
    rbenv-help
  } | abort
  ;;
```


We've seen the `)` closing parenthesis syntax before.  It denotes a specific case in the case statement.  If the value of `$command` matches our case, then we do what's in the curly braces, and we pipe that output to the `abort` command that we defined earlier in this file.

The `""` before the `)` character is the specific case we're dealing with.  This branch of the case statement will execute if `$command` matches the empty string (i.e. if the user just types `rbenv` by itself, with no args).  The code we execute in that scenario is that we call the `rbenv—version` and `rbenv-help` scripts.

Again, the output of those two commands gets piped to the `abort` command, which will send the output to `stderr` and return a non-zero exit code, which implies that calling `rbenv` with no args is a failure mode of this command.

If we go into our terminal and type `rbenv` with no args, we see this happen.  The version number prints out, followed by info on how the `rbenv` command is used (its syntax and its possible arguments).  If we then type `echo "$?"` immediately after that to print the last exit status, we see `1` print out.

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

$ echo "$?"

1
```

Pretty straight-forward.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next case branch is:

```
-v | --version )
  exec rbenv---version
  ;;
```

This time we're comparing `$command` against two values instead of just one: `-v` or `--version`.  If it matches either pattern, we `exec` the `rbenv---version` script, which is just a one-line output of (in my case) "rbenv 1.2.0":

```
 $ rbenv -v

rbenv 1.2.0-16-gc4395e5

$ rbenv --version

rbenv 1.2.0-16-gc4395e5
```

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next case branch is:

```
-h | --help )
  exec rbenv-help
  ;;
```
Again, two patterns to match against.  If the user types `rbenv -h` or `rbenv –help`, we just run the `rbenv-help` script:

```
$ rbenv -h

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

Again, no real surprises here.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next up is:

```
* )
...;;
```

The `* )` line is the catch-all / default case branch.  Any `rbenv` command that wasn't captured by the previous branches will be captured by this branch.  How we handle that is determined by what's inside the branch, starting with the next line:

```
  command_path="$(command -v "rbenv-$command" || true)"
```
Here we're declaring a variable called `command_path`, and setting its value equal to the result of a response from a command substitution.  That command substitution is **either**:

 - the result of `command -v "rbenv-$command"`, or (if that result is a falsy value)
 - the simple boolean value `true`.

The value of the command substitution depends on what `command -v "rbenv-$command` evaluates to.  It's a bit confusing to parse because `command` is the name of a shell builtin, but `$command` is the name of a shell variable that we declared earlier.

If we run `help command` to see what this shell builtin does, we get:

```
bash-3.2$ help command

command: command [-pVv] command [arg ...]
    Runs COMMAND with ARGS ignoring shell functions.  If you have a shell
    function called `ls', and you wish to call the command `ls', you can
    say "command ls".  If the -p option is given, a default value is used
    for PATH that is guaranteed to find all of the standard utilities.  If
    the -V or -v option is given, a string is printed describing COMMAND.
    The -V option produces a more verbose description.
```

So calling `command ls` is the same as calling `ls`.  I could see this being useful if the command you want to run is stored in a variable, and is dynamically set.  For example:

```
$ myCommand="pwd"

$ if [ "$myCommand" = "pwd" ]; then
> command "$myCommand"
> fi

/Users/myusername/Workspace/OpenSource/rbenv
```

As the `help` description mentions, adding the `-v` flag results in a printed description of the command you're running.  When I pass `-v` to `command ls` in my terminal, I see `/bin/ls` *instead of* the regular output of the `ls` command.  Therefore, the path to the `$command` will end up being the string that we store in the variable named `command_path`.

That is, unless no such path exists, in which case we'll store the boolean `true` instead.  Recall from earlier that passing a boolean to a command substitution results in a response with a length of zero.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That knowledge is useful when interpreting our next line of code:

```
if [ -z "$command_path" ]; then
...
fi
```

In other words, if the user's input doesn't correspond to an actual command path, then we execute the code inside this `if` block.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That code is:

```
if [ "$command" == "shell" ]; then
  abort "shell integration not enabled. Run \`rbenv init' for instructions."
else
  abort "no such command \`$command'"
fi
```

So if the user's input was the string "shell", then we abort with one error message ("shell integration not enabled. Run \`rbenv init' for instructions.").

We would reach this branch if we tried to run `rbenv shell` before adding `eval "$(rbenv init - bash)"` to our `~/.bashrc` config file (if we're using `bash` as a shell) or `eval "$(rbenv init - zsh)"` to our `~/.zshrc` file (if we're using `zsh` as a shell).  In this case, `$command_path` would be empty.

On my machine, I have the above `rbenv init` command added to my `~/.zshrc` file, so I can't reproduce this error in `zsh`.  I don't have the equivalent line added to my `~/.bashrc` file, however, so if I open up a `bash` shell and type `rbenv shell`, I get the following:

```
bash-3.2$ rbenv shell

rbenv: shell integration not enabled. Run `rbenv init' for instructions.
```

We'll get to why `$command_path` has a value in my `zsh` and no value in my `bash` later, when we examine the `rbenv-init` file in detail.

In our `else` clause (i.e. if `$command` does *not* equal `"shell"`), we abort with a `no such command` error.  I'm able to reproduce the `else` case by simply running `rbenv foobar` in my terminal.

```
bash-3.2$ rbenv foobar

rbenv: no such command `foobar'
```

So to sum up this entire `if` block- its purpose appears to be to handle any sad-path cases, specifically:

 - if the user enters a command that isn't recognized by RBENV, or
 - if the user tries to run `rbenv shell` without having enabled shell integration by adding the right code to their shell's configuration file.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Moving on to the next line of code:

```
shift 1
```
This just shifts the first argument off the list of `rbenv`'s arguments.  The argument we're removing was previously stored in the `command` variable, and we've already processed it so we don't need it anymore.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next line of code:

```
if [ "$1" = --help ]; then
  ...
else
  ...
fi
;;
```
Now that we've shifted off the `command` argument in the previous line, we have a new value for `$1`.  Here we check whether that new first arg is equal to the string `--help`.  An example of this would be if the user runs `rbenv init --help`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next block of code:

```
if [[ "$command" == "sh-"* ]]; then
  echo "rbenv help \"$command\""
else
  exec rbenv-help "$command"
fi
```

In the first half of this nested conditional, we check whether the user entered a command which starts with "sh-".  If they did, **and** if they followed that command with `--help`, then we print "rbenv help "$command" to STDOUT.

I try this in my terminal by typing "rbenv sh-shell –help", and I see the following:

```
$ rbenv sh-shell --help

rbenv help "sh-shell"
```

Why would we print **this** to the screen?  At this point we know enough to tell the user which command they *should have* run.  Why don't we just run it for them and save them a step?

I find [the PR which added this block of code](https://github.com/rbenv/rbenv/pull/914){:target="_blank" rel="noopener"} and read up on it.  Turns out the code used to look like this:

```
if [ "$1" = --help ]; then
  exec rbenv-help "$command"
else
  exec "$command_path" "$@"
fi
```

This is much closer to what I'd expect.  But according to the PR description, this caused the `rbenv shell --help` command to trigger an error.  I check out the commit just before this PR was merged and try to reproduce the error:

```
$ rbenv shell --help

(eval):2: parse error near `\n'
```

OK, so what caused this error?

I remember we have the ability to run in verbose mode by passing in the `RBENV_DEBUG` environment variable, so I try running `RBENV_DEBUG=1 rbenv shell --help`.  It results in a ton of output of course, and the last few lines of that output are:

```
...
+ [rbenv-help:124] echo
+ [rbenv-help:125] echo 'Sets a shell-specific Ruby version by setting the `RBENV_VERSION'\''
environment variable in your shell. This version overrides local
application-specific versions and the global version.

<version> should be a string matching a Ruby version known to rbenv.
The special version string `system'\'' will use your default system Ruby.
Run `rbenv versions'\'' for a list of available Ruby versions.'
+ [rbenv-help:126] echo
(eval):2: parse error near `\n'
```

Here we can see the lines of code that are reached (`rbenv-help:124`, `rbenv-help:125`, and `rbenv-help:126`).

For comparison, I run this same command but with `rbenv version` instead of `rbenv shell`, and the last few lines of the verbose output are:

```
...
+ [rbenv-help:124] echo

+ [rbenv-help:125] echo 'Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'\''.'
Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
+ [rbenv-help:126] echo
```

The same lines of code are logged, but no `(eval):2` error at the end.  So I **think** the problem must be in the code that we're trying to `eval`, i.e. `exec rbenv-help "$command"`.

I wanted to see what exactly this code was.  So I added the following `echo` statement above it:

```
if [ "$1" = --help ]; then
  echo "$(rbenv-help "$command")" >&2
  echo "----------" >&2
  exec rbenv-help "$command"
else
```

I'm capturing the output of the same command that we're trying to `exec`, sending it to `echo`, and redirecting `stdout` to `stderr` so that my `echo` statement won't interfere with anything else that's going on in the code.  I also `echo` a divider line, so we can know where my printed statements end and the code takes over again.

Here's the result when I run `rbenv shell --help`:

```
$ rbenv shell --help

Usage: rbenv shell <version>
       rbenv shell --unset

Sets a shell-specific Ruby version by setting the `RBENV_VERSION'
environment variable in your shell. This version overrides local
application-specific versions and the global version.

<version> should be a string matching a Ruby version known to rbenv.
The special version string `system' will use your default system Ruby.
Run `rbenv versions' for a list of available Ruby versions.
----------
(eval):2: parse error near `\n'
```

OK, so we're trying to `exec` a printed set of usage instructions which are meant for humans to read (not for `bash` to run).  But this error only happened with `rbenv shell`, not with `rbenv version`.

What if I capture the output from `rbenv version` instead?  Does it also print out usage instructions?

```
$ rbenv version --help
Usage: rbenv version

Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
Usage: rbenv version

Shows the currently selected Ruby version and how it was
selected. To obtain only the version string, use `rbenv
version-name'.
```

Yep, `"$(rbenv-help $command)"` evaluates to the usage instructions for `version`, just like it did with `shell`.  So why is it trying to `eval` usage instructions for `shell`, but not `version`?  We know from [the PR diff](https://github.com/rbenv/rbenv/pull/914/files){:target="_blank" rel="noopener"} that the solution was to treat commands that are prefixed with `sh-` differently.  Where is this happening?

OK, I'll stop here and admit that I cheated a little.  I initially was stumped by this question, so I decided to punt on it for the time being and continued onward.  Then, months later when I was re-reading and editing this post, I went back with the knowledge I had gained reading the other files in this repo and leveraged that knowledge to deduce what is happening here.

TL;DR- one of the things that RBENV does when you add that `eval "$(rbenv init -)"` string to your shell config is that it creates a shell function (also called `rbenv`).  When you run `rbenv` commands from inside your terminal, you're **not** running the `rbenv` bash script, at least not directly.  Instead, you're **actually** running *this shell function*, which in turn calls the `rbenv` shell script.  You can verify this by running `which rbenv` from your terminal:

```
$ which rbenv

rbenv () {
	local command
	command="$1"
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	case "$command" in
		(rehash | shell) eval "$(rbenv "sh-$command" "$@")" ;;
		(*) command rbenv "$command" "$@" ;;
	esac
}
```

Instead of printing `path/to/file/rbenv.bash` or something similar, it prints out a complete shell function.  It's this shell function that gets defined by the `eval "$(rbenv init -)"` call in your shell config every time you open a new terminal tab.  Since UNIX will check for shell functions before it checks your `PATH` for any commands, this is the first implementation of the `rbenv` command that it finds, and so this is what gets run when you type `rbenv` into your terminal.

As part of its logic, the shell function executes [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-init#L147-L152){:target="_blank" rel="noopener"}, which checks if the command that the user is running begins with `sh-`.  If it does, it runs `eval` plus the name of the command with its `sh-` prefix.  Otherwise, it runs the command via the `command` command (which we discussed earlier).

It's **this** call to `eval` that is erroring out.  We can prove that to ourselves by changing that block of code in `rbenv-init` to look like the following:

```
set -e
  case "\$command" in
  ${commands[*]})
    echo 'just before eval' >&2
    eval "\$(rbenv "sh-\$command" "\$@")"
    echo 'just after eval' >&2
    ;;
  *)
```

I added the call to `set -e` before the `case` statement (so that the code will exit immediately if the `eval` code throws an error), as well as the two `echo` statements, one before `eval` and one after.  I then `source` my `~/.zshrc` file so that these changes take effect, and I run `which rbenv` to confirm that they appear in the updated shell function:

```
$ which rbenv

rbenv () {
	local command
	command="$1"
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	set -e
	case "$command" in
		(rehash | shell) echo 'just before eval' >&2
			eval "$(rbenv "sh-$command" "$@")"
			echo 'just after eval' >&2 ;;
		(*) command rbenv "$command" "$@" ;;
	esac
}
```

Then, when I run `rbenv shell --help`, I see the following:

```
$ rbenv shell --help

just before eval
(eval):2: parse error near `\n'

[Process completed]
```

I see "just before eval", but **not** "just after eval".  Since we added the `set -e` option to our shell function, the code exited after the first error that it encountered.  Since we only saw the first of the two `echo` statements immediately before and after our call to `eval`, it **must** have been this call to `eval` which threw an error.

Now it's starting to make sense why the PR author structured their code the way they did.  Since all `sh-` scripts will be treated the same way by this `case` statement,

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next (and final!) line of code in this file:

```
  else
    exec "$command_path" "$@"
```

This is the line of code which actually executes the command that the user typed.  The `$@` syntax expands into [the flags or arguments](https://web.archive.org/web/20230319115333/https://stackoverflow.com/questions/3898665/what-is-in-bash){:target="_blank" rel="noopener"} we pass to that command.

That's it!  That's the entire `rbenv` file.  What should we do next?

Normally I'd want to copy the order in which the files appear in the "libexec" directory.  But given what we saw with "rbenv-init" and how it has a big effect on how the "rbenv" file is called, I think it makes more sense to start there and come back to the next file ("rbenv–-version") afterward.
