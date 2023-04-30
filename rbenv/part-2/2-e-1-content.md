Before reading the code for each command, we'll start by looking at the command's tests.  In the spirit of ["tests as executable documentation"](https://web.archive.org/web/20230321145910/https://subscription.packtpub.com/book/application-development/9781788836111/1/ch01lvl1sec13/executable-documentation){:target="_blank" rel="noopener"}, reading the tests first should give us a sense of what the expected behavior is.  The test file for the `rbenv` command is located [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/rbenv.bats){:target="_blank" rel="noopener"}.

## The `BATS` test framework

The first line of code is:

```
#!/usr/bin/env bats
```

This is a shebang, which we've seen before.  But importantly, it's not a `bash` shebang.  Instead, it's a `bats` shebang.  [BATS is a test-runner program](https://github.com/sstephenson/bats){:target="_blank" rel="noopener"} that Sam Stephenson (the original author of RBENV) wrote, and it's used here as RBENV's test framework.  But it's not RBENV-specific.  In theory, you could use it to test any shell script.

### Experiment: running the BATS tests

To run these tests, we'll need to install `bats` first.  The installation instructions are [here](https://github.com/sstephenson/bats#installing-bats-from-source){:target="_blank" rel="noopener"}.  You'll know the installation was successful if you can run `which bats` and a filepath appears, like this:

```
$ which bats

/usr/local/bin/bats
```

Note that I used Homebrew to install `bats` on my machine.  If you used another technique, your filepath may look different from mine.

Once that's done, we can navigate to the home directory of our cloned RBENV codebase, and run the following:

```
$ cd ~/Workspace/OpenSource/rbenv/test/

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
```

They all pass, as we'd expect since we haven't (yet) done anything which breaks the code.

## Loading helper code

Next line of code:

```
load test_helper
```

This `load` function is defined in [this block of code](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L32){:target="_blank" rel="noopener"} in the `bats` repo.

Examining this function's internals is beyond the scope of this guide (although it would make a great exercise for the reader).  For now, let's just say that the `load` function does what it says on the tin- it loads a given file so that its contents are available to the test suite we're looking at.

In this line of code, we're loading a helper file called `test_helper`, which lives [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash){:target="_blank" rel="noopener"}.  Loading `test_helper` does lots of things for us that help our tests run, such as:

- [updating the value of `PATH`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L22){:target="_blank" rel="noopener"} to include the `rbenv` commands that we want to test.
- `export`ing the [environment variables](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L18){:target="_blank" rel="noopener"} that we'll need for those commands to run, such as `RBENV_ROOT`, `RBENV_HOOK_PATH`, `HOME`, and `RBENV_TEST_DIR`.
- giving us access to helper functions that let us run those commands and assert that the results succeeded or failed.  For example:
  - [`teardown`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L33){:target="_blank" rel="noopener"}- cleans up the effects of our tests.
  - [`flunk`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L37){:target="_blank" rel="noopener"}- causes the test to exit with a non-zero exit code (i.e. the test fails), along with printing an error message.
  - [`assert_success`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L45){:target="_blank" rel="noopener"}- checks that the last command completed successfully, and (optionally) that the expected output of the command matched the actual output.
  - [`assert_failure`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L53){:target="_blank" rel="noopener"}- the opposite of `assert_success`.  Checks that the last command did **not** complete successfully.  This is useful in testing what happens when a command is used improperly.
  - [`assert_equal`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L61){:target="_blank" rel="noopener"}- checks that two values match.
  - [`assert_output`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L69){:target="_blank" rel="noopener"}- checks that the output of the most-recently-run command matches our expectations.
  - [`assert_line`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L77){:target="_blank" rel="noopener"}- checks that a given line of expected output was contained somewhere in the actual output.  You can optionally pass a specific line number at which you expect the output to contain your string.
  - [`refute_line`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L89){:target="_blank" rel="noopener"}- There are two ways to use this function:
    - You pass it a string, to check that string **is not** present in the most recent output.  Ex.- `refute_line "I hope this line is not present in the output"`
    - You pass an integer, to check that the number of lines in the output was **less than** that number.  Ex.- `refute_line 5`.
  - [`assert`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L105){:target="_blank" rel="noopener"}- Checks that the condition you pass is truthy.  For example, `assert [ 5 -lt 6 ]`.
  - [`path_without`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L113){:target="_blank" rel="noopener"}- This is only useful to test a few very specific situations, so we won't worry about this for now.
  - [`create_hook`](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L134){:target="_blank" rel="noopener"}- creates a fake hook that RBENV will subsequently register.  This is only useful to test a few very specific situations, so we won't worry about this for now.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

The next block of code is also our first test.  It starts with:

```
@test "blank invocation" {
  ...
}
```

### Annotations

The first thing I notice is the `@test` snippet.  I'm not sure what other developers would call this, but I would call it an "annotation", because [similar syntax exists](https://web.archive.org/web/20230309020001/https://en.wikipedia.org/wiki/Java_annotation){:target="_blank" rel="noopener"} in the Java community, and they also refer to these as annotations.

In BATS, annotations are used as metadata, and they help identify which code represents tests that should be run.  If we search the BATS codebase for the string `@test` and look through the results, eventually we find [this line of code](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-preprocess#L34){:target="_blank" rel="noopener"}.  This is a regular expression (or a regex for short).  If you aren't familiar with regexes, they're a very powerful tool for finding and parsing strings.  See [here](https://web.archive.org/web/20221024181745/https://linuxtechlab.com/bash-scripting-learn-use-regex-basics/){:target="_blank" rel="noopener"} for more information.

This isn't a walk-through of the BATS codebase so I want to keep this part short, but essentially what's happening here is we're providing a pattern for `bash` to use when searching for lines of code.  `bash` will read each line of code in a test file (for example, `test/rbenv.bats`) and see if it matches the pattern `@test`.  If it does, we know we've found a test, and we'll run the code we find.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Back to our test block:

```
@test "blank invocation" {
  run rbenv
  assert_failure
  assert_line 0 "$(rbenv---version)"
}
```

Here we're verifying that an attempt to run `rbenv` without any arguments will fail.  The steps in this test are:

 - We use the BATS [`run` command](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L50){:target="_blank" rel="noopener"} to execute the `rbenv` command without any arguments or flags.
   - `run` populates certain variables like `output`, `status`, and `lines`.
   - The helper functions we mentioned earlier (such as `assert_failure`, which is used in this test) use these variables to determine whether to pass or fail a given test.
 - Here, `assert_failure` checks to make sure the last command which was run (i.e. `run rbenv`) had a non-zero exit code.
 - If the command failed, the test passes.  If command succeeded, the test fails.

I would call this a "sad-path test".  When building our testing harness, we not only want to test what happens when things go right (i.e. the "happy-path"), but also what happens when things go wrong.  This gives us confidence that our code will work as expected in all scenarios, not just the good ones.

We can also test edge cases which are neither happy paths nor sad paths.  I've heard these referred to as "alternate paths".  They represent uses of a command which aren't exactly the primary use case, but aren't exactly "failures" either.

This test implies that running the command `rbenv` by itself, with no arguments, is considered "sad-path".  The `rbenv` command needs you to pass it the name of another command, before it can do anything.  For example, if you give it the `versions` command by running `rbenv versions`, RBENV knows that you want to see a list of all the Ruby versions which are installed on your system.  But by itself, the `rbenv` command does nothing, and attempting to run it by itself would be considered a user error.

There is also a 2nd assertion below the first one:

```
  assert_line 0 "$(rbenv---version)"
```

This assertion states that the 1st line of the printed output should be equal to the output of the `rbenv --version` command (the indexing here is 0-based).  So when the user runs `rbenv` without any arguments, the first line of printed output they should see is the version number for their RBENV installation.  I try this on my machine, and it works as expected:

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

## Command Substitution

The `"$( ... )"` syntax in our 2nd assertion above is known as [command substitution](https://web.archive.org/web/20230331064238/https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html){:target="_blank" rel="noopener"}, and will come up a lot in our walk-through.  It's similar to parameter expansion, in that it resolves to whatever is inside the left and right delimiters (here, parentheses instead of curly braces).  But instead of outputting a variable along with some optional modifiers (as with parameter expansion), it outputs the result of running the command inside the parens.  Let's do a few quick experiments here.

### Experiment: command substitution

Directly in my terminal, I run the following:

```
$ current_dir="$(pwd)"

$ echo "$current_dir"

/Users/myusername/Workspace/OpenSource/

$ current_dir_contents="$(ls "$current_dir" )"

$ echo "$current_dir_contents"

Make
bats
impostorsguides.github.io
rbenv
rubinius
...
```

Here we create two shell variables:

 - one named `current_dir`, containing the output of the `pwd` command.
 - the other named `current_dir_contents`, containing the contents of the directory whose name is stored in the `current_dir` variable (a.k.a. some directories I have in my `~/Workspace/OpenSource` directory).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Now that we've finished reading our first BATS test, let's write one of our own.

### Experiment: writing our own BATS test

I create a file named `bar.bash`, inside the same `test/` folder as `rbenv.bats`, which defines a shell function named `my_echo`:

```
#!/usr/bin/env bash

my_echo() {
 echo "Hi"
}
```

I create another file called `foo.bats`, also in the same directory, with the following content:

```
#!/usr/bin/env bats

load bar

@test "prints 'Hey yourself! when it's supposed to" {
  run my_echo "Hey"
  assert_success "Hey yourself!"
}
```


When I try to run it with the `bats` command, I get:

```
$ bats foo.bats
 ✗ prints 'Hey yourself! when it's supposed to
   (in test file foo.bats, line 8)
     `assert_success "Hey yourself!"' failed with status 127
   /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/bats.85070.src: line 8: assert_success: command not found

1 test, 1 failure
```

The thing to zero in on here is `assert_success: command not found`.

We're getting this error because we're missing the `assert_success` command.  That's because `assert_success` is a `test-helper` function, not a BATS function.  To access this command, we need to load `test_helper`, just like the regular test files do.

I update the test file to look like the following:

```
#!/usr/bin/env bats

load test_helper
load bar

@test "prints 'Hey yourself! when it's supposed to" {
  run my_echo "Hey"
  assert_success "Hey yourself!"
}
```

I then run it again:

```
$ bats foo.bats
 ✗ prints 'Hey yourself! when it's supposed to
   (from function `assert_equal' in file test_helper.bash, line 65,
    from function `assert_output' in file test_helper.bash, line 74,
    from function `assert_success' in file test_helper.bash, line 49,
    in test file foo.bats, line 8)
     `assert_success "Hey yourself!"' failed
   expected: Hey yourself!
   actual:   Hi

1 test, 1 failure
```

Now we see the following error:

```
  expected: Hey yourself!
  actual:   Hi
```

We've run the test, and verified that it fails for the correct reason (unexpected output).  This gives us confidence that our test fails when it's supposed to.

We can then write the functionality that we expect to make the test pass, and re-run the test.  In our case, that just means updating the `my_echo` function inside `bar.bash` to actually print what it's supposed to:

```
#!/usr/bin/env bash

my_echo() {
 echo "Hey yourself!"
}
```

When I re-run the test, we get:

```
$ bats test/foo.bats
 ✓ prints 'Hey yourself! when it's supposed to

1 test, 0 failures
```

That's an example of testing a "happy-path" scenario.

Next, I want to test a "sad-path" scenario.  I write a 2nd test in my `.bats` file to check that it fails when I pass an invalid argument:

```
#!/usr/bin/env bats

load test_helper
load bar

@test "prints 'Hey yourself! when it's supposed to" {
  run my_echo "Hey"
  assert_success "Hey yourself!"
}

@test "fails if the input is not 'Hey'" {
  run my_echo "Ahoy"
  assert_failure "I don't understand 'Ahoy'"
}
```

When I re-run it:

```
$ bats foo.bats
 ✓ prints 'Hey yourself! when it's supposed to
 ✗ fails if the input is not 'Hey'
   (from function `flunk' in file test_helper.bash, line 42,
    from function `assert_failure' in file test_helper.bash, line 55,
    in test file foo.bats, line 13)
     `assert_failure "I don't understand 'Ahoy'"' failed
   expected failed exit status

2 tests, 1 failure
```

We see a `✗` character instead of a `✓` character next to the test description.  We also see which assertion failed:

```
`assert_failure "I don't understand 'Ahoy'"' failed
```

Lastly, we see `expected failed exit status`, which tells us why `assert_failure` failed.

To make this "sad-path" test pass, we can update our function to the following:

```
#!/usr/bin/env bash

my_echo() {
  if [ "$1" != "Hey" ]; then
    echo "I don't understand '$1'"
    exit 1;
  fi

 echo "Hey yourself!"
}
```

Now, when we re-run the test, we see:

```
$ bats foo.bats
 ✓ prints 'Hey yourself! when it's supposed to
 ✓ fails if the input is not 'Hey'

2 tests, 0 failures
```

Great, that's a (very preliminary) introduction to writing our own BATS test.  We'll see lots more BATS syntax in the subsequent tests.

### Aside- Test-Driven Development


In our first test, we expected to see "Hey yourself!" printed to the screen, but we actually saw "Hi".  I wrote the test this way intentionally, to demonstrate the concept of ["Red-Green-Refactor"](https://web.archive.org/web/20221203024358/https://www.codecademy.com/article/tdd-red-green-refactor){:target="_blank" rel="noopener"}, which comes from the world of [test-driven development](https://web.archive.org/web/20230425032604/https://en.wikipedia.org/wiki/Test-driven_development){:target="_blank" rel="noopener"} (or 'TDD' for short).  We start by writing a test for the functionality that we want to test, **before** we write the functionality itself.

If we really wanted to be strict about our TDD practice, our sequence of steps would have been even more granular:

 - We run the test **without** the `load bar` line, and see a failure related to a missing `my_echo` function.
 - We run the test with an **empty** implementation of `my_echo` (i.e. no function body), and see a failure related to empty output of `my_echo`.
 - We run the test with an **incorrect** implementation of `my_echo`, and see a failure related to incorrect output of `my_echo`.
 - Then and only then, we write the correct implementation of `my_echo` and see our test pass.

At first, writing tests like this is slower than just writing the code itself and forgetting about tests.  But over time, as an application starts to grow in size, it actually becomes faster to use TDD.  This is because you need to spend more and more time ensuring that the features you just finished writing didn't break previous features.

Without automated tests, at a certain point you end up giving up manual tests entirely, in favor of relying on your user base to report errors to you.  That's not a great user experience, and I'm comfortable claiming that it's not great engineering practice either.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "invalid command" {
  run rbenv does-not-exist
  assert_failure
  assert_output "rbenv: no such command \`does-not-exist'"
}
```

This test covers the sad-path case of when a user tries to run a command that RBENV doesn't recognize.  We do the following:

- run a fake RBENV command called `rbenv does-not-exist`,
- call our `assert_failure` helper function to ensure that the previous command failed, and
- check that the output which was printed to `stdout` contained the line `rbenv: no such command 'does-not-exist'`.

I try this on my machine as well:

```
$ rbenv foo
rbenv: no such command `foo'
```

Looks good!

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test is:

```
@test "default RBENV_ROOT" {
  RBENV_ROOT="" HOME=/home/mislav run rbenv root
  assert_success
  assert_output "/home/mislav/.rbenv"
}
```

Here we call `root` (a real RBENV command) because we want to test how `rbenv` responds to a known-valid command (unlike the previous test, which tested a known-invalid command).  We picked the `root` command in particular because its implementation is only a single line of code, so it allows us to accomplish this goal with minimal risk.

The test does the following:

- passes an empty value for `RBENV_ROOT` and an arbitrary but unsurprising value for `HOME` as environment variables, and
- asserts that:
  - the command succeeded, and
  - that the printed output included the `.rbenv/` directory, prepended with the value we set for `HOME`.

Judging by the environment variables (`RBENV_ROOT` and `HOME`) which are passed to the `run rbenv root` command, this test appears to cover the behavior beginning at [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54){:target="_blank" rel="noopener"}.  But rather than skip ahead to analyze what this line of code does, let's punt on that until we look at the code for the command itself.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "inherited RBENV_ROOT" {
  RBENV_ROOT=/opt/rbenv run rbenv root
  assert_success
  assert_output "/opt/rbenv"
}
```

This test is similar to the previous test, except this time we're testing [the `else` branch](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L56){:target="_blank" rel="noopener"} instead of [the `if` branch](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54){:target="_blank" rel="noopener"}.  We set a non-empty value for `RBENV_ROOT` and assert that that value is used as the output for the `root` command.  We leave `HOME` blank this time, because `HOME` is only needed to help construct `RBENV_ROOT` if `RBENV_ROOT` doesn't already exist.

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

This test covers the same block of code as the previous test, except this time we're testing [the `else` branch](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L63){:target="_blank" rel="noopener"} instead of [the `if` branch](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61){:target="_blank" rel="noopener"}:

- We create a variable named `dir` and set it equal to `BATS_TMPDIR` with "/myproject" appended to the end.
  - The value of the `BATS_TMPDIR` env var is set [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L305){:target="_blank" rel="noopener"} if it's not already set.
  - More info on `BATS_TMPDIR` and other BATS-specific environment variables can be found [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/README.md#special-variables){:target="_blank" rel="noopener"}.
- We then create a directory whose name is the value of our `dir` variable.
  - The `-p` flag ensures that any intermediate directories in between our current one and `/myproject` are also created, if they don't already exist.
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

If it *does* work, [we reset `RBENV_DIR`](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv#L35){:target="_blank" rel="noopener"} to be equal to our current directory.  But if it fails, we abort and print the error message `rbenv: cannot change working directory to '$dir'`.  That's the edge case we're testing- when the navigation into the specified directory fails, the command fails and the expected error message is printed to `stderr`.

Why do we reset `RBENV_DIR`?  We'll analyze that in depth later, but the short explanation is that we want to remove and possible `..` syntax from it, i.e. we want to "canonicalize" it.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next test:

```
@test "adds its own libexec to PATH" {
  run rbenv echo "PATH"
  assert_success "${BATS_TEST_DIRNAME%/*}/libexec:$PATH"
}
```

After some digging, I discovered that  this test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79){:target="_blank" rel="noopener"}.  We can prove this by running the test with this line of code in-place, and then re-running it with the code commented-out, observing that the test fails when the line is commented out.

We will dive into what this line of code does when we start reading the code for `rbenv` itself.  But from the description of this test (`adds its own libexec to PATH`), we can deduce that the `libexec/` folder contains commands that we'll want to execute from the terminal.

Remember that `PATH` is the list of folders which UNIX checks when we give it a command to execute.  By adding more folders to `PATH` (such as `libexec/`), we'll have access to more commands.

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

This test covers the 4-line block of code starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L76){:target="_blank" rel="noopener"}.  Inside the test, we create two directories, one named `ruby-build` and one named `rbenv-each`.  From the name of the directory ( `plugins/`), we can assume that this is where RBENV plugins are stored, so we can deduce that creating these two sub-directories means we're creating two RBENV plugins for the purposes of our test.  Since there's no additional setup (such as creating files inside of those directories), we can assume that's all the setup required, in order to make our test think these plugins actually exist.

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
 - assert that the printed output references the following directories, delimited by the `:` character:
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
