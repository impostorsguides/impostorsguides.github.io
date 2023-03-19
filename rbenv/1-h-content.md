We'll cover the tests first, and the code afterward.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/commands.bats)

After the `bats` shebang and the loading of `test_helper`, the first test is:

```
@test "commands" {
  run rbenv-commands
  assert_success
  assert_line "init"
  assert_line "rehash"
  assert_line "shell"
  refute_line "sh-shell"
  assert_line "echo"
}
```

This is the happy-path test, covering [this `for` loop](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L27).  The test runs the regular `rbenv-commands` command, asserts that it was successful, and asserts that certain commands are listed among the output printed to STDOUT.

We also explicitly assert that the line “sh-shell” does *not* appear in the output.  We want to ensure that the “shell” command is presented to the user when they run `rbenv commands`, but that command's logic lives in a file named `rbenv-sh-shell` (because the path it takes during execution branches depending on which shell program the user is running), and when we scrape the list of command files in order to generate the output of `rbenv commands`, we want to strip out the `sh-` prefix since the user is not meant to type `rbenv sh-shell` when they run this command.

Next test:

```
@test "commands --sh" {
  run rbenv-commands --sh
  assert_success
  refute_line "init"
  assert_line "shell"
}
```

This test covers [this block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L15), as well as the 4-line block of code from lines 30-33 (starting [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L30)).  We run the same command as before, but we pass the “--sh” flag.  This time we assert that commands with no “sh-” prefix in their filenames (such as the “init” command) are excluded from the printed output, and commands *with* that prefix (such as “shell”) are included.

Next test:

```
@test "commands in path with spaces" {
  path="${RBENV_TEST_DIR}/my commands"
  cmd="${path}/rbenv-sh-hello"
  mkdir -p "$path"
  touch "$cmd"
  chmod +x "$cmd"

  PATH="${path}:$PATH" run rbenv-commands --sh
  assert_success
  assert_line "hello"
}
```

To set up this test, we make a directory whose name includes a space character, and we make an executable command within that directory called “rbenv-sh-hello”.  We then add that directory name to our `$PATH` environment variable.  When we run the `commands` command, we pass the “--sh” flag.  We assert that the command was successful, and that the “sh-” prefix was removed from the command name before it was printed to STDOUT.

Last test for this command:

```
@test "commands --no-sh" {
  run rbenv-commands --no-sh
  assert_success
  assert_line "init"
  refute_line "shell"
}
```

This test covers [this 4-line block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L18-L21), as well as [this 4-line block of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L34-L37).  It's the inverse of the "commands --sh" test, in that we expect commands whose files do *not* contain the “sh-” prefix in their name to be printed to STDOUT, and we explicitly expect commands which *do* contain that prefix in their filenames to be excluded from the output.

With the tests for this command out of the way, let's move on to the code for the command itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands)

First few lines:

```
#!/usr/bin/env bash
# Summary: List all available rbenv commands
# Usage: rbenv commands [--sh|--no-sh]

set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

This is the same beginning as most of the files we've encountered so far: shebang, comments summarizing the purpose and usage of the command, and setting the shell options to exit on first error and to set verbose mode if the user turns debug mode on.  At some point I may start to skip these lines when we consider new files.

Next lines of code:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --sh
  echo --no-sh
  exit
fi
```
We've seen this before as well, in `rbenv-init`.  If the user types `rbenv commands --complete`, we echo the two flags shown here (`--sh` and --no-sh`), and then exit the script.  This tells the user which flags are acceptable from this flag.

Note that we did *not* see this `if` conditional in `rbenv---version`.  That's because we don't expose a `--complete` option for `rbenv --version`.

Next lines of code:

```
if [ "$1" = "--sh" ]; then
  sh=1
  shift
elif [ "$1" = "--no-sh" ]; then
  nosh=1
  shift
fi
```

If the user has typed `rbenv commands --sh`, we set the `sh` variable to 1.  Otherwise, if the user has typed in `--no-sh`, we set the `nosh` variable to 1.  `sh` is used later if we just want to see the commands `shell` and `rehash`, and `nosh` is used if we want to see all commands except those two.

