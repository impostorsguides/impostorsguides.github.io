NOTE- the analysis of this command's test coverage was written after I had already finished reading the code for the commands in "libexec/", and therefore reflects a level of knowledge that I didn't yet have on my first pass through this code.

Let's look at the tests for this file first, to get a sense of what the expected behavior is.  We'll look at the code afterward.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/rbenv.bats)

TODO: Move explanation of BATS here, since this is the first time we encounter BATS tests.

The first line of code is:

```
#!/usr/bin/env bats
```

This is a shebang, but it's not a `bash` shebang.  Instead, it's a `bats` shebang.  [`bats` is a test-runner program](https://github.com/sstephenson/bats) that Sam Stephenson (the original author of RBENV) wrote, and it's used here as RBENV's test framework.  But it's not RBENV-specific- you could technically use it to test any shell script.  This shebang tells the shell that the way we run these tests is by calling `bats` plus the name of the test file.

Next line of code:

```
load test_helper
```

This `load` method comes from [this line of code](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L32) in `bats`.  Here we're loading a helper file called `test_helper`, which lives [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash).  Loading `test_helper` does lots of things for us that help our tests run as expected, such as updating the value of `PATH` to include the `rbenv` commands that we want to test, as well as giving us access to helper functions that let us run those commands and assert that the results succeeded or failed, along with asserting that the printed output of the commands included certain text.

The next block of code is our first test:

```
@test "blank invocation" {
  run rbenv
  assert_failure
  assert_line 0 "$(rbenv---version)"
}
```

Here we're testing that an attempt to run `rbenv` without any arguments will fail.  We use `test_helper`'s `run` command to execute the `rbenv` command by itself, then we call `test_helper`'s `assert_failure` function, which fails this test if the previously-run command (aka `run rbenv`) was zero (which means it succeeded).  In other words, if `run rbenv` succeeded, the test we're reading now would fail.

There is also a 2nd assertion below the first one, which states that the 0th line of the printed output should be equal to the output of the `rbenv --version` command.  So when the user runs `rbenv` without any arguments, the first line of printed output they should see is the version number for their RBENV installation.  I try this on my machine, and it works as expected:

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

Next test:

```
@test "invalid command" {
  run rbenv does-not-exist
  assert_failure
  assert_output "rbenv: no such command \`does-not-exist'"
}
```

This test covers the sad-path case of when a user tries to run an RBENV command that doesn't exist.  We run a fake command called `does-not-exist`, call our `assert_failure` helper function to ensure that the previous command failed, and check that the output which was printed to STDOUT contained the line "rbenv: no such command \`does-not-exist'".

I try this on my machine as well:

```
$ rbenv foo
rbenv: no such command `foo'
```

Looks good!  Next test is:

```
@test "default RBENV_ROOT" {
  RBENV_ROOT="" HOME=/home/mislav run rbenv root
  assert_success
  assert_output "/home/mislav/.rbenv"
}
```

At first I thought it was strange that we're including a call to the `root` command inside the test file for the `rbenv` command.  I would have expected the test file for `rbenv` to only include calls to `rbenv`, not to other commands as well.  Otherwise, if such a test fails, it could be because of a failure in that other command, as opposed to in the `rbenv` command.

After giving this some thought, I suspect it's because:

we intentionally want to test how `rbenv` responds to a known-valid command (unlike the previous test, which tested a purposely invalid command),
we know the `root` command is such a command, and
this command's implementation is only a single line of code, so it allows us to accomplish our goal with minimal added complexity and risk of the failure I mentioned just now.

Judging by the environment variables which are passed to the `run rbenv root` command, this test appears to cover the behavior beginning at [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54) (I skipped ahead a bit because I was curious where `RBENV_ROOT` and `HOME` are used).  We pass an empty value for `RBENV_ROOT` and an arbitrary but unsurprising value for `HOME` as environment variables, and we assert that a) the command succeeded (i.e. its return code was 0), and b) that the printed output included the `.rbenv/` directory, prepended with the value we set for `HOME`.

Next test:

```
@test "inherited RBENV_ROOT" {
  RBENV_ROOT=/opt/rbenv run rbenv root
  assert_success
  assert_output "/opt/rbenv"
}
```

This test is similar to the previous test, except this time we set a non-empty value for `RBENV_ROOT` and assert that that value is used as the output for the `root` command.  We leave `HOME` blank because `HOME` is only needed to help construct `RBENV_ROOT` if `RBENV_ROOT` doesn't already exist, again according to [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L54).

Next test:

```
@test "default RBENV_DIR" {
  run rbenv echo RBENV_DIR
  assert_output "$(pwd)"
}
```

Here we appear to be testing [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61).  We assert that, if no prior value has been set for `RBENV_DIR`, we set it equal to the value of the shell's `PWD` environment variable (which is also the same as the output of the `pwd` shell command, which is what "$(pwd)" resolves to here).

Note that we won't be able to run `rbenv echo` in our shell unless we manually update our `PATH` environment variable to include RBENV's `test/libexec/` directory.  The `test_helper` file does this for us when we run our test, but if we're not running a test then we have to do this ourselves.

Next test:

```
@test "inherited RBENV_DIR" {
  dir="${BATS_TMPDIR}/myproject"
  mkdir -p "$dir"
  RBENV_DIR="$dir" run rbenv echo RBENV_DIR
  assert_output "$dir"
}
```

This test covers the same block of code as the previous test, except this time we're specifying a non-default value for `RBENV_DIR` (as opposed to testing what happens when the default value is used).

We create a variable named `dir` and set it equal to `BATS_TMPDIR` with "/myproject" appended to the end (the value of the `BATS_TMPDIR` env var is set [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test#L304), and more info on `BATS_TMPDIR` can be found [here](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/README.md#special-variables)).  We then create a directory whose name is the value of our `dir` variable, and we set the `RBENV_DIR` env var equal to this directory before running `rbenv echo RBENV_DIR`.  We assert that the command printed the value that we specified for the `RBENV_DIR` env var, since that's the env var that we passed to `rbenv echo`.  In other words, [the block of code that we're testing](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61) didn't modify the value of `RBENV_DIR` in any way.

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

Here we're testing the same [block of logic](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L61) as the last test, but this time we're testing a different edge case.  Inside that block's `else` branch, we attempt to navigate into the directory we specify via `RBENV_DIR`.  If that succeeds, we reset `RBENV_DIR` to be equal to the directory we just `cd`'ed into.  If that fails, we abort and print the error message "rbenv: cannot change working directory to \`$dir'".  That's the edge case we're testing- when the navigation into the specified directory fails, the command fails and the expected error message is printed to STDERR.

Next test:

```
@test "adds its own libexec to PATH" {
  run rbenv echo "PATH"
  assert_success "${BATS_TEST_DIRNAME%/*}/libexec:$PATH"
}
```

This test is a bit confusing, because when I search [the `libexec/rbenv` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv) for the string "libexec", I only find one result ([here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23)), which doesn't appear to do what the test is asserting.  This makes me wonder how the test is passing.  I wonder if the reason for that is because of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L25) inside `test_helper`.  I run just that one test two separate times, the first time with that line intact:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-109pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I get the following:

<p style="text-align: center">
  <img src="/assets/images/test-output-12mar2023-117pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Next I comment out just that line:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar23-118pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...and I run the test again, this time getting the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar23-118pm-2.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

To me, this indicates that the test is testing logic inside `test_helper`, *not* logic inside `libexec/rbenv`.  This could be worth a pull request.

(stopping here for the day; 90621 words)

UPDATE: I was wrong.  After some digging into the code, I discovered that [another line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79) (inside the `rbenv` file itself) is actually the code which this test covers.  I ran that same test with and without this line of code in place, and the test failed when the line was commented out.  So I feel comfortable with leaving this test as-is, and continuing on with the analysis.

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

This test seems to cover the 4-line block of code starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L76).  This test creates two plugins, one named `ruby-build` and one named `rbenv-each`.  We then run the command to `echo` `$PATH`, with ":" as a separator so that each item in `$PATH` prints on its own line, and assert that the command was successful.  The test then asserts that the first item in `$PATH` is the value stored in `bin_path` and pre-pended to `$PATH` [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L79), and that the next two items in `$PATH` are the paths to the two plugins that we installed.  The `libexec/` directory comes first in `$PATH` because the line which prepends `libexec/` to `$PATH` is executed *after* the `for` loop which prepends each plugin directory to `$PATH`.

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

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81).  We set the value of the `RBENV_HOOK_PATH` env var so that it includes two hard-coded paths, and then run `rbenv echo` on this env var.  We assert that the command was successful and that the two hard-coded paths are printed, followed by `${RBENV_ROOT}/rbenv.d` (which the aforementioned line of code appends to the end of `$PATH`.

Side note- we can test whether a given test covers certain lines of code by simply commenting out those lines in the command and seeing which tests fail:



The above 2 failures include the test we're currently examining.

Last test:

```
@test "RBENV_HOOK_PATH includes rbenv built-in plugins" {
  unset RBENV_HOOK_PATH
  run rbenv echo "RBENV_HOOK_PATH"
  assert_success "${RBENV_ROOT}/rbenv.d:${BATS_TEST_DIRNAME%/*}/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
}
```

Here we unset `RBENV_HOOK_PATH`, run the command, assert that it was successful, and assert that the printed output matched a certain series of directories, delimited by the ":" character.

I'm reasonably certain that this test covers the block of code [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81), from lines 81-91.  But it's a bit hard to follow how each directory in `RBENV_HOOK_PATH` ends up where it is.  To clarify this, I decide to `echo` some lines to a file.  I update the `rbenv` command to look like the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-121pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="updating the code for experimentation's sake">
</p>

And I update the test to look like the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-122pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="updating the code for experimentation's sake">
</p>

When I run the test, and `cat` the output file `foo.txt`, I see the following:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-123pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="updating the code for experimentation's sake">
</p>

The first version of `RBENV_HOOK_PATH` that we see is:

```
RBENV_HOOK_PATH #1: :/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.Nbj/root/rbenv.d
```

This seems to equal the value of `RBENV_ROOT` that was printed to the screen, with `/rbenv.d` appended to the end.  That matches the logic of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81).

The next version of `RBENV_HOOK_PATH` that we see is:

```
RBENV_HOOK_PATH #2: :/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.Nbj/root/rbenv.d:/Users/myusername/Workspace/OpenSource/rbenv/rbenv.d
```

This matches the previous value of `RBENV_HOOK_PATH #1`, plus everything from `bin_path` *except for* the final "/libexec" from `bin_path`.  Instead of that missing last part, we have "/rbenv.d" at the end.  This matches the logic of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L84).

The next version of `RBENV_HOOK_PATH` that we see is:

```
RBENV_HOOK_PATH #3: :/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.CGK/root/rbenv.d:/Users/myusername/Workspace/OpenSource/rbenv/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks
```

This matches the previous value of `RBENV_HOOK_PATH #2`, if the string `:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks` were appended to the end.  This matches the logic of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L86).

The next version of `RBENV_HOOK_PATH` that we see is:

```
RBENV_HOOK_PATH #5: /var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.CGK/root/rbenv.d:/Users/myusername/Workspace/OpenSource/rbenv/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks
```

This matches the previous value of `RBENV_HOOK_PATH #3` that we saw, except that the leading ":" character is removed from the beginning.  That matches the logic of [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L90).

Comparing `RBENV_HOOK_PATH #5` with `expected_output` shows that they are exactly the same string.  So this explains why each directory ends up in its given location.  Cool, that was helpful.

That's all for the `rbenv` command's tests.  Let's move onto the code.

## [Code](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv)

This file's first line is:

```
#!/usr/bin/env bash
```

This is the shebang, which we're already familiar with.  This tells us that we will be using bash-flavored rules when dictating how the script will be processed.  So no more zsh oddities to Google!

The next line of code is:

```
`set -e`
```

We already know what that is- it tells the interpreter to immediately exit with a non-zero status code as soon as the first error is raised (as opposed to continuing on executing the rest of the file).  So we don't need to spend too much time here.