This might be a good point at which to investigate why `shell` and `rehash` are treated differently from the other commands.  I look for the git commit which introduced this code.  There are a few SHAs mentioned in the `git blame` for the above lines of code.  I pick the oldest one: `5a4bee6e`.  [The PR containing this commit](https://github.com/rbenv/rbenv/pull/57) has the following description:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-828am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

After reading and re-reading this a few times, I think I have an idea of what's going on.  It seems like the original purpose of the `sh-` prefix was to allow developers to add their own custom shell commands?  And the reason they needed a special prefix was because those commands needed to be called by `eval` [here](https://github.com/rbenv/rbenv/pull/57/files#diff-fde6791214061a6ba8c036bfa0a278968bf11ceab83070561591834ee1befd6eR78), instead of by `command` [here](https://github.com/rbenv/rbenv/pull/57/files#diff-fde6791214061a6ba8c036bfa0a278968bf11ceab83070561591834ee1befd6eR80).  This was so that the special commands would be run in a scope which would allow them to modify environment variables (which they may want or need to do).

But we already saw when we looked at `rbenv-init` that there is a whole process for including the folders in the `/plugins` directory.  Does that mean the `--sh` and `--no-sh` flags are now superfluous?  Still not sure.

Let's keep going.  Next line of code:

```
IFS=: paths=($PATH)
```

This sets the `IFS` environment variable equal to `:`, and in the same line of code stores the value of `$PATH` inside the variable `paths`.  We need to set `IFS` while running this command because `$PATH` evaluates to a series of directories delimited by the `:` character, and the author wanted to store these paths as an array of strings split according to the delimiter, not as a single long string with the delimiters included.

We can verify this with a quick test script:

```
#!/usr/bin/env bash

echo "size of PATH: ${#PATH}"

IFS=: paths=($PATH)

echo "size of PATH: ${#paths}"
```

We first echo the size of the un-split “$PATH” variable.  Remember, the `#` char inside the parameter expansion, before your parameter, tells bash to expand the expansion to the size of the parameter.  Since `PATH` is a single long string here, the size will be the # of characters in the string.  Then we create a new variable, `paths`, which is the PATH string split into an array according to the delimiter we set.  We then echo the size of that new variable.  When we run this script, we get:

```
$ ./foo

size of PATH: 1246
size of paths: 32
```

The size of the original string (on my machine) is 1246 characters, but the size of the array is 32 array items (i.e. 32 directories).

Next line of code:

```
shopt -s nullglob
```

Earlier in this post, we saw that this line sets the `nullglob` shell option, which:

> If set, bash allows patterns which match no files to expand to a null string, rather than themselves.

I'm guessing this means that, if there's a directory in the user's PATH which doesn't exist anymore, it gets expanded to a null string.  This is just meant to prevent any errors if the user has a crufty directory in their PATH.  I could be wrong though; maybe we'll find out as we keep reading.

Next lines:

```
{ for path in "${paths[@]}"; do
  ...
  done
} | sort | uniq
```

We iterate over each path in our `paths` array, and do something with it.  Then we take the results of that something, and pipe it to `sort`.  I *think* this means we can assume that the output of the code inside the `for` loop is a series of strings.  We then take the results of that `sort` operation, and grab just the unique values.

We have to `sort` first before we can call `uniq`, because `uniq` wouldn't remove any duplicate items unless they were next to each other on the output.  For example, it wouldn't remove the duplicates in the following output:

```
Foo
Bar
Foo
```

Next lines of code:

```
    for command in "${path}/rbenv-"*; do
    ...
    done
```

For each of the `path`s in our outer `for` loop, we look for any file beginning with `rbenv-`, and we assume it's a command.

 - I tested this by doing the following:
 - I made a directory in my Home directory called “~/foo”.
 - I added this directory to my PATH (`PATH=~/foo:$PATH`).
 - I added a file inside ~/foo called `rbenv-foo`, which looks like this:

```
#!/usr/bin/env bash

echo "Foo!"
```
 - I ran `chmod +x ~/foo/rbenv-foo` to make sure it was executable.
 - I ran `rbenv commands` and verified that `foo` was one of the commands listed.
 - I ran `rbenv foo` and saw “Foo!” printed out to my screen:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-835am.png" width="50%" style="border: 1px solid black; padding: 0.5em">
</p>

Next lines:

```
      command="${command##*rbenv-}"
```
This line takes the value of `command` defined in the inner `for` loop (i.e. `/usr/local/Cellar/rbenv/1.2.0/libexec/rbenv-completions`) and changes it to just the value after the last hyphen (i.e. `commands`).  According to [StackExchange](https://archive.ph/UgqfS), the `##` tells the shell to remove the longest-possible match of the subsequent pattern, in this case `*rbenv-`.  The `*` means that the pattern can be expanded to include any text ending in `rbenv-`.  So the shell removes the `rbenv-` text, *plus* everything before it (i.e. `/usr/local/Cellar/rbenv/1.2.0/libexec/`).

Next lines:

```
      if [ -n "$sh" ]; then
        if [ "${command:0:3}" = "sh-" ]; then
          echo "${command##sh-}"
        fi
```
The outer `if` conditional checks if the `sh` variable was set, i.e. if the user passed the `--sh` flag.  If they did, then we only want to echo commands which start with `sh-`.  So we check whether our newly-shortened `command` variable (i.e. `init`, `global`, `rehash`, etc.) starts with `sh-`.  If it does, then we print the variable, minus its `sh-` prefix.

Next lines of code:

```
      elif [ -n "$nosh" ]; then
        if [ "${command:0:3}" != "sh-" ]; then
          echo "${command##sh-}"
        fi
```

If we've reached this block, then we know that the user didn't pass the `--sh` flag.  The `elif` line checks whether the `nosh` variable was set, i.e. if the user passed the `--no-sh` flag.  If they did, then we check whether our `command` variable *does not* begin with `sh-`.  If it indeed does not, then we print the command minus any `sh-` prefix.

I'm not entirely sure why the `##sh-` expansion is needed here, given the inner `if` check should have ensured that the command doesn't have that prefix.

Last lines of code in this file:

```
      else
        echo "${command##sh-}"
      fi
```

If the user didn't pass either the `--sh` or the `--no-sh` flag, then we want to echo all commands, whether they start with `sh-` or not.

(stopping here for the day; 31137 words)

While I was reading through the code yesterday, I noticed that the `rbenv-commands` file has a corresponding test file called `commands.bats`.  I had never heard of the `.bats` extension before, so I decided to Google it.  Nothing came up on Google's page 1 when I tried “bats file extension”, but when I Googled “how to run bats test”, the first result was [this Github repo](https://github.com/sstephenson/bats), which I noticed was maintained by [Github user Sam Stephenson](https://github.com/sstephenson), the same person who I've seen author many commits in the RBENV repo.  In fact, I suspect he is the original author of RBENV, though I haven't bothered to research that (TO-DO- actually do that).

The `bats` repo is archived, meaning there won't be further updates to it, but I still want to see if the code works and can be used to run tests in the `rbenv` repo.  I'd be surprised if it didn't, since RBENV is still maintained and therefore still needs a way to run its own tests.

I follow the installation instructions [here](https://github.com/sstephenson).  I get tripped up a little, because I initially try to run the `./install.sh /usr/local` command without running `sudo` and get `Permission denied`.  I then try to re-run it with `sudo` as per the instructions, but I get `file exists`.  I figure out that this is because the install script is trying to create a file that already exists (hence the error), so I comment out that line of code and re-run with `sudo`, and it's all good.

I then go back into back into the `rbenv` directory and look at [the test script](https://github.com/rbenv/rbenv/blob/baf7656d2f1570a3b2d5a7e70d5bfcc52fe0428a/test/commands.bats) more closely.  I see that, instead of a `bash` shebang, it uses a `bats` shebang.  This means that, now that I have `bats` installed in my `$PATH`, running the script should Just Work.  I run the following from within my `~/Workspace/OpenSource/rbenv/test` directory:

```
$ ./commands.bats

 ✓ commands
 ✓ commands --sh
 ✓ commands in path with spaces
 ✓ commands --no-sh

4 tests, 0 failures
```
Indeed, running the test file works and the tests are passing!

What I want now is a way to run all the spec files at once, without having to call them individually.  I see a file inside `/test` named `run`, which looks promising from the filename.  I try running it from within `/test`, but I get an error:

```
$ ./run

bats: /Users/myusername/Workspace/OpenSource/rbenv/test/test does not exist
```

I notice the `/rbenv/test/test` filepath, which I'm not surprised doesn't exist.  I wonder if it's assuming that I'm running the `run` file from the root directory, and is therefore looking for the `/test` subdirectory in whichever directory it's currently in.  I `cd..` and re-run `./test/run`, and this works:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-836am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

...

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-837am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Awesome, now I have a complete suite of running tests!

So now that these specs are running, what do they actually do?  Reading the tests for a piece of code you're studying is often a great source of documentation.  And the BATS repo has [helpful documentation](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/README.md#writing-tests) on the commands it offers and the API it exposes.

Let's look at the `commands.bats` spec:

```
load test_helper
```

Without getting too in-the-weeds, the `load` command comes from the BATS repo.  Here's [the docs on that command](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/README.md#load-share-common-code).  The above line of code loads a file called `test_helper` in the `rbenv` repo, which defines functions like `assert_success` and `assert_line` which make our `commands.bats` file easier to read and write.

The syntax is pretty readable, IMHO.  The first spec looks like this:

```
@test "commands" {
  run rbenv-commands
  assert_success
  assert_line "init"
  assert_line "rehash"
  assert_line "shell"
  refute_line "sh-shell"
  assert_line "echo"
}
```

According to the BATS docs, the `run` command runs the `rbenv-commands` file (which it will have access to by the time it reaches this scope), and saves certain results of that command (such as the exit status and the output to STDOUT).  This is what allows us to run the helper functions that we got from the test_helper file.  Here we assert that the exit status was 0 (`assert_success`), and that the output contained the lines “init”, “rehash”, “shell”, and “echo”, and did *not* contain the line “sh-shell”.  There are way more commands in the output of “rbenv commands” than just the 4 that we assert against (ex. “hooks”, “global”, “version”, etc.), so it's possible that this test could stand to be improved.  But it's also possible that the authors felt that testing for a subset of commands was sufficient.

The next test is:

```
@test "commands --sh" {
  run rbenv-commands --sh
  assert_success
  refute_line "init"
  assert_line "shell"
}
```

Here we run `rbenv commands` with the `–sh` flag, assert that the exit code was 0, assert that the output included “shell”, and assert that the output did NOT include “init”.

Next test is:

```
@test "commands in path with spaces" {
  path="${RBENV_TEST_DIR}/my commands"
  cmd="${path}/rbenv-sh-hello"
  mkdir -p "$path"
  touch "$cmd"
  chmod +x "$cmd"

  PATH="${path}:$PATH" run rbenv-commands --sh
  assert_success
  assert_line "hello"
}
```

Here we create a directory with a space in its name, create an `sh-` command inside that directory, make the command executable via `chmod +x`, and run `rbenv commands --sh`.  We then assert that the new command shows up in the output list.

The last spec is:

```
@test "commands --no-sh" {
  run rbenv-commands --no-sh
  assert_success
  assert_line "init"
  refute_line "shell"
}
```
Pretty straightforward- we've previously tested `rbenv commands` *with* the `--sh` flag, and now we're testing that command *without* the `--sh` flag.  The syntax is largely the same, just with different inputs.

From now on, when I analyze a command, I'll first analyze the spec file so that we can see what's tested.  I'll then analyze the command itself, so we can recall the spec file and see whether any functionality is missing tests.  If so, that could be a good candidate for a PR to the RBENV repo.

That said, a quick glance at the `/test` folder shows that [not all commands have specs](https://github.com/rbenv/rbenv/tree/baf7656d2f1570a3b2d5a7e70d5bfcc52fe0428a/test).  For example, the next command that I'm due to examine (`rbenv-completions`) does not have a corresponding `completions.bats` file.  Nor do the `rbenv root` or `rbenv whence` commands, apparently.  Writing some could potentially be an interesting exercise.  We'll cross that bridge when we get to it.

(stopping here for the day; 32154 words)