(stopping here for the day; 7774 words)

Next line of code is:

```
if [ "$1" = "--debug" ]; then
```

This feels easier to read, now that we've had some experience with `if` statements and the `[[` / `test` commands.  The one thing I'm unsure about is "$1".  I'm pretty sure it evaluates to one of the arguments that the terminal command was passed, but I'm not sure if it's 0-based or 1-based.  A quick Google should leads us [here](https://web.archive.org/web/20211006091051/https://stackoverflow.com/questions/29258603/what-do-0-1-2-mean-in-shell-script):

<p style="text-align: center">
  <img src="/assets/images/stackoverflow-answer-positional-arguments.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer about positional arguments">
</p>

So "$1" is the first non-filename argument sent to the script.  Based on this, we can conclude that if the first argument is equal to "--debug", then...do something (TBD in the next line of code).

Speaking of which:

```
  export RBENV_DEBUG=1
  shift
fi
```

The `export` statement looks familiar from our discussion on environment variables.  Here we're just setting `RBENV_DEBUG` equal to 1 and exporting it so that it's available to any subsequent code that relies on it, either in this file or another file.

My understanding of `export` is that, once an environment variable is `export`ed, it's available to *any* other script that needs it.  That makes me wonder if, after I pass `--debug` to this script, whether it would be available to me in the same terminal script where I ran the command, or whether the env var is unset by the time the script completes.  I suspect it wouldn't be available outside this code, especially since [I don't see any code in the repo](https://github.com/rbenv/rbenv/search?p=1&q=RBENV_DEBUG) which unsets `RBENV_DEBUG`, but I'm not sure how that var is wiped away.

[The answer I found](https://unix.stackexchange.com/a/28349/142469) says that an `export`ed variable is available in the same script, in a child script, and in a function which is called inside that same script, but not in another sibling script or in a parent process.  A separate, but also helpful, answer says that the processes in which scripts run are organized like a tree, and that an env var which is set in process A will be accessible in process A's script and in any child processes, but not in any parent processes.  Makes sense to me.

What about `shift`, what does that do?  According to [the docs](https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_09_07.html), when called without params, it trims off the first arg from the array of args passed to the script.  I did a test script to see how it works:

```
#!/usr/bin/env bash

echo "old arg length: $#"
echo "old args: $@"

shift

echo "new arg length: $#"
echo "new args: $@"
```

When I run it, I get:

```
$ ./foo bar baz buzz
old arg length: 3
old args: bar baz buzz
new arg length: 2
new args: baz buzz
```

Success!  It does what I thought.

So if the user passes `--debug` as their first arg to `rbenv`, we set RBENV_DEBUG and trim the `--debug` flag off the list of args.

Next line:

```
if [ -n "$RBENV_DEBUG" ]; then
```

Since the `-n` flag is passed to the `[` command, I run `man test` and search for `-n`.  I see:

```
-n string     True if the length of string is nonzero.
```

OK, so if the length of `$RBENV_DEBUG` is non-zero (aka if it has been set), then do what's inside the `if` block.  Which is:

```
# https://wiki-dev.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
```

The first line of code is a comment, containing a URL which may be helpful later.

Next line is another `export` statement, and woof, is it ugly.  Let's inspect each of the 4 values inside it, as a first step.  I add 4 `echo` statements to the body of the `if` block:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-133pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Adding more `echo` debugging statements">
</p>

I then run `rbenv –debug commands` and get:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-135pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Output of the additional `echo` debugging statements">
</p>

The first 2 lines are fine:

```
BASH_SOURCE: /usr/local/bin/rbenv
LINENO: 12
```

`BASH_SOURCE` resolves to `/usr/local/bin/rbenv`, the file it's currently executing (which I looked up in the terminal using `ls -la`, and is just a symlink to the `libexec/rbenv` file we `vim`ed into).  And `LINENO` outputs `12`, which is the line of code we're on in that file.  But the next 2 lines are weird:

```
FUNCNAME:
FUNCNAME[0]: [0]
```

Not super-clear on what those do.  This may be a case where I `echo`'ed the wrong thing, in which case the above is a red herring.

Let me take a different tack, and search what `PS4` is.  The only line of code in this codebase containing the string `PS4` is the `export` line we're currently reading, so I know `PS4` isn't *directly* referenced anywhere else in the codebase.  That sort of implies to me that `PS4` must be used by something else, probably the system itself, in which case the name `PS4` has a special meaning in bash.

I Google "PS4" and find that I'm right about this.  [This article](https://web.archive.org/web/20220517005905/https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/) says that "The PS4 shell variable defines the prompt that gets displayed, when you execute a shell script in debug mode...  It also says that "PS4 (is used) by ‘set -x' to prefix tracing output", which relates to the line of code after the `export` line we're currently on.

So when I see lines like the following in the output of `rbenv –debug commands`:

```
+(/usr/local/bin/rbenv:24): enable -f /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-realpath.dylib realpath
+(/usr/local/bin/rbenv:55): '[' -z '' ']'
+(/usr/local/bin/rbenv:56): RBENV_ROOT=/Users/myusername/.rbenv
```
The `+(/usr/local/bin/rbenv:56): ` comes from `+(${BASH_SOURCE}:${LINENO}): `.

And therefore, `RBENV_ROOT=/Users/myusername/.rbenv` comes from `${FUNCNAME[0]:+${FUNCNAME[0]}(): }`?  This is still really hard to read.

I remember that, luckily, there was a URL mentioned in the comment of this block of code.  Maybe that URL will help me understand what's happening here?

[One of the first things I read](https://archive.ph/l0HmS) on that URL is:

> `xtrace` output would be more useful if it contained source file and line number. Add this assignment PS4 at the beginning of your script to enable the inclusion of that information:
>
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

Oh, I think I see.  Because we aren't currently inside a function, we don't see `FUNCNAME[0]` by itself.  But if we were, we'd see the name of that function.

—-----

I kept noticing the phrase `xtrace` being thrown around on some of the links I encountered while trying to solve the above.  I Googled "what is xtrace bash", and found [this link](https://unix.stackexchange.com/questions/536263/turn-on-xtrace-with-environment-variable), which says:

<p style="text-align: center">
  <img src="/assets/images/stackoverflow-answer-12mar2023-138pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer about `xtrace`">
</p>

One interesting sentence here is "if you turn on the "-x" option... Bash outputs each line of script as it executes it."  It's interesting partly because we *didn't* see *every* line of code that was executed.  We only saw a *subset* of them.  For example, in the series of output lines I quoted above:

```
+(/usr/local/bin/rbenv:24): enable -f /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-realpath.dylib realpath
+(/usr/local/bin/rbenv:55): '[' -z '' ']'
+(/usr/local/bin/rbenv:56): RBENV_ROOT=/Users/myusername/.rbenv
```
The first line number is 24, and the next line number is 55.  Line 24 in the output is not the same as line 24 in the Github file, but I'm guessing that's just because the interpreter strips out all the comment lines (including the 1-line shebang) before it calculates the interpreted line numbers.  But why does it skip from 24 to 55?

Oh, I think I see.  The reason it skips is, perhaps, because we enter into the `if` block, not the `else` block, and the `if` block just defines a function, and a function definition doesn't actually execute any code.  The next line of code after the `if/else` logic is, in fact, the `if [ -z "${RBENV_ROOT}" ]; then` code on (what it thinks is) line 55.

—-----

OK, so to sum it up so far, if `$RBENV_DEBUG` has a length greater than zero (aka if debug mode is turned on), then we reset the debug-mode shell prompt to print out the line of code, and the command that's currently being executed.

One additional tidbit I learned was from [this link](https://web.archive.org/web/20220727073711/https://www.shell-tips.com/bash/prompt/#gsc.tab=0), which says "The default value (of $PS4) is "+". The first character of the $PS4 expanded value is replicated for each level of indirection."

This seems to imply that the prompt will replicate the first character of $PS4 (a `+` character in my case, and in the new over-ridden $PS4 value above) once for each level of nesting / abstraction we're in.  However, that doesn't seem to happen when I try the test script below:

```
#!/usr/bin/env bash

function baz() {
  echo "inside baz"
}

function foo() {
  echo "inside foo"
  (baz);
}

function bar() {
  echo "inside bar"
  (foo);
}

set -x

bar;
```

I was expecting something like the following, or similar:

```
+ bar
+ echo 'inside bar'
inside bar
++ foo
++ echo 'inside foo'
inside foo
+++ baz
+++ echo 'inside baz'
inside baz
```

But instead, I see:

```
+ bar
+ echo 'inside bar'
inside bar
+ foo
+ echo 'inside foo'
inside foo
+ baz
+ echo 'inside baz'
inside baz
```

In other words, I never see more than one "+" per line, regardless of how deep inside the call stack I am.  So what does "level of indirection" mean here?

[I post another StackExchange question](https://unix.stackexchange.com/questions/715831/ps4-in-bash-how-can-i-reproduce-the-level-of-indirection-behavior-mentioned), and eventually I get [an answer](https://unix.stackexchange.com/a/715835/142469):


<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-141pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow answer">
</p>

I try the suggested script and I get the same results that the commenter mentioned.  Success!

So what is `eval` in bash?

From [The Linux Documentation Project](https://web.archive.org/web/20220824231216/https://tldp.org/LDP/abs/html/internal.html):

> eval
>
> eval   arg1   [arg2]   ...   [argN]
>
> Combines the arguments in an expression or list of expressions and evaluates them. Any variables within the expression are expanded. The net result is to convert a string into a command.

And from [StackOverflow](https://stackoverflow.com/questions/11065077/the-eval-command-in-bash-and-its-typical-uses):

> `eval` takes a string as its argument, and evaluates it as if you'd typed that string on a command line.

And lastly, in [ComputerHope](https://web.archive.org/web/20220524230137/https://www.computerhope.com/unix/bash/eval.htm):

> It's similar to running `bash -c "string"`, but `eval` executes the command in the current shell environment rather than creating a child shell process.

Now my question is: why would you need to call `eval` and pass it a command?  Why not just call the command itself?

It seems like that could be tricky to accomplish, for example if part of the command that `exec` would run is the first command in the string.  Ex.:

```
command="echo ‘Hello world'"
eval $command
```

How would one run `command` without `eval`, in this case?

[The ComputerHope post](https://web.archive.org/web/20220524230137/https://www.computerhope.com/unix/bash/eval.htm) has more examples:

<p style="text-align: center">
  <img src="/assets/images/computerhope-post-on-eval-12mar2023.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="More info on the `eval` command">
</p>

This `ssh-agent` example is actually pretty similar to the way `rbenv init` is called, i.e. by adding `eval "$(rbenv init -)"` to your `.zshrc` file.

Question: Why do we need the `-` character in `eval "$(rbenv init -)"`?  And why do we need to call `rbenv init` inside `eval` at all?  Why not just call it by itself?

Oh wait, I think I remember I answered this for myself already.  One of the things that the `rbenv init` does is `echo` certain executable commands to the screen, so that `eval` can execute them.  I can investigate further why they need to be `echo`ed instead of just run in-line, but a) I'm sure the authors had their reasons, and b) I don't want to get too side-tracked from my main goal of understanding the current file.  I will get to those other files in due course.

—--------

So summarizing the first 2 blocks of code: we first check if the user passed `--debug` as the first argument.  If they do, we set the `RBENV_DEBUG` env var.  Then in the 2nd block, if the `RBENV_DEBUG` env var has been set, we change the terminal prompt to output more useful information (such as the stack trace including the filename and line of code, and the current code being executed) and we call `set -x` to put bash into debug mode.

But why do we need to separate these steps into different blocks of code?  Why didn't we just do something like the following:

```
if [ "$1" = "--debug" ]; then
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi
```

In other words, combine the conditional check of the 1st `if` block and body of the 2nd `if` block?

The reason is because we need to `export` the `RBENV_DEBUG` environment variable so that other commands can access it for their own purposes.

(stopping here for the day; 9444 words)

Next line of code is:

```
abort() {
...}
```

This just declares (but doesn't actually call) a function named `abort`.  Nothing surprising here.


Next line of code is:

```
  { if [ "$#" -eq 0 ]; then cat -
  ...  } >&2
```

A couple questions here:

First, what does "$#" evaluate to?  According to [StackOverflow](https://web.archive.org/web/20211120050118/https://askubuntu.com/questions/939620/what-does-mean-in-bash):

> `echo $#` outputs the number of positional parameters of your script.

So `[ "$#" -eq 0 ]` means "if the # of positional parameters is equal to zero".

But whose positional parameters are we talking about- the `abort` function's params, or rbenv's params?

I try a simple function definition in my terminal:

```
function foo() {
  if [ "$#" -eq 0 ]; then
    echo 'no args given';
  else
    echo "$# args given";
  fi
}
```

I then run it a few times:

```
$ foo
no args given
$ foo bar baz
2 args given
```

OK, so we *might* be talking about the # of args sent to `abort`.  To get more info, I try putting the above function inside a script file named "foo":

```
#!/usr/bin/env bash

function foo() {
  if [ "$#" -eq 0 ]; then
    echo 'no args given';
  else
    echo "$# args given";
  fi
}

foo "$@"
```

I then run it as follows:

```
$ ./foo bar baz

2 args given
```

OK, so we therefore *must* be talking about the # of args passed to `abort`.

NOTE FROM RICHIE- verify that the above is correct.

Second, What is `cat -`?

I type `help cat` in my terminal, and get the following:

> The `cat` utility reads files sequentially, writing them to the standard output.  The file operands are processed in command-line order.  If file is a single dash (‘-') or absent, `cat` reads from the standard input.

OK, so if there are no args passed to `abort`, then we read from standard input.  Not sure why, though.  Maybe it'll become clearer if we continue reading the code.

Last question about this code snippet: what is `>&2` at the end there?

From [StackExchange](https://askubuntu.com/questions/1182450/what-does-2-mean-in-a-shell-script):

```
Using > to redirect output is the same as using 1>. This says to redirect stdout (file descriptor 1).

Normally, we redirect to a file. However, we can use >& to redirect to stdout (file descriptor 1) or stderr (file descriptor 2) instead.

Therefore, to redirect stdout (file descriptor 1) to stderr (file descriptor 2), you can use >&2
```
Hmmm, so we're redirecting the output of whatever is inside the curly braces, and sending it to stderr.

TODO: answer what STDIN, STDOUT, and STDERR are here.

Next line of code is:

```
    else echo "rbenv: $*"
    fi
```

The "fi" just terminates the "if" clause.  What does "$*" do?

Once again, [StackOverflow answers our question](https://stackoverflow.com/questions/12314451/accessing-bash-command-line-args-vs):

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-152pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow - what does `$*` do?">
</p>

So "$*" expands to the list of arguments passed to the script.  We can verify that by writing our own simple script:

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

I'm still no clearer on why we read from standard input via "cat -".  I decide to see where this "abort" function is used in this file.  I see a few references to "abort" with some strings passed, which I assume is for the "else" case of "abort"'s "if/else" logic.  Then I see:

```
case "$command" in
"" )
  { rbenv---version
    rbenv-help
  } | abort
  ;;
```

OK, so here "abort" is being called without any explicit params.  Instead, we're piping some text to it.  Let's try to replicate that and see what happens:

```
#!/usr/bin/env bash

function foo() {
  {
    if [ "$#" -eq 0 ]; then cat -
    fi
  } >&2
  exit 1
}

echo "Hello bang" | foo
```

When I run this script, I see:

```
$ ./foo

Hello bang
```

Gotcha- so the logic inside the `if` clause is meant to allow the user (aka the caller of the "abort" function) to be able to send text into the function via piping.

While we're at it, let's see what happens in the "else" case.  I copy the entire "abort" function into my "foo" script, along with one of the lines in the "rbenv" file which calls "abort" with params:

```
#!/usr/bin/env bash

abort() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "rbenv: $*"
    fi
  } >&2
  exit 1
}

#echo "Whoops" | abort

abort "cannot find readlink - are you missing GNU coreutils?"
```

Running the script gives us:

```
$ ./foo
rbenv: cannot find readlink - are you missing GNU coreutils?
```

So it just concatenates "rbenv: " at the front of whatever error message you pass it.

So to sum up the "abort" function: if you don't pass it any string as a param, it assumes you are piping in the error, and it reads from STDIN and prints the input to STDERR.  Otherwise, it assumes that whatever params you passed it is the error you want to output, and prints THAT to STDERR.  It then terminates with a non-zero exit code.

Take-aways: here we were lucky, because the code we were trying to comprehend was part of a function that was later called throughout the file.  So we could see how and where the function was called, and use that information to deduce what it did and why.  It's not always possible to use this strategy (for instance, if the code isn't part of a function which is later called, but instead is just part of a procedural script), but when it IS possible, it's a good tool for our toolbelt.

[Next line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L23) is:

```
if enable -f "${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib realpath 2>/dev/null; then
```

(stopping here for the day; 10545 words)

Reading this line, I ask myself a few questions:

What does the `enable` command do?
What does its `-f` flag mean?
What are the command's positional arguments?
What does `2>/dev/null` do?
What kind of file extension is `.dylib`?  What does that imply about the contents of the file?

I type both `man enable` and `help enable` in my terminal, but each time I see `No manual entry for enable`.  Looks like I only have Google to turn to.

Luckily, [the first link](https://web.archive.org/web/20220529121055/https://ss64.com/bash/enable.html) I see when I Google "enable command bash" looks like a good one, though it doesn't look like part of the official docs:

<p style="text-align: center">
  <img src="/assets/images/enable-docs-12mar2023-157pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Docs on the `enable` keyword">
</p>

This actually answers my first three questions:

The `enable` command can take builtin shell commands (like `which`, `echo`, `alias`, etc.) and turn them on or off.  It mentions that this could be useful if you have a script which shares the same name as a builtin command, and which is located in one of your $PATH directories.  Normally, the shell would check for builtin commands first, and only search in $PATH if no builtins were found.  You can ensure your shell won't find any builtin command by disabling the builtin using the `enable` command.  [Here's a link explaining more](https://archive.ph/C6kZc), from O'Reilly's Bash Cookbook.


The `-f` flag is passed when you want to change the source your new command from its original source (the builtin) to a file whose path you specify after the `-f` flag.


In the case of our line of code, after `enable -f`, the first positional argument is the filepath containing the new version of the command we're over-riding, and the 2nd positional argument is the name of the command we're over-riding.


What does `2>/dev/null` do?  According to [StackOverflow](https://web.archive.org/web/20220801111727/https://askubuntu.com/questions/350208/what-does-2-dev-null-mean), the `2>` tells the shell to take the output from file descriptor #2 (aka STDERR) and send it to the destination specified after the `>` character.  Further, "`/dev/null` is the null device it takes any input you want and throws it away. It can be used to suppress any output."  So here we're suppressing any error which is output by the `enable` command, rather than showing it.  If I had to guess, I'd say we're doing that because this is part of an `if` check, and if the `enable` command fails, we don't want to see the error, we just want to move on and execute the code in the `else` block.


What kind of file extension is `.dylib`, and what does that imply about the contents of the file?  I Googled "what is dylib extension" and read a few different results ([here](https://web.archive.org/web/20211023152003/https://fileinfo.com/extension/dylib) and [here](https://web.archive.org/web/20211023142331/https://www.lifewire.com/dylib-file-2620908), in particular).  I read that "dylib" is a contraction of "dynamic library", and that this means it's a library of code which can be loaded on-the-fly (aka "dynamically").  Loading things dynamically (as opposed to eagerly, when the shell or the application which relies on it is first booted up) means you can wait until you actually need the library before loading it, which means you're not taking up memory with code that you're not actually using yet.

Now that we've answered my immediate questions, I'm wondering what is the purpose of the builtin that we over-rode (i.e. `realpath`).  What does it normally do?

The manpage says:

```
REALPATH(1)                                                                       User Commands                                                                      REALPATH(1)

NAME
       realpath - print the resolved path

SYNOPSIS
       realpath [OPTION]... FILE...

DESCRIPTION
       Print the resolved absolute file name; all but the last component must exist
```

"print the resolved path" doesn't feel super-helpful to me.  In what sense is the path that the user provides "resolved"?  What would "unresolved" mean?  It doesn't say.

Let's do some Googling.  I search for "what is realpath unix" and find [the internet equivalent of the same man page](https://web.archive.org/web/20220608150749/https://man7.org/linux/man-pages/man1/realpath.1.html).  But then I find [the `man(3)` page](https://web.archive.org/web/20220629161112/https://man7.org/linux/man-pages/man3/realpath.3.html) for a *function* named `realpath`, which is more detailed and grokkable.  Among other things, it says:

> realpath() expands all symbolic links and resolves references to `/./`, `/../` and extra `/` characters in the null-terminated string named by `path` to produce a canonicalized absolute pathname.

OK, so the `realpath()` function takes something like `~/foo/../bar` and changes it to `/Users/myusername/bar`.  I wonder if the `realpath` builtin calls the `realpath` function?  It seems plausible.

I quickly test this out in my terminal:

```
$ mkdir ~/foo
$ mkdir ~/bar
$ realpath ~/foo/../bar
/Users/myusername/bar
```

A quick note- I initially tried to run the `realpath` command first, without having created the directories, but I got `realpath: /Users/myusername/foo/../bar: No such file or directory`.  So it looks like the file or directory does actually have to exist in order for `realpath` to work.

So that's the original 5 questions answered.  And I now feel like I have a better understanding of what this line of code does: it overrides the existing `realpath` command, but only if the `"${BASH_SOURCE%/*}"/../libexec/rbenv-realpath.dylib` file exists.  I don't see this new filepath in my current version of the RBENV repo that I pulled down, so I am unable to see what this new version of `realpath` does differently from the default version.

But this brings up two questions for me:

Why did the authors need to override the existing `realpath` command?  Wouldn't it have been safer to just call their imported function something else?
And what was wrong with the original `realpath`, anyway?

To answer question #1, I decide to dive into the git and Github history of this line of code.  I start by running the following command in the terminal, in the home directory of the `rbenv` repo that I pulled down from Github:

```
$ git blame libexec/rbenv
```

I get the following output:

<p style="text-align: center">
  <img src="/assets/images/git-blame-output-12mar2023-213pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="git blame output">
</p>

This output is organized in columns: column #1 is the SHA of the commit that added this line to the codebase.  Column #2 is the author of the commit.  Column #3 is the timestamp when the code was committed.  Column #4 is the line number in the file, and Column #5 is the actual line of code itself.

The code I'm trying to research is on [line 23 of the file](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv#L23), so I scan down to the right line number based on the values in column #4, and I see the following:

```
6e02b944 (Mislav Marohnić   2015-10-26 15:53:20 +0100  23) .....
```

So this code was committed on Oct 26, 2015 by Mislav Marohnić, and the commit SHA is 6e02b944.  If we were to run `git checkout 6e02b944`, we'd be telling git to roll all the way back to 2015, making this commit the latest one in our repo.  I plug this SHA into Github's search bar from within the repo's homepage, and I see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-214pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Github search results">
</p>

I click on the one commit that comes back, and see:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-215pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Github search results part 2">
</p>


This shows us what the code was like before this commit, and what it was like after.  In this case, it's not super-helpful, because this commit changed the line of code but not in a way that makes clear what's going on.

Let's try that strategy of rolling back our local version of this repo to an earlier commit, but instead of using the SHA from this commit, let's roll back to the commit *before* this commit.  That way we can re-run `git blame`, get the SHA of the 2nd-to-last commit which altered this line, and repeat the above process.

I run `git checkout 6e02b944~` (the single `~` character means "one commit before this SHA", two `~` characters would mean "two commits before this SHA", etc.).

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
  <img src="/assets/images/searching-for-a-commit-12mar2023-444pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Searching for a commit in the Github repo">
</p>

And when we click on the "Issues" section, we see:

<p style="text-align: center">
  <img src="/assets/images/searching-for-gh-issues-12mar2023-444pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Searching for a commit in the Github repo">
</p>

OK, so judging by the title of the issue, this change has something to do with making rbenv's performance faster.

In general I find that more the descriptions of Issues are more informative than those of Commits, so [let's click on the Issue first](https://github.com/rbenv/rbenv/pull/528):

<p style="text-align: center">
  <img src="/assets/images/gh-issue-528.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Github issue on speeding up rbenv by dynamically loading a compiled command">
</p>

Looks like we were right- the goal of this change was to address a bottleneck in rbenv's performance, i.e. "resolving paths to their absolute locations without symlinks".

To make sure this is the right change, I still think it's a good idea to look at [the Commit link](https://github.com/rbenv/rbenv/commit/5287e2ebf46b8636af653c1c61d4dc0dffd65796) too:

<p style="text-align: center">
  <img src="/assets/images/gh-commit-for-issue-528.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Code for Github issue on speeding up rbenv by dynamically loading a compiled command">
</p>

Yep, so the original code only had one definition of the `abs_dirname` function, and this commit added a 2nd one, as well as the `if/else` logic that checks if the `realpath` re-mapping is successful.  If not, we use the old `abs_dirname` function as before.  I'm still not sure what the difference is between the old and new versions of `realpath`, but I think we can safely assume that the only difference is that it uses a faster algorithm, not that it actually has different output.  If there were such a difference, the dynamic library might well be unsafe to use as a substitute.

Great!  This makes way more sense now.  Let's roll our local copy of the repo forward, back to the one we originally cloned:

```
$ git co master
```

I think, based on the level of bash knowledge we've reached so far, we can quickly knock out the logic inside the `if` clause, which is just a function definition with a body of 3 lines of code:

```
  abs_dirname() {
    local path
    path="$(realpath "$1")"
    echo "${path%/*}"
  }
```

On the first line of the body, we create a local variable named `path`.  On the 2nd line, we set it equal to the return value of our new `realpath` function, when it's passed the first of `abs_dirname`'s arguments.  The last line of code is that we `echo` the new path.  This means the return value of the function is this resolved path, meaning the caller of `abs_dirname` can store the resolved path in a variable of its choosing.  The "%/*" after "path" on line 3 just deletes off any trailing "/" character, as well as anything after it.  We can reproduce that in the terminal:

```
$ path="/foo/bar/baz/"
$ echo ${path%/*}
/foo/bar/baz

$ path="/foo/bar/baz"
$ echo ${path%/*}
/foo/bar
```

Question- on line 2 of the function body, I see double quotes wrapping both "$(...)" and "$1".  Wouldn't this have the effect of wrapping everything *except* "$1" in double quotes?  I.e. wouldn't double-quote #2 close out double-quote #1, and double-quote #3 be the opening of double-quote #4?

(stopping here for the day; 12255 words).

From [this StackOverflow question](https://web.archive.org/web/20220526033039/https://unix.stackexchange.com/questions/289574/nested-double-quotes-in-assignment-with-command-substitution):

> Once one is inside `$(...)`, quoting starts all over from scratch.

OK, simple enough!

Moving on to the first line of the `else` block:

```
[ -z "$RBENV_NATIVE_EXT" ] || abort "failed to load \`realpath' builtin"
```

So if the test inside the single square brackets is falsy, then we `abort` with the quoted error message.  But what is that test?  And why is there a single, escaped backtick before `realpath`, followed by a lone single-quote?  Why not just have opening and closing single-quotes?

The first question is easy enough to answer.  We just run `help test` in our terminal again, and search for `-z` using the forward-slash syntax.  We get:

>  -z string     True if the length of string is zero.

OK, so if the `$RBENV_NATIVE_EXT` environment variable is empty, then the test is truthy.  If that env var has already been set, then the test is falsy, and we would abort.

I'm not sure that my 2nd question is super-important, but I'm also not sure that it's *not* important.  On the surface, it *seems* to relate to the specifics of how the text of the error message is resolved, which doesn't feel like a blocker to me making progress right now.  Nevertheless, it wouldn't hurt to spend 5-10 minutes spiking on what the purpose of the single backtick is.  Who knows, it could lead to something surprising!

Let's try copy-pasting the code after the `||` symbol into a new terminal window:

```
$ abort "failed to load \`realpath' builtin"
zsh: command not found: abort
```

Oh, right.  This `abort` command is actually a function that we defined earlier in this file.  No worries, let's copy that entire function into our terminal and re-run the above code:

<p style="text-align: center">
  <img src="/assets/images/abort-command-in-terminal-12mar2023.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Everything from `Saving session... onwards appears to happen in my terminal due to running `exit 1`.  I verified this by opening another new terminal and just running `exit 1` by itself:

<p style="text-align: center">
  <img src="/assets/images/typing-exit-1-into-terminal-12mar2023.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="typing `exit 1` into the terminal">
</p>

You might well see something different in your terminal, depending on what your terminal startup scripts are (i.e. what's in your .zshrc and .zshenv files).

Oh right!  There's a difference between how zsh and bash operate!  I forgot that I'm supposed to be running tests like this in a bash script, since the "rbenv" file has a bash shebang.  Doy!

Sometimes I beat myself up over forgetting stuff like this.  It's hard to realize that I'm making the same mistakes more than once- it makes me feel like I'm not making forward progress.  And it's something that one of my less-compassionate former managers criticized me for, on more than one occasion.  So when I beat myself up over this, it's their voice I hear in my head, saying "Maybe you're not cut out for this.  Maybe you should go do something else."  Part of why I'm doing this project is to prove them wrong.  Everytime I learn something new or have an a-ha moment, I like to imagine them getting miffed and storming away in a huff.  It's petty, I know.  I'd love it if they weren't living rent-free in my head.  Maybe someday I'll grow out of this and become a better person.  Until then, this is what I have to keep me going lol.

OK, I'll re-run the above tests in my "foo" bash script:

```
#!/usr/bin/env bash

abort() {
  {
    if [ "$#" -eq 0 ]; then cat -
      else echo "rbenv: $*"
    fi
  } >&2
  exit 1
}

abort "failed to load \`realpath' builtin"
```

Running the above results in:

```
$ ./foo
rbenv: failed to load `realpath' builtin
$
```

So our terminal process doesn't get killed when we run the above script.  The process that gets killed when the script runs `exit 1` is the process that our terminal creates (or "spawns", in terminal-speak) when it runs the script.  But when we copy-paste the above script directly in our terminal, then the process that runs the code is the same as the process that's running our terminal tab, so that's why we saw that `[Process completed]` output (and also why we were no longer able to type commands into that terminal tab).

Next line of code:

```
  READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
```

So we're setting a variable called `READLINK` equal to...something.  I'll try to figure out what that is momentarily, but first- why is this variable capitalized here?  I thought capitalization was a convention that is reserved for environment variables, but this variable isn't `export`ed here.  I search for `READLINK` in all-caps elsewhere in the codebase, and I see the following:

<p style="text-align: center">
  <img src="/assets/images/gh-screenshot-12mar2023-517pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Searching the Github repo">
</p>

Of the all-caps results in Github search tool (i.e. the first 3 out of 4 files), not one of them uses a value declared by another file.  So we're definitely not working with an environment variable here.  So why the caps?

I think I may be right on this, judging by [this StackOverflow post](https://web.archive.org/web/20220812210953/https://stackoverflow.com/questions/673055/correct-bash-and-shell-script-variable-capitalization):

<p style="text-align: center">
  <img src="/assets/images/so-screenshot-12mar2023-518pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="StackOverflow post about upper casing for environment variables">
</p>

> If it's your variable, lowercase it.  If you export it, uppercase it.

So I'm *somewhat* more convinced that `READLINK` should ideally be lower-cased, but I'm not *completely* convinced.  For the sake of completeness, I decide to look up the commit which introduced this line of code.  I do my `git blame / git checkout` dance until [I find it in Github](https://github.com/rbenv/rbenv/commit/81bb14e181c556e599e20ca6fdc86fdb690b8995).  The commit message reads:

> readlink comes from GNU coreutils.  On systems without it, rbenv used to spin out of control when it didn't have readlink or greadlink available because it would re-exec the frontend script over and over instead of the worker script in libexec.

And the diff is:

<p style="text-align: center">
  <img src="/assets/images/gh-diff-12mar2023-520pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Github diff">
</p>

It doesn't look like anything which should be capitalized, according to the convention that StackOverflow describes.  Unless I'm missing something, this could well be a candidate for a change / PR.  Such a PR certainly doesn't seem like it would do any *harm*, and it might even help.  After all, if I asked this question and spent some cognitive effort to answer it, perhaps others have as well.

That said, I'll save that decision for a later day, since I want to keep plugging away at this code for now.

Back to the main question: what value are we assigning to the `READLINK` variable?

Let's start with that `type -p` command.  I try `man type` and `help type` in the terminal, but just get the "General Commands Manual" for both.  I Google "bash type command", and [the first result](https://archive.ph/n1OJg) seems somewhat useful:

> The type command is used to find out if command is builtin or external binary file. It also indicate how it would be interpreted if used as a command name...
>
> The -p option is used to find (if) the name of the disk file (external command) would be executed by the shell. It will return nothing if it is not a disk file.

Further down in the search results, I find [a link to Linuxize.com](https://web.archive.org/web/20220527191309/https://linuxize.com/post/linux-type-command/).  In the past, when searching for answers, I've had good experiences with them, so I check their link as well:

> The type command is used to display information about the command type. It will show you how a given command would be interpreted if typed on the command line...
>
> The syntax for the type command is as follows:
>
`type [OPTIONS] FILE_NAME...`
>
> For example, to find the type of the wc command , you would type the following:
>
>`type wc`
>
> The output will be something like this:
>
>`wc is /usr/bin/wc`
>
> You can also provide more than one arguments to the type command:
>
>`type sleep head`
>
> The output will include information about both sleep and head commands:
>
> `sleep is /bin/sleep`
> `head is /usr/bin/head`
>
> The -p option will force type to return the path to the command only if the command is an executable file on the disk:
>
> For example, the following command will not display any output because the pwd command is a shell builtin.
>
`type -p pwd`

This seems to check out: I see no output when I update my `foo` script as follows, and run it:

```
#!/usr/bin/env bash

echo $(type -p pwd)
```

When I change `pwd` in the script to `ls` and re-run it, I see:

```
$ ./foo

/bin/ls
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

echo $(type -p bar baz ls)
```
When I run it, I get:

```
$ ./foo

/Users/myusername/foo/bar /Users/myusername/foo/baz /bin/ls
```

Hmmm, this is a bit unexpected.  The reason I passed two of my own scripts AND the `ls` command is because I was expecting to see just the first two filepaths (i.e. `/Users/myusername/foo/bar` and `/Users/myusername/foo/baz`), NOT `/bin/ls`.  What's happening here?

I re-read the example code and realize that the example they gave was for the `pwd` command, NOT the `ls` command.  I re-run my `./foo` script after replacing `ls` with `pwd`, and I see the expected result of `/Users/myusername/foo/bar /Users/myusername/foo/baz`.

So what's the difference between `pwd` and `ls`?  I run the following in my `foo` script:

```
#!/usr/bin/env bash

echo $(type ls)
echo $(type pwd)
```

```
$ ./foo

ls is /bin/ls
pwd is a shell builtin
```
So `pwd` is a true shell builtin, while `ls` is...not?

[A post on FreeCodeCamp.com](https://web.archive.org/web/20211020190218/https://www.freecodecamp.org/news/bash-commands-bash-ls-bash-head-bash-mv-and-bash-cat-explained-with-examples/) has the answer:

> `ls` is a command on Unix-like operating systems to list contents of a directory, for example folder and file names.

Ah, so `ls` is a Unix command, NOT a shell builtin.  A subtle difference for someone like me, but it just means that `ls` comes from Unix, while `pwd` comes from bash / zsh / etc.

So the reason `/bin/ls` showed up in my output of `type -p` is because `/bin/ls` is a valid "executable file on the disk".  I think that makes sense!

Moving on from `type -p` to `2>/dev/null`.  We already know what this is from yesterday- we're piping any error output from running `type -p` to `/dev/null`, aka the black hole of the console.  But what do we do with any non-error output?  That's answered by the last bit of code from this line: `| head -n1`.  Running `man head` gives us:

```
head – display first lines of a file
...-n count, --lines=count
             Print count lines of each of the specified files.
```
So it seems like `| head -n1` means that we just want the first line of the input that we're piping in from `type -p`?  Let's test this hypothesis.  I run my `foo` script (which currently `echo`'s two lines, see above) and pipe the output:

```
$ ./foo | head -n1

ls is /bin/ls
```
Looks like our hypothesis is correct!

So to sum up this line of code: we're declaring a variable named `READLINK`, and declaring its value to be the first absolute path returned from `type -p greadlink readlink`.  If that command doesn't find any absolute paths, we can assume that the value of `READLINK` will be empty.  And that knowledge comes in handy, because the next line of code is:

```
[ -n "$READLINK" ] || abort "cannot find readlink - are you missing GNU coreutils?"
```

We already learned what `[ -n ...]` does from reading about `$RBENV_DEBUG`.  It returns true if the length of `...` (or, in our case, `$READLINK`) is non-zero.  So if the length of `$READLINK` *is* zero, then we `abort` with the specified error message.

Let's look at the next 3 lines of code together, since it's just a simple function declaration:

```
  resolve_link() {
    $READLINK "$1"
  }
```
Here we resolve `$READLINK` to the absolute filepath of either `greadlink` or `readlink` (since these were the two commands passed to `type -p`, in that order, and `head -n1` will return the first of the two filepaths that were piped to it from `type`).  Passing the filepath here has the effect of returning the filepath to the executable, and we pass that executable an argument (i.e. the "$1").  Note that calling this function doesn't actually execute `greadlink` or `readlink`- if you skip ahead a bit, you can see that's actually done when we call the `resolve_link` function from inside `$( ...)` (aka bash's command substitution feature).  For more info on command substitution, see [this StackOverflow post](https://web.archive.org/web/20220603122201/https://stackoverflow.com/questions/27472540/difference-between-and-in-bash).

Next line of code:

```
  abs_dirname() {

  ...}
```

So here's where we're declaring the version of `abs_dirname` from the `else` block (as an alternative to the `abs_dirname` function in our `if` block above).

Next two lines of code are:

```
    local cwd="$PWD"
    local path="$1"
```

Here we declare two local variables: one named `cwd` (which likely stands for "current working directory", and in which we store the absolute directory of whichever directory we're currently in when we run the `rbenv` command), and one named `path` (which contains the first argument we pass to `abs_dirname`).

Next line of code:

```
while [ -n "$path" ]; do
...done
```

In other words, while the length of our `path` local variable is greater than zero, we do...something.  That something is:

(stopping here for the day 14405 words)

```
      cd "${path%/*}"
      local name="${path##*/}"
      path="$(resolve_link "$name" || true)"
```
The above 3 lines of code are inside the aforementioned `while` loop.  Taken together, they are pretty hard for me to get my head around.  Rather than my usual strategy of deducing their meanings one by one and then piecing them together to form an overall meaning, I decide to use a different strategy.  I'll try adding multiple `echo` statements to the code, seeing what's actually happening overall, and then use that to inform my understanding of the individual lines.  In the past, this has helped me avoid getting too bogged down in my own guesses and hypotheses, and in the process straying too far from what the code actually does.

I update the `while` loop's code to read as follows:

<p style="text-align: center">
  <img src="/assets/images/updating-while-loop-12mar2023-637pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Updating the `while` loop">
</p>

I then re-run `eval "$(rbenv init - )"` so that my changes take effect, and run `rbenv commands`.

Nothing happens.  Hmmm, weird.

I decide to add an `echo` tracer before the `while` loop, to see if I'm reaching this line of code:

<p style="text-align: center">
  <img src="/assets/images/add-echo-tracer-12mar2023-638pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Adding another `echo` statement">
</p>

When I run `eval "$(rbenv init - )"` again, I get:

```
$ eval "$(rbenv init - )"

zsh: command not found: inside
inside rbenv command
```

Oh, right.  If I `echo` from this `rbenv` file, the output is sent to `eval`, and it tries to run `inside rbenv command` as if that string is itself a command.  I change the line slightly, to read as follows:

<p style="text-align: center">
  <img src="/assets/images/adding-echo-tracer-12mar2023-639pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Updating the `echo` statement">
</p>

Note that I could have also changed it to echo to STDERR, instead of STDOUT, as follows:

<p style="text-align: center">
  <img src="/assets/images/alternate-echo-approach-12mar2023-641pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Alternate approach to `echo` statement">
</p>

I sort of like the `>&2` approach, and that's what I'll use, simply because it's fewer keystrokes.  But both tracer strategies accomplish the same goal, so it hardly matters which we choose.

I retry this and now see the following:

```
$ eval "$(rbenv init - )"

inside rbenv command
echo 'inside rbenv command'
```

So we now know we're reaching our tracer statement, but for some reason we're not reaching the code inside the `while` loop.  Maybe that loop is never being run because its conditional check is never truthy?

Let's check if that's the case.  I add another tracer, this time just before the start of the loop:

<p style="text-align: center">
  <img src="/assets/images/add-moar-echo-12mar2023-643pm.png" width="70%" style="border: 1px solid black; padding: 0.5em" alt="Adding yet more `echo` statements">
</p>

Re-running the `rbenv init` line:

```
$ eval "$(rbenv init - )"

inside rbenv command
echo 'inside rbenv command'
```

Still no tracer.  This might (must?) mean that the `abs_dirname` function (which our latest tracer resides in) is not getting called.  I decide to see where it's called, and add more tracers there.  The only other reference to `abs_dirname`, besides the two function definitions inside our `if` and `else` blocks, about 25 lines down:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-645pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I add another tracer just before that line:

<p style="text-align: center">
  <img src="/assets/images/echo-statement-12mar2023-651pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Re-running `rbenv init`:

```
$ eval "$(rbenv init - )"

just before bin_path
inside rbenv command
echo 'inside rbenv command'
```

Weird...so we do see this new tracer, but we don't see the tracers inside the `abs_dirname` definition.

I added the tracers to the 2nd of the 2 definitions of `abs_dirname`...  ohhhhh... Shoot.  This is totally my bad.  I was mis-remembering what condition was checked in the `if`/`else` block.  I thought I remembered that it was checking whether the length of some string was greater than zero.  By extension, I was therefore mistakenly thinking we'd reach the `else` block, not the `if` block.  TL;DR- I was putting my initial tracers in the wrong implementation of `abs_dirname`.

OK, so I *could* move the tracers to the other `abs_dirname`.  But the whole point of the tracers was to see what the body of the `while` loop does, and that `while` loop is in the 2nd implementation of `abs_dirname`.  We already figured out what the 1st version of that function does, so moving the tracers to *that* function would be redundant at this point.  What we want is to force a way for the 2nd version of the function to be used, so that we can see what *it's code* does.  How do we do that?

One way is to just prevent the `if` check from happening.  Why don't we just temporarily comment it out?  Once we've answered our question, we can un-comment it again.

I do the following (note that I also had to comment out the `fi` which closes the `if` block; this happened further down, below the screenshot):

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-653pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Re-running the `rbenv init` command:

```
$ eval "$(rbenv init - )"

before while loop
before: path: /usr/local/bin/rbenv
rbenv: no such command `init'
inside rbenv command
```

I suspect this is because I didn't update my initial `echo` tracer statements inside the `while` loop to print to STDERR, the way I did with my later `echo` statements.  I do this now:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-655pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Re-running:

<p style="text-align: center">
  <img src="/assets/images/much-output-12mar2023-656pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Ah-ha!  This is more output to parse, which means more head-work, but I don't see the `no such command` error, nor any other lines which look like errors.  And indeed, when I run `rbenv commands`, I get the logging statements above, plus a list of commands I can run from `rbenv`:

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

The `while` loop's condition becomes falsy when `[ -n "$path" ]` is falsy.  This happens when the length of `$path` is non-zero (aka greater than zero, since the length can never be less than zero).  The length of "$path" will be greater than zero when the length of `$(resolve_link "$name" || true)` is greater than zero.  Out of curiosity, I check the length of `$(true)` in my "foo" bash script, and I get `0`:

```
#!/usr/bin/env bash

path="$(true)"

echo "length: ${#path}"
```

Running this script results in:

```
$ ./foo

length: 0
```

The `while` loop continuously re-sets the value of `$path` to be `resolve_link "$name"`, until the value that this expression resolves to becomes falsy.  At that point, it sets the value of `$path` to the boolean `true`.  Since the length of the `true` boolean is zero (as is the length of the `false` boolean, FYI), this causes the `while` loop to exit.

OK, so it seems like the purpose of the `while` loop is to keep `cd`ing into successive values of `path` until the value of `resolve_link` is falsy.  And as we learned earlier, the value of `resolve_link is determined by the value of either the `greadlink` or `readlink` commands.  These commands return output if the param you pass it is a symlink pointing to another file, and don't return output if the param you pass it is a non-symlink file.  I verified this by taking the following steps:

-create an executable file named `bar`, and place it inside a directory named `foo`.
-create a symlink to the `foo/bar` file in the same directory as the `foo` directory.  I name the symlink file `baz`.  The command for this is `ln -s foo/bar baz`.
-from the directory containing the symlink, run `readlink baz`.  Verify that the output is `foo/bar`.
-from the same directory, run `readlink foo/bar`.  Verify that nothing is output.
-repeat the last 2 steps, but with `greadlink` instead of `readlink`.  Verify the same output happens.

So the purpose of the `while` link is to allow us to keep `cd`ing until we've arrived at the real, non-symlink home of the command represented by the `$name` variable (in our case, `rbenv`).  When that happens, we exit the `while` loop and run the next two lines of code:

```
pwd
cd "$cwd"
```

`pwd` stands for `print working directory`, which means we `echo` the directory we're currently sitting in.  After we `echo` that, we `cd` back into the directory we were in before we started the `while` loop.  Why do we do this?

What the heck is going on here?  Why is the last statement of this function a call to navigate to our original directory?  Given that the `cd` call is the last item in our function, doesn't that make the return value of the `cd` operation also the return value of our `abs_dirname` function?  And why do we need to print the current working directory beforehand?

At this point I started to wonder whether all these weird things were related.  Specifically, my hypothesis is that the purpose of the call to `cd` is to negate the changes of the `cd`ing which happened inside the `while` loop.  If that's true, I wonder whether the function is somehow returning the value output by `pwd`, given that (at that point) the return value of `pwd` is the same as the canonical directory of the `rbenv` command.  Once we've output that, we wouldn't need to be inside its canonical directory anymore, so it's safe to `cd` back into where we started from.

But how could the value of `pwd` be captured?  True, it's being sent to STDOUT, but that's just like `echo`'ing it to the screen.  It's not actually getting `return`ed, is it?  And at any rate, it's not the last line of code in the function, so it can't possibly be the `return` value, can it?

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

When I Google "bash return value of a function", the first result I see is [a blog post in LinuxJournal.com](https://web.archive.org/web/20220718223538/https://www.linuxjournal.com/content/return-values-bash-functions) which is readable and informative.  Among other things, it tells me:

> Bash functions, unlike functions in most programming languages do not allow you to return a value to the caller. When a bash function ends its return value is its status: zero for success, non-zero for failure.
>
> Although bash has a return statement, the only thing you can specify with it is the function's status, which is a numeric value like the value specified in an exit statement... If a function does not contain a return statement, its status is set based on the status of the last statement executed in the function. To actually return arbitrary values to the caller you must use other mechanisms.
>
> The simplest way to return a value from a bash function is to just set a global variable to the result. Since all variables in bash are global by default this is easy:
>
>```
>function myfunc()
>{
>    myresult='some value'
>}
>
>myfunc
>echo $myresult
>```
>
> The code above sets the global variable myresult to the function result. Reasonably simple, but as we all know, using global variables, particularly in large programs, can lead to difficult to find bugs.
>
> A better approach is to use local variables in your functions. The problem then becomes how do you get the result to the caller. One mechanism is to use command substitution:
>
>```
>function myfunc()
>{
>    local  myresult='some value'
>    echo "$myresult"
>}
>
>result=$(myfunc)   # or result=`myfunc`
>echo $result
>```
>
> Here the result is output to the stdout and the caller uses command substitution to capture the value in a variable. The variable can then be used as needed.
>
> The other way to return a value is to write your function so that it accepts a variable name as part of its command line and then set that variable to the result of the function:
>
>```
>function myfunc()
>{
>    local  __resultvar=$1
>    local  myresult='some value'
>    eval $__resultvar="'$myresult'"
>}
>
>myfunc result
>echo $result
>```
>
> Since we have the name of the variable to set stored in a variable, we can't set the variable directly, we have to use eval to actually do the setting. The eval statement basically tells bash to interpret the line twice, the first interpretation above results in the string result='some value' which is then interpreted once more and ends up setting the caller's variable.

To summarize, the post lets us know that bash functions don't return values in the same way that a regular programming language does, and then outlines 3 strategies to achieve the same effect.  The code in `rbenv` uses strategy # 2.

For reference, the 2nd result in Google was [a StackOverflow post](https://stackoverflow.com/a/17338371/2143275), which provided some helpful extra color:

> Functions in Bash are not functions like in other languages; they're actually commands...Shell commands are connected by pipes (aka streams), and not fundamental or user-defined data types, as in "real" programming languages. There is no such thing like a return value for a command, maybe mostly because there's no real way to declare it...When a command wants to get input it reads it from its input stream, or the argument list. In both cases text strings have to be parsed.  When a command wants to return something, it has to echo it to its output stream. Another often practiced way is to store the return value in dedicated, global variables. Writing to the output stream is clearer and more flexible...As others have written in this thread, the caller can also use command substitution $() to capture the output.

So the way I interpret this is, if you `echo` things from your function, and you call your function inside the bash command substitution syntax (i.e. `$(...)`), the things you `echo` will be the return value of your command substitution.  That fits the pattern of the code inside the `rbenv` file, namely where our `abs_dirname` function is called (see below).  So we can conclusively say that the return value of this 2nd implementation of `abs_dirname` is the result of `pwd`, and the call to `cd "$pwd"` is just cleanup code.

Next few lines of code:

```
if [ -z "${RBENV_ROOT}" ]; then
  RBENV_ROOT="${HOME}/.rbenv"
else
  RBENV_ROOT="${RBENV_ROOT%/}"
fi
export RBENV_ROOT
```

This seems pretty standard.  A quick jog of the memory to see what `-z` does again, and we find out that it returns true if the following value (in this case, "$RBENV_ROOT") has a length of zero.

So if the RBENV_ROOT variable has not been set, then we set it equal to "${HOME}/.rbenv", i.e. the ".rbenv" hidden directory located as a subdir of our UNIX home directory.  If it *has* been set, then we just trim off any trailing "/" character.  Then we export it as a environment variable.

Next few lines of code:

```
if [ -z "${RBENV_DIR}" ]; then
  RBENV_DIR="$PWD"
else
...fi
export RBENV_DIR
```

Here we examine everything except the code inside the `else` block, which we'll look at next.  This block of code is similar to the block before it.  We check if a variable has not yet been set (in this case, `RBENV_DIR` instead of `RBENV_ROOT`).  If it's not yet set, then we set it equal to the current working directory.  Later, once we've exited the `if/else` block, we export `RBENV_DIR` as an environment variable.

Now the code inside the `else` block:

```
  [[ $RBENV_DIR == /* ]] || RBENV_DIR="$PWD/$RBENV_DIR"
  cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"
  RBENV_DIR="$PWD"
  cd "$OLDPWD"
```

The first line of code tries to execute one piece of code (`[[ $RBENV_DIR == /* ]]`), and if that fails, executes a 2nd piece (`RBENV_DIR="$PWD/$RBENV_DIR"`).  The first command it tries is a pattern-match, [according to StackExchange](https://web.archive.org/web/20220628171954/https://unix.stackexchange.com/questions/72039/whats-the-difference-between-single-and-double-equal-signs-in-shell-compari):
> `[[ $a == $b ]]` is not comparison, it's pattern matching. You need `[[ $a == "$b" ]]` for byte-to-byte equality comparison.

Hypothesizing that we're checking to see if `$RBENV_DIR` is a string that represents a directory structure, I write the following test script:

```
#!/usr/bin/env bash

foo='/foo/bar/baz'

if [[ "$foo" == /* ]]; then
  echo "True"
else
  echo "False"
fi
```

I get `True` when I run this script, and `False` when I remove the leading `/` char in `foo` (so that it reads `foo/bar/baz` instead of `/foo/bar/baz`).  So we can confidently say that this first line of code appends the current working directory plus `/` to the front of `RBENV_DIR`, if that variable doesn't start with a `/`.

The next line of code is:

```
cd "$RBENV_DIR" 2>/dev/null || abort "cannot change working directory to \`$RBENV_DIR'"
```

Here we're just attempting to `cd` into our latest version of `$RBENV_DIR`, sending any error message to `/dev/null`, and aborting with a helpful error message if that `cd` attempt fails.

Next line of code is:

```
RBENV_DIR="$PWD"
```

I'm honestly not sure why we're doing this.  Assuming we've reached this line of code, that means we've just `cd`'ed into our current location using the same value of `$RBENV_DIR` that we currently have.  So (to me) this just seems like setting the variable's value to the value it already contains.  It's like saying `a=1; a=1;`.  Given the previous `cd` command succeeded, when would the value of `$PWD` be anything different from the current value of `RBENV_DIR`?  Let's put this question aside for now, and keep going.

The last line of code in the `else` block is:

```
cd "$OLDPWD"
```

Hmmm, we haven't encountered `$OLDPWD` yet.  Is this set somewhere else in the codebase?  A quick Github search says no:

<p style="text-align: center">
  <img src="/assets/images/searching-gh-for-oldpwd-12mar2023.png" width="90%" style="border: 1px solid black; padding: 0.5em" alt="Searching Github for the string '$OLDPWD'">
</p>

Weird.  I'll try Googling it.  The first link that turns up is from a site called [RIP Tutorial](https://web.archive.org/web/20210921235302/https://riptutorial.com/bash/example/16875/-oldpwd).  It's pretty basic, but that's fine because it contains the answer to our question:

> `OLDPWD` (OLDPrintWorkingDirectory) contains directory before the last `cd` command:

```
~> $ cd directory
directory> $ echo $OLDPWD
/home/user
```

So `$OLDPWD` comes standard with our shell.  Good enough!

Next line of code is:

```
export RBENV_DIR
```
Here we just make the result of our `RBENV_DIR` setting into an environment variable, so that it's available elsewhere in the codebase.

Next line of code is:

```
[ -n "$RBENV_ORIG_PATH" ] || export RBENV_ORIG_PATH="$PATH"
```

Here we check if `$RBENV_ORIG_PATH` has been set yet.  If not, we set it equal to our current path and export it as an environment variable.

Next line of code is:

```
shopt -s nullglob
```

I've never seen the `shopt` command before.  I try running `man` and `help` in my `bash` script, but I just get `No manual entry for shopt`.  I turn to Google, and [the first result](https://web.archive.org/web/20220815163336/https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html) is from GNU.org, which says:

> This builtin allows you to change additional shell optional behavior...
> Toggle the values of settings controlling optional shell behavior. The settings can be either those listed below, or, if the -o option is used, those available with the -o option to the set builtin command (see The Set Builtin). With no options, or with the -p option, a list of all settable options is displayed, with an indication of whether or not each is set; if optnames are supplied, the output is restricted to those options.

[The next Google result](https://web.archive.org/web/20220714115608/https://www.computerhope.com/unix/bash/shopt.htm), from ComputerHope.com, adds the following:

> On Unix-like operating systems, shopt is a builtin command of the Bash shell that enables or disables options for the current shell session.

It adds that the job of the `-s` flag is:

> If optnames are specified, set those options. If no optnames are specified, list all options that are currently set.

The option name that we're passing is `nullglob`.  Further down, in the descriptions of the various options, I see the following entry for `nullglob`:

> If set, bash allows patterns which match no files to expand to a null string, rather than themselves.

Lastly, [StackExchange](https://unix.stackexchange.com/a/504591/142469) has an example of what would happen before and after `nullglob` is set:

> Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.

```
$ echo my*file
my*file
$ shopt -s nullglob
$ echo my*file
```

OK, so we're setting a shell option so that we can change the way we pattern-match against files.  I'm still not quite clear on *why* we're doing this, however.  I dig into the git history using my `git blame / git checkout` dance again.  There's only one issue and one commit.  [Here's the issue](https://github.com/rbenv/rbenv/pull/102) with its description:

> The purpose of this branch is to provide a way to install self-contained plugin bundles into the $RBENV_ROOT/plugins directory without any additional configuration. These plugin bundles make use of existing conventions for providing rbenv commands and hooking into core commands.
>
> ...
>
> Say you have a plugin named foo. It provides an rbenv foo command and hooks into the rbenv exec and rbenv which core commands. Its plugin bundle directory structure would be as follows:
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
> When the plugin bundle directory is installed into ~/.rbenv/plugins, the rbenv command will automatically add ~/.rbenv/plugins/foo/bin to $PATH and ~/.rbenv/plugins/foo/etc/rbenv.d/exec:~/.rbenv/plugins/foo/etc/rbenv.d/which to $RBENV_HOOK_PATH.

I think this clarifies not only the `shopt` line, but the next few lines after that:

```
shopt -s nullglob

bin_path="$(abs_dirname "$0")"
for plugin_bin in "${RBENV_ROOT}/plugins/"*/bin; do
  PATH="${plugin_bin}:${PATH}"
done
export PATH="${bin_path}:${PATH}"
```

After adding a few `>&2 echo` statements, I learn that `$0` is `/usr/local/bin/rbenv`, and `bin_path` is `/usr/local/Cellar/rbenv/1.2.0/libexec`.  So for each of the `/bin` folders that are located inside `rbenv`'s `/plugins` subfolder (in other words, for all RBENV plugins we've installed`, we add that `/bin` folder to our `$PATH` folder so we can call the plugin's command from our terminal.  Then we add `/usr/local/Cellar/rbenv/1.2.0/libexec` to the front of our `$PATH`, and re-set `$PATH` to its new value.  This code seems like it's in charge of making any RBENV plugins that we've installed ready-to-use.

I hypothesize that the call to `shopt -s nullglob` seems to be intended to prevent any non-existent directories from being added to `$PATH` by accident, though I could be wrong.  I write a quick experiment script to try and emulate what we see in the `for` loop above:

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

Next line of code is:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${RBENV_ROOT}/rbenv.d"
```
This just resets the current value of `RBENV_HOOK_PATH` to add "${RBENV_ROOT}/rbenv.d" to the end.  But what is "${RBENV_ROOT}/rbenv.d"?  I run `find . -name rbenv.d` and get:

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

(stopping here for the day; 18534 words)

I've seen things ending in ".d" before, but I don't know what I'm supposed to infer from that ending.  I guess I thought it was a file extension of some sort, but here ".d" has been added to the name of a directory, not a file.  I Google ‘what does ".d" stand for bash', and the first two results I see ([this](https://web.archive.org/web/20220619172419/https://unix.stackexchange.com/questions/4029/what-does-the-d-stand-for-in-directory-names) and [this](https://web.archive.org/web/20201130081947/https://serverfault.com/questions/240181/what-does-the-suffix-d-mean-in-linux)) are both from StackExchange.  Some excerpts from these pages:

> "d" stands for directory and such a directory is a collection of configuration files which are often fragments that are included in the main configuration file. The point is to compartmentalize configuration concerns to increase maintainability.
>
> When you have a distinction such as /etc/httpd/conf vs /etc/httpd/conf.d, it is usually the case that /etc/httpd/conf contains various different kinds of configuration files, while a .d directory contains multiple instances of the same configuration file type (such as "modules to load", "sites to enable" etc), and the administrator can add and remove as needed.
>
>...
>
> The main driving force behind the existence of this directory naming convention is for easier package management of configuration files. Whether its rpm, deb or whatever, it is much easier (and probably safer) to be able to drop a file into a directory so that it is auto included into a program's configuration instead of trying to edit a global config file.
>
>...
>
> When distribution packaging became more and more common, it became clear that we needed better ways of forming such configuration files out of multiple fragments, often provided by multiple independent packages. Each package that needs to configure some shared service should be able to manage only its configuration without having to edit a shared configuration file used by other packages.
>
> The most common convention adopted was to permit including a directory full of configuration files, where anything dropped into that directory would become active and part of that configuration. As that convention became more widespread, that directory was usually named after the configuration file that it was replacing or augmenting. But since one cannot have a directory and a file with the same name, some method was required to distinguish, so .d was appended to the end of the configuration file name. Hence, a configuration file /etc/Muttrc was augmented by fragments in /etc/Muttrc.d, /etc/bash_completion was augmented with /etc/bash_completion.d/*, and so forth.
>
> Generally when you see that *.d convention, it means "this is a directory holding a bunch of configuration fragments which will be merged together into configuration for some service."

OK, I think I see now.  So the `.d` suffix means "this is a directory containing configuration files which are compartmentalized in some fashion, and which are meant to be bundled up together into a single aggregate configuration."  And that makes sense, because that actually jives with what we see if we skip a few lines of code ahead.  According to the original PR, an RBENV plugin should include both a `bin` folder and an `etc` folder.  The `etc` folder, in turn, includes an `rbenv.d` folder, which then includes a folder for each "rbenv" command that it wants to hook into.  The loop in the "rbenv" file that we're examining iterates over each of these command sub-directories, and includes that sub-directory in the `RBENV_HOOK_PATH` environment variable.

So taken together, this loop and the `bin_path` loop that we just covered are how RBENV gives a user access to the plugin commands that user has installed.

But let's not get too far ahead of ourselves.  We still have to talk about that 2nd `for` loop and what its code does.

Next bit of code is:

```
if [ "${bin_path%/*}" != "$RBENV_ROOT" ]; then
  # Add rbenv's own `rbenv.d` unless rbenv was cloned to RBENV_ROOT
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${bin_path%/*}/rbenv.d"
fi
```

This looks like more of that pattern-matching that we heard about in the last `for` loop, for `bin_path`.  I suspect this means that, if "$RBENV_ROOT" doesn't contain the string stored in our `bin_path` variable, then we append the "/rbenv.d" directory of our `bin_path` to what will eventually become our "RBENV_HOOK_PATH" environment variable.  And that fits with what the comment on that 2nd line of code tells us.  So the way we detect whether "rbenv was cloned to RBENV_ROOT" is to check whether RBENV_ROOT already contains the value stored in our `bin_path` variable.

Moving on to the next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks"
```
This just means we're further updating RBENV_HOOK_PATH to include more potential RBENV configuration directories, including those inside `/usr/local/etc`, `/etc`, and `/usr/lib/`.

Next few lines of code:

```
for plugin_hook in "${RBENV_ROOT}/plugins/"*/etc/rbenv.d; do
  RBENV_HOOK_PATH="${RBENV_HOOK_PATH}:${plugin_hook}"
done
```
This is that 2nd `for` loop that I mentioned earlier (the one that I skipped ahead to).  This appears to be the main event, where we actually add the configuration for each of RBENV's commands that each of the user's plugins hook into.

Next line of code:

```
RBENV_HOOK_PATH="${RBENV_HOOK_PATH#:}"
```

This syntax is a bit weird.  It's definitely parameter expansion, but I haven't seen the `#:` syntax before.  I search [the GNU docs](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) for "#:" since it looks like a specific kind of expansion pattern, but I don't see those two characters used together anywhere in the docs.  Maybe it's just the "#" pattern I've seen before, for instance when I saw `parameter#/*`, but with `:` instead of `/*`?

Let's try an experiment.  I update my test script to read as follows:

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
In my script, when I update FOO to add a `:` at the beginning (i.e. ':foo:bar/baz/buzz:quox'), and I re-run the script, I see:

```
$ ./bar
foo:bar/baz/buzz:quox
```
So yes, it looks like our hypothesis was correct, and that the parameter expansion is just removing any leading `:` symbol from RBENV_HOOK_PATH.


Next line of code is:

```
export RBENV_HOOK_PATH
```
This should be straightforward- we're just exporting RBENV_HOOK_PATH so that it can be used elsewhere in RBENV's code.

Note that we haven't actually seen yet where RBENV_HOOK_PATH is used.  We'll likely see that sometime in the future, in some other file we encounter.

Next line of code is:

```
shopt -u nullglob
```

This just turns off the `nullglob` option in our shell that we turned on before we started adding plugin configurations.  This is a cleanup step, not too surprising to see it here.

Next few lines of code:

```
command="$1"
case "$command" in
...esac
```

Here's where we get to the meat of this file.  We're grabbing the first argument sent to `rbenv`, and we're deciding what to do with it via a `case` statement.  Everything else we've done in this file, from loading plugins to setting up helper functions like `abort`, has led us to this point.  The internals of that case statement will dictate how RBENV responds to the command the user has entered.

Let's take each branch of the `case` statement in turn:

```
"" )
  { rbenv---version
    rbenv-help
  } | abort
  ;;
```
We've seen the `)` closing parenthesis syntax before.  This (plus the empty string before it) just means that if the first argument is empty (i.e. if the user just types `rbenv` by itself, with no argos), then we do what's in the curly braces (i.e. we call the `rbenv—version` and `rbenv-help` scripts), and we pipe that output to the `abort` command that we defined earlier in this file.  If we try this out in our terminal (i.e. we just type `rbenv` with no argos), we see the version print out, followed by info on how the `rbenv` command is used (its syntax and its possible arguments).

Pretty straightforward.  Next case branch is:

```
-v | --version )
  exec rbenv---version
  ;;
```

So if the argument is "-v" or "--version", then we execute the "rbenv---version" script, whose output we saw earlier (just a one-line output of, in my case, "rbenv 1.2.0").

Next case branch is:

```
-h | --help )
  exec rbenv-help
  ;;
```
If the user types "rbenv -h" or "rbenv –help", we just run the "rbenv-help" script.  Again, no real surprises here.

Next up is:

```
* )
...;;
```
The `* )` line is the catch-all / default case branch.  Any `rbenv` command that wasn't captured by the previous branches will be captured by this branch.  How we handle that is determined by what's inside the branch, starting with the next line:

```
  command_path="$(command -v "rbenv-$command" || true)"
```
Here we're declaring a variable called `command_path`, and setting its value equal to the result of a response from a command substitution.  That command substitution is *either* the result of `command -v "rbenv-$command"`, or (if that result is a falsy value) the simple boolean value `true`.  What is the value of that aforementioned result?  That depends on what the `command` is inside `$(...)`.  It appears to be a shell builtin; I don't think it's the same thing as the `command` variable that we declared at the beginning of the case statement, since if it were then we'd need to refer to it as `"$command"` (including the dollar sign and double-quotes).

I update my `./bar` bash script to simply run `help command`, since when I run `help command` in my `zsh` shell I just get the General Commands Manual.  I get the following:

```
$ ./bar
command: command [-pVv] command [arg ...]
    Runs COMMAND with ARGS ignoring shell functions.  If you have a shell
    function called `ls', and you wish to call the command `ls', you can
    say "command ls".  If the -p option is given, a default value is used
    for PATH that is guaranteed to find all of the standard utilities.  If
    the -V or -v option is given, a string is printed describing COMMAND.
    The -V option produces a more verbose description.
```

OK, so `command foo` is the same as running the `foo` command directly in your terminal.  I test this by adding the `~/foo` directory (which contains my `bar` script) into my $PATH variable, and running `command bar` in my terminal.  I get the same `command: command [-pVv] command [arg ...]` output that I mentioned above.

So this is a useful way of running commands whose named are dynamically interpreted in a script, such as `command -v "rbenv-$command"` inside our command substitution.

As the `help` description mentions, the `-v` flag prints a description of the command you're running.  When I pass `-v` to `command bar` in my terminal, I see `/Users/myusername/foo/bar` *instead of* the regular output of my `bar` script.  It makes sense to me that this is the path to my `bar` script, because this will end up being the string that we store in the variable named `command_path`.

So to sum up this line of code, we use command substitution to try and get the path to the command that the user passed to the `rbenv` script.  If there is no path, then we pass the boolean `true` to the command substitution.

Recall from earlier that passing a boolean to a command substitution results in a response with a length of zero.  That knowledge is useful when interpreting our next line of code:

```
if [ -z "$command_path" ]; then
  ...fi
```

In other words, if the user's input doesn't correspond to an actual command path, then we execute the code inside this `if` block.  That code is:

```
    if [ "$command" == "shell" ]; then
      abort "shell integration not enabled. Run \`rbenv init' for instructions."
    else
      abort "no such command \`$command'"
    fi
```
So if the user's input was the string "shell", then we abort with one error message ("shell integration not enabled. Run \`rbenv init' for instructions.").  Otherwise, we abort with a different error message ("no such command \`$command'").  I'm able to reproduce the `else` case by simply running `rbenv foobar` in my terminal.  However, when I try to reproduce the `if` case by running `rbenv shell`, I get something unexpected:

```
$ rbenv shell
rbenv: no shell-specific version configured
```

The error message "rbenv: no shell-specific version configured" is not the same as the message in the `if` block.  Why is that?

(stopping here for the day; 20542 words)

I'm reasonably confident that we at least reach [line 110](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L110) of this file, so I put tracer statements there and in a few lines before that, all the way up to line 98:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-731pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

When I `eval` my code and re-run `rbenv shell`, I see something unexpected:

```
$ rbenv shell

command at line 98: sh-shell
command_path: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-sh-shell
pwd: /Users/myusername/Workspace/OpenSource/rbenv
command: sh-shell
rbenv: no shell-specific version configured
```

Somehow, the string `sh-` is being prepended to my argument.  I didn't notice this same thing happening when I ran `eval` a moment ago (which runs `rbenv init`, if you recall).  Instead, `eval` outputs the following:

```
$ eval "$(rbenv init - )"

command at line 98: init
command_path: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-init
pwd: /Users/myusername/Workspace/OpenSource/rbenv
command: init
```

Where (and why) is `sh-` being prepended?

The weird thing is that it appears to have already happened by the time we store `$1` in the `command` variable.  But I thought `$1` represents the first terminal argument in its original form, before any application code has touched it.  So either something is altering the arguments before they get to this point (which I'm not sure is even possible, and if it were, it would feel kind of hacky), or the code in the `rbenv` file (i.e. the `rbenv` command itself) is being called from elsewhere in the codebase and prepending `sh-` to it, but only for certain commands (this seems more likely).

I do a search in the Github repo for the string "sh-", thinking that if that string is being added by some application code, then it will have to exist somewhere in the codebase.  I see the following:

<p style="text-align: center">
  <img src="/assets/images/searching-gh-for-sh-prefix.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

That 2nd result looks interesting.  I'm not 100% on the parameter expansion that's taking place on line 117, but it looks like if that condition is met, then `rbenv` is called with the command `sh-$command`, which would fit the description of the more likely scenario we described above.  But what does the plural `commands` evaluate to within that file (`libexec/rbenv-init`)?  I open it up to find out:

<p style="text-align: center">
  <img src="/assets/images/search-continues-for-sh-prefix-12mar2023-737pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

It looks like it's the result of running `rbenv-commands --sh`.  I run this same command, and get:

```
$ eval "$(rbenv init - )"

command at line 98: commands
command_path: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-commands
pwd: /Users/myusername/Workspace/OpenSource/rbenv
command: commands
rehash
shell
```

I still have those tracer statements in my code so there's a bit of noise, but if we ignore those, the important lines are the last two:

```
rehash
shell
```

At this point, I have a pretty confident working hypothesis that the block of code we're currently examining in `rbenv-init` is executed whenever we run an `rbenv` command, and that if the argument we pass to `rbenv` is either `rehash` or `shell`, then the code prepends `sh-` to the command.  The only part of that hypothesis which I'm not 100% sure on is the first part- why and how would the code in `rbenv-init` be executed on every command run?  I thought that code was only executed once, when we "init" or initialize RBENV itself?

I add a tracer statement to `rbenv-init` to see whether that statement gets hit on a non-init rbenv command:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-738pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

My tracer statement gets hit when I run `eval`:

```
$ eval "$(rbenv init - )"

command at line 98: init
command_path: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-init
pwd: /Users/myusername/foo
command: init
rehash
shell
```

But *not* when I run `rbenv shell`:

```
$ rbenv shell

command at line 98: sh-shell
command_path: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-sh-shell
pwd: /Users/myusername/foo
command: sh-shell
rbenv: no shell-specific version configured
```

However, I notice something interesting just below my tracer, on line 110:

```
case "$shell" in
fish )
  cat <<EOS
function rbenv
  set command \$argv[1]
  set -e argv[1]
  switch "\$command"
  case ${commands[*]}
    rbenv "sh-\$command" \$argv|source
  case '*'
    command rbenv "\$command" \$argv
  end
end
EOS
```
I can understand the gist of this: We have a case statement that branches based on the value of a variable named `$shell`.  If the user's shell is the fish shell (an alternative to bash, zsh, etc.), then we print a string to STDOUT (presumably so it can be `eval`'ed by the runner of the script, as we've seen happen elsewhere).

Interestingly, that string is a definition of a function named `rbenv`!

I examine each of the branches in this case statement, and I see branches for `fish`, `ksh`, and and a default catch-all `* )` at the end, which presumably handles shells like `bash` and `zsh`.  That branch's logic is simpler: it `cat`s a string which opens (but doesn't close) the new `rbenv()` function:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-742pm.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

A few lines down, another `cat` statement appears which finishes the function's definition:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-744pm.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

Here we again see similar logic around prepending `sh-` to the command that gets executed.

I don't want to spend too much time diving into this code; we'll get to it when we dissect the `rbenv-init` file itself (which I may decide to do next, given it appears to affect how the current file is executed).  But I do just want to add one last tracer statement to this `rbenv()` function, to see whether it really is the function that's being executed here.  I think it's worth confirming my understanding up to this point, before we move on and wrap up the `rbenv` file.

I add a tracer to just before the line of code in the `rbenv-init` file which concatenates `sh-` to the command:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-745pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I then re-run `eval` and run `rbenv shell`.  I see the following:

```
$ rbenv shell

line 150 of rbenv function definition
command at line 98: sh-shell
command_path: /usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-sh-shell
pwd: /Users/myusername/foo
command: sh-shell
rbenv: no shell-specific version configured
```

There's my newest tracer statement!  So we can be reasonably confident that we now know where `sh-` gets prepended to the command.  We still don't know *why* this is happening, though.  To answer that question, we'll probably have to dive into the Github history.  But we'll save that question for our examination of `rbenv-init`, so that we can unblock ourselves.

Before we get back to the `rbenv` file, let's clean up all the tracer statements we added today, and re-run `rbenv shell` to make sure they're all gone:

```
$ eval "$( rbenv init - )"
$ rbenv shell
rbenv: no shell-specific version configured
```

So going back to an earlier question of "Why don't we see the expected output when running `rbenv shell`?"  The reason for this is that the condition inside line 111 is false.  The reason it's false is because the length of the `command_path` variable is greater-than-zero.  The reason its length is greater-than-zero is because `command -v "rbenv-$command"` returned a value.  And the reason it returned a value is because it found a file named `rbenv-sh-shell` inside the `libexec` directory.

Something else dawns on me a bit later.  This new knowledge also represents the answer to a question that I asked myself a few days ago, but didn't write down because I didn't want to get distracted.  That question was, "When I type `which rbenv` in my terminal, why do I see the following instead of a simple path to an executable file?

```
$ which rbenv

rbenv () {
	local command
	command="${1:-}"
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

The answer is that, when you give the `which` command an argument, it looks for that argument name among the locally-defined functions before it starts checking the directories in the $PATH environment variable.  It stops at the first match it finds, which in this case is the function that `init` defined.

(stopping here for the day; 21619 words)

Moving on to the next line of code:

```
shift 1
```
This just shifts the first argument off the list of `rbenv`'s arguments.  The argument we're removing was previously stored in the `command` variable, so we don't need it on the shell's list of arguments anymore.  It's not strictly necessary to remove it, as far as I know- I suspect we could leave it where it is and access the next argument with `$2` instead.  It's probably a matter of style and preference.

Next line of code:

```
if [ "$1" = --help ]; then
 ...else
...fi
;;
```
Remember that, since we shifted off the `command` argument in the previous line, we now have a new value for "$1".  Here we check whether that new first arg is equal to the string "--help".  An example of this would be if the user types "rbenv init –help".  If we've reached this line of code, we know that the command is a valid RBENV command, because the previous "if" block's job was to `abort` if the command that the user entered didn't correspond to a valid command path.

Also interestingly, the code authors didn't wrap "--help" in quotes here, so that's another difference between bash and a regular language like Ruby- you don't need to wrap your strings in quotes.  I probably still will, lol.

Next line of code:

```
    if [[ "$command" == "sh-"* ]]; then
      echo "rbenv help \"$command\""
    else
      exec rbenv-help "$command"
    fi
```

In the first half of this conditional (the "if" block), we see that if the user had previously entered a value that started with "sh-" for their *original* first arg (before we shifted it off the list), AND their original *2nd* arg (now arg #1) is equal to "--help"), then we print "rbenv help "$command" to STDOUT.

I try this in my terminal by typing "rbenv sh-shell –help", and I see the following:

```
$ rbenv sh-shell --help

rbenv help "sh-shell"
```

This is actually *not* what I expect, since printing `rbenv help "sh-shell"` to STDOUT should cause the caller of our code to `exec` the above command, NOT to just print it to the screen.

To figure this out, I realize I'm going to need to put tracer statements into the `rbenv` function, the one that gets dynamically compiled when running `rbenv init`.  This feels like a lot of work to answer a relatively trivial question, and I wouldn't blame the reader if they decided it wasn't worthwhile.  But I know this question will gnaw at me and take up cognitive load in my head, so I decide to timebox it at 10 minutes.

I add tracers on lines 143, 145, 151, 154, and 155 of the "rbenv-init" file(see below):

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-749pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I then re-run `eval` and then run `rbenv sh-shell –help`:

```
$ rbenv sh-shell --help

command inside rbenv func: sh-shell
inside if of rbenv func
inside catch-all of case statement
command inside catch-all: sh-shell
command: sh-shell
inside if block
rbenv help "sh-shell"
```

Everything from "command: sh-shell" onwards is from tracer statements inside the "rbenv" file.  Everything up to that point is from tracer statements inside "rbenv-init".

I see we reached the `command inside catch-all: sh-shell` tracer statement, meaning the next line of code to be executed is `command rbenv "\$command" "\$@";;`.  I suspect that this resolves to `command rbenv sh-shell --help`, and when I run this resolved command in my terminal, I see:

```
$ command rbenv sh-shell --help
command: sh-shell
inside if block
rbenv help "sh-shell"
```
This is the code I expected, given what we've already seen.  I suspect the execution is reaching the `rbenv-sh-shell` file.  Although I'm rapidly losing my motivation to keep this investigation going, I decide it's pretty easy to at least add some tracer statements to that file.  If adding these tracers sheds light on anything, it might boost my motivation, so that's what I (grudgingly) do.

I add a single tracer statement to start with, as the first line of executable code in `rbenv-sh-shell`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-750pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Although I don't think I need to run `eval` again, I do it anyway just to be safe.  Then I re-run `rbenv sh-shell --help` and see:

```
$ rbenv sh-shell --help

command inside rbenv func: sh-shell
inside if of rbenv func
inside catch-all of case statement
command inside catch-all: sh-shell
command: sh-shell
inside if block
rbenv help "sh-shell"
```

Interesting: I don't see my tracer statement.  I try removing the redirect to STDERR (i.e. the `>&2` at the beginning of the tracer) and re-run it:

```
$ rbenv sh-shell --help

command inside rbenv func: sh-shell
inside if of rbenv func
inside catch-all of case statement
command inside catch-all: sh-shell
command: sh-shell
inside if block
rbenv help "sh-shell"
```

Still no tracer.  Looks like my hypothesis that we've reached the `rbenv-sh-shell` file is incorrect.

At this point, I'm wondering whether I have the right expectation about this `echo` statement inside the `if` block of the `rbenv` file:

<p style="text-align: center">
  <img src="/assets/images/screenshot-12mar2023-751pm.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

More specifically, I'm wondering whether `echo`ing to STDOUT here really does trickle up to the caller (who then runs `eval` on it), or whether *this* echo actually does `echo` to the screen.

I think I can test this by doing a similar `echo` statement which doesn't correspond to a valid terminal command, and seeing whether I get some sort of "invalid command" error.  Or even simpler, I could just remove the `>&2` redirect on line 124, and see if the word "inside" triggers that same "invalid command" error.  If these echo statements are being `eval`ed by the caller of the `rbenv` file, then my `echo "inside if block"` should trigger the error I expect when I direct the "echo" to STDOUT as opposed to STDERR (as I'm doing now).

I remove ">&2" and re-run the code:

```
$ rbenv sh-shell --help

command inside rbenv func: sh-shell
inside if of rbenv func
inside catch-all of case statement
command inside catch-all: sh-shell
command: sh-shell
inside if block
rbenv help "sh-shell"
```

I continue to see my "inside if block" tracer statement, without any "invalid command" error.  Looks like the "echo" statement on line 125 really is an "echo", and not meant to be "eval"ed by another line of code somewhere.

OK, so now I think I at least understand the path of execution.  If we've reached the "else" block, we can assume that the user's command did *not* begin with "sh-", AND that the 2nd argument was "--help", AND that the "command" they entered is a valid RBENV command.  So we show them the `help` script for the command they entered.

But I'm still not sure *why we needed* the "if" block of code here.  At this point we know enough to tell the user which command they *should have* run.  Why don't we just run it for them and save them a step?

I think that's an important question to ask at some point, but I don't want to lose my forward momentum.  I decide to start [a running list of questions](https://docs.google.com/document/d/1yhR5_Z5JoAB4I0ZsA8qPxCwfTBMuWSYRAGv7vBvys-Y/edit?usp=sharing) to come back and revisit at a later time.  I capture this one and a few other related ones.  I think answering this question would require a deep dive into the Github history of this section of the code, and while I think that's a worthwhile activity to do, I don't think now is the time to do it.  I could be wrong about that, but I'm guided by a preference for "going broad" and getting a basic understanding of the overall codebase, before "going deep" and diving into the history of one specific part.  It might just be a matter of personal preference, and this whole thing is an experiment anyway, so after I'm done writing this book, I'll revisit the strategy to judge its success.

Next line of code:

```
  else
    exec "$command_path" "$@"
```

(stopping here for the day; 22757 lines of code)

This is the line of code which actually executes the command that the user typed.  The "$@" is just how we pass in any flags or arguments to that command.

As a side note, this could have / should have been a hint to me that the above "echo" command really was a true "echo", and not a signal to the calling code about which command to exec.  I think it would have helped if the text that was echo'ed was clearly not a command, for example by prefixing it with the "usage: " string that is used elsewhere.  But just the fact that the "if" branch uses "echo" while the "else" branch uses "exec" is a signal that, at this layer of abstraction, we are not "echo"ing commands for someone else to run.  Same with the "exec" block in the earlier "else" block of code above.

That's it!  That's the entire `rbenv` file.  What should we do next?

Normally I'd want to copy the order in which the files appear in the "libexec" directory.  But given what we saw with "rbenv-init" and how it has a big effect on how the "rbenv" file is called, I think it makes more sense to start there and come back to the next file ("rbenv–-version") afterward.

