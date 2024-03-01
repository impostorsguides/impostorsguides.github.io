Once again, let's start with the command's test file.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/hooks.bats){:target="_blank" rel="noopener" }

### Sad path- running `hooks` without arguments

After the `bats` shebang and the loading of `test_helper`, the first spec is:

```
@test "prints usage help given no argument" {
  run rbenv-hooks
  assert_failure "Usage: rbenv hooks <command>"
}
```

We run the command without any args, and we assert that:

 - the command failed, and
 - we see a helpful error message describing how the command should be used.

### Happy path- running `hooks` for a specific command

Next spec:

```
@test "prints list of hooks" {
  path1="${RBENV_TEST_DIR}/rbenv.d"
  path2="${RBENV_TEST_DIR}/etc/rbenv_hooks"
  RBENV_HOOK_PATH="$path1"
  create_hook exec "hello.bash"
  create_hook exec "ahoy.bash"
  create_hook exec "invalid.sh"
  create_hook which "boom.bash"
  RBENV_HOOK_PATH="$path2"
  create_hook exec "bueno.bash"

  RBENV_HOOK_PATH="$path1:$path2" run rbenv-hooks exec
  assert_success
  assert_output <<OUT
${RBENV_TEST_DIR}/rbenv.d/exec/ahoy.bash
${RBENV_TEST_DIR}/rbenv.d/exec/hello.bash
${RBENV_TEST_DIR}/etc/rbenv_hooks/exec/bueno.bash
OUT
}
```

 - We start by creating a few variables, named `path1` and `path2`, which point to the `/rbenv.d` and `/etc/rbenv_hooks` subdirectories of the `RBENV_TEST_DIR` parent, respectively.
 - We then set the value of the `RBENV_HOOK_PATH` environment variable to `path1`'s value.
 - Lastly, we create 3 hooks for the `exec` command, using the `create_hook` helper method:
    - Two of the hooks have `.bash` extensions, and
    - One hook has a `.sh` extension.
    - Judging by the fact that the only apparently "invalid" hook is the one with the `.sh` extension, it appears that files with this extension are not allowed.
  - We also create a hook for a different command, `which`, containing a script with a `.bash` extension.
  - We then reset our `RBENV_HOOK_PATH` environment variable to `$path2` and create another `exec` hook with a `.bash` extension.

We then run `rbenv hooks exec`, being sure to include both `$path1` and `$path2` in our `RBENV_HOOK_PATH` env var so that the `hooks` command knows to look in both directories for possible hooks.

Lastly, we assert that:
 - the command executed successfully, and that:
 - the output contains only the valid hooks, from both directories `$path1` and `$path2`, for the `exec` command (*not* for `which`, since that's not the command we passed to `rbenv hooks`).

## The `create_hook()` helper function

This helper function comes from [the `test_helper` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash){:target="_blank" rel="noopener" } that we loaded at the start of this test file, and it looks like this:

```
create_hook() {
  mkdir -p "${RBENV_HOOK_PATH}/$1"
  touch "${RBENV_HOOK_PATH}/$1/$2"
  if [ ! -t 0 ]; then
    cat > "${RBENV_HOOK_PATH}/$1/$2"
  fi
}
```

We can see that the function has a dependency on the `RBENV_HOOK_PATH` env var.  Although the value of this env var is set [at the start of the `test_helper` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L20){:target="_blank" rel="noopener" }, we override it in our test.

The first two lines of this helper method do the following:

 - We create a directory by concating `RBENV_HOOK_PATH` plus the 1st argument to the function, and
 - We create an empty file within that new directory, with a name equal to the 2nd argument.

For example, back in our spec, we call `create_hook exec "hello.bash"`.  Therefore:


 - the directory that we create is `${RBENV_TEST_DIR}/rbenv.d/exec`, and
 - our new file would be `${RBENV_TEST_DIR}/rbenv.d/exec/hello.bash`

To test this, we can add `echo` statements, and write our output to a new file, from within the test (or in this case, within our helper method).  I modify `create_hook` to the following:

```
create_hook() {
  mkdir -p "${RBENV_HOOK_PATH}/$1"
  touch "${RBENV_HOOK_PATH}/$1/$2"
  touch testlog
  echo "new hook file: ${RBENV_HOOK_PATH}/$1/$2" > testlog
  if [ ! -t 0 ]; then
    cat > "${RBENV_HOOK_PATH}/$1/$2"
  fi
}
```

When I run this spec file with `bats test/hooks.bats`, I see `testlog` has been created and contains the following:

<center>
  <a target="_blank" rel="noopener" href="/assets/images/screenshot-14mar2023-845am.png">
    <img src="/assets/images/screenshot-14mar2023-845am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

There's a bunch of junk at the start of the filepath, but we see it ends with `/exec/hello.bash`.
So not only were we right about what the newly-created directory and file look like, but we now have a dependable way to log stuff from our BATS tests.  Cool!

Before moving on, I remove the tracer methods I just added.

### Populating the contents of the test hook file

One thing I was unsure about here was on the next line of `create_hook`:

```
if [ ! -t 0 ]; then
```

I don't recognize the test flag `-t`.  I run `man test`, and search for `-t`, and I see the following:

> -t file_descriptor
>
> True if the file whose file descriptor number is file_descriptor is open and is associated with a terminal.

So the `0` in `! -t 0` represents a file descriptor.  And this condition says "execute the code inside this conditional check, *if* file descriptor zero is *not* open or is *not* associated with a terminal".

I was still a bit confused by this, so I plugged this block of code into ChatGPT:

<center>
  <a target="_blank" rel="noopener" href="/assets/images/screenshot-23may2023-128pm.png">
    <img src="/assets/images/screenshot-23may2023-128pm.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

So `if [ ! -t 0 ]` checks whether the script's input is coming from the terminal or from another source (such as piping the input from the output of another command).  If the input from `STDIN` is "associated with a terminal" (i.e. if it is being entered by the user from a command prompt), this `if` check will return `false`.  If it is **not** being entered by a user at a command prompt, then the `if` check will return `true` and we will execute the logic that it wraps.

We can confirm this with an experiment. I re-write my `foo` file to contain the following code:

```
#!/usr/bin/env bash

if [ ! -t 0 ]; then
    echo "Standard input is not a terminal. Reading input from non-interactive source."
    cat > output.txt
else
    echo "Standard input is a terminal. Waiting for user input interactively."
    read -p "Enter your input: " user_input
    echo "You entered: $user_input"
fi
```

I then run it with no arguments, like so:

```
$ ./foo

Standard input is a terminal. Waiting for user input interactively.
Enter your input:
```

I type `Bar` where it says `Enter your input:`:

```
$ ./foo

Standard input is a terminal. Waiting for user input interactively.
Enter your input: Bar
You entered: Bar
```

Next, I re-run the command, this time with a heredoc:

```
$ ./foo <<BAR
heredoc> foo
heredoc> bar
heredoc> baz
heredoc> BAR

Standard input is not a terminal. Reading input from non-interactive source.
```

Lastly, I re-run the command, piping the output from an `echo` command as the input to the `foo` script:

```
$ echo "Foo Bar Baz" | ./foo

Standard input is not a terminal. Reading input from non-interactive source.
```

So we've verified the following:

 - When I run `foo` without any heredoc or pipes, the `if [ ! -t 0 ]` check returns `false`, we see the message `Standard input is a terminal. Waiting for user input interactively.`, and we are prompted to type text into the terminal.
 - When we **do** provide a heredoc or piped input, we see the message `Standard input is not a terminal. Reading input from non-interactive source.`.

As a final check, I look for how the `create_hook` function receives its input.  I search for other uses via the Github search field:

<center>
  <a target="_blank" rel="noopener" href="/assets/images/screenshot-14mar2023-904am.png">
    <img src="/assets/images/screenshot-14mar2023-904am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The 3rd result in the above screenshot is for the test file `test/version-name.bats`.  On [this line of code](https://github.com/rbenv/rbenv/blob/d604acb78aeba583be95f08d45eeae430372beb9/test/version-name.bats#L34){:target="_blank" rel="noopener" }, I see:

```
create_hook version-name hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
SH
```

We can see that there's some input coming from a heredoc.  So sometimes we pass a multi-line string to `create_hook`, and sometimes we don't.  Now it makes sense why we're ensuring that file descriptor 0 is not associated with a terminal before `cat`ing to the new file- if we don't pass that heredoc string, we just want an empty file and we don't care about what it does when it's executed.

### Supporting hook paths with spaces

Next test is:

```
@test "supports hook paths with spaces" {
  path1="${RBENV_TEST_DIR}/my hooks/rbenv.d"
  path2="${RBENV_TEST_DIR}/etc/rbenv hooks"
  RBENV_HOOK_PATH="$path1"
  create_hook exec "hello.bash"
  RBENV_HOOK_PATH="$path2"
  create_hook exec "ahoy.bash"

  RBENV_HOOK_PATH="$path1:$path2" run rbenv-hooks exec
  assert_success
  assert_output <<OUT
${RBENV_TEST_DIR}/my hooks/rbenv.d/exec/hello.bash
${RBENV_TEST_DIR}/etc/rbenv hooks/exec/ahoy.bash
OUT
}
```

Here we do the following:

 - We create two hook paths, one whose name contains spaces.
 - We then create a hook for the `exec` command in each path.
    - We set `RBENV_HOOK_PATH` before each call to `create_hook`, since (as we saw) the folder where that function creates a hook depends on the value of this env var.
 - Next we run the `rbenv hooks exec` command, ensuring that our hook path contains both paths we created.
 - Lastly, we assert that:
    - The command executed successfully, and
    - That the output contains both hooks we created, including the one whose directory includes a space.

### Resolving relative paths inside `RBENV_HOOK_PATH`

Next test:

```
@test "resolves relative paths" {
  RBENV_HOOK_PATH="${RBENV_TEST_DIR}/rbenv.d"
  create_hook exec "hello.bash"
  mkdir -p "$HOME"

  RBENV_HOOK_PATH="${HOME}/../rbenv.d" run rbenv-hooks exec
  assert_success "${RBENV_TEST_DIR}/rbenv.d/exec/hello.bash"
}
```

Here we do the following:

- We create a hook for `rbenv exec` in the `rbenv.d` subdirectory of `RBENV_TEST_DIR`.
- We also create a directory whose name is the value of the `$HOME` environment variable.
- That value is set [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L19){:target="_blank" rel="noopener" }:

```
export HOME="${RBENV_TEST_DIR}/home"
```

 - We then run our `rbenv hooks exec` command, setting the `RBENV_HOOK_PATH` env var equal to `"${HOME}/../rbenv.d"`.
  - Since `${HOME}` resolves to "${RBENV_TEST_DIR}/home", the `..` should cause us to navigate up to `${RBENV_TEST_DIR}`, and the `/rbenv.d` *after* `..` should resolve the final value of `RBENV_HOOK_PATH` to`${RBENV_TEST_DIR}/rbenv.d/`.
 - Lastly, we assert that the output of the command is "${RBENV_TEST_DIR}/rbenv.d/exec/hello.bash".  This is the expected output if the command resolved the relative path as it should.

### Resolving symlinks

Last spec is:

```
@test "resolves symlinks" {
  path="${RBENV_TEST_DIR}/rbenv.d"
  mkdir -p "${path}/exec"
  mkdir -p "$HOME"
  touch "${HOME}/hola.bash"
  ln -s "../../home/hola.bash" "${path}/exec/hello.bash"
  touch "${path}/exec/bright.sh"
  ln -s "bright.sh" "${path}/exec/world.bash"

  RBENV_HOOK_PATH="$path" run rbenv-hooks exec
  assert_success
  assert_output <<OUT
${HOME}/hola.bash
${RBENV_TEST_DIR}/rbenv.d/exec/bright.sh
OUT
}
```

Here we do the following:

 - We create a variable named `path`, resembling a path to a subdirectory named `rbenv.d/` inside our `RBENV_TEST_DIR` directory.
 - We make that subdirectory, as well as a subdirectory inside it named `/exec`.
 - We also create the `$HOME` directory, as we did in the last spec.
 - We create a valid hook file inside `$HOME` named `hola.bash`.
 - We also create a symlink named `hello.bash` which points to that hook file, and place the symlink inside our `${path}/exec` directory.
 - We then create another hook file named `bright.sh`, this time inside `${path}/exec/`, and create a symlink called `world.bash` in the same directory, which points to that 2nd hook file.
 - We then run `rbenv hooks exec` with `$path` as the hook path, and assert that:
    - the command exited successfully, and
    - the paths to the original files (NOT the symlinks) are displayed in the results.

One thing to note- in an earlier test we created a hook named `invalid.sh`.  Without any apparent modifications to make it "invalid", the file extension was the only thing which made it different from the other, valid, hook files.  Therefore, we could be forgiven for assuming that it was the `.sh` extension which made it invalid.

But in our test above, we not only created a hook called `bright.sh`, but we saw `"bright.sh"` included in the expected output.  So why was `bright.sh` valid and included in the output, but `invalid.sh` was not?

The answer is that `bright.sh` had a symlink pointing to it called `world.bash`.  It was *this* file which is identified by the `rbenv hooks` command.  However, `rbenv hooks` doesn't print out the *symlink* filename.  Instead, it resolve the symlink to its canonical filename, which in this case is a `.sh` file.

With that question answered, let's move on to the command file itself, `libexec/rbenv-hooks`.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-hooks){:target="_blank" rel="noopener" }

By now, this first block of code is standard boilerplate for us:

```
#!/usr/bin/env bash
# Summary: List hook scripts for a given rbenv command
# Usage: rbenv hooks <command>

set -e
[ -n "$RBENV_DEBUG" ] && set -x

# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo exec
  echo rehash
  echo version-name
  echo version-origin
  echo which
  exit
fi
```

We have:

- the Bash shebang
- Summary and usage comments (to be read by the previous command we analyzed, `rbenv help`)
- Setting the shell option to exit immediately once it encounters an error.
- Setting the shell option to output verbose logs if the `RBENV_DEBUG` env var was set
- Providing completion instructions for the `rbenv hooks` command, to be output if the users types `rbenv completions hooks`.

### Printing help instructions

Next block of code:

```
RBENV_COMMAND="$1"
if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage hooks >&2
  exit 1
fi
```

Here we set `RBENV_COMMAND` equal to the first arg passed to `rbenv hooks`.  After setting it, we check to see if it has a value.  If nothing was stored, we run `rbenv help --usage hooks` and direct the output to STDERR, then exit with a non-zero return code.

Let's run this command in our terminal and see what is printed:

```
$ rbenv help --usage hooks

Usage: rbenv hooks <command>
```

Note that the output exactly matches the `Usage:` comments we saw at the top of the file.  We'll look more closely at how `rbenv help` works, its `--usage` flag, etc. in a future section.

### Overriding the `realpath` command

Next block of code:

```
if ! enable -f "${BASH_SOURCE%/*}"/rbenv-realpath.dylib realpath 2>/dev/null; then
...
fi
```

This code says that if the `enable -f <filepath> realpath` command fails, we execute the code inside the `if` block.  We've seen this before, back when we were analyzing the `rbenv` file.  In that file, the goal was to override the builtin `realpath` command with a more performant version.  That's the goal here too.

### Checking for the presence of RBENV_NATIVE_EXT

Next block of code:

```
  if [ -n "$RBENV_NATIVE_EXT" ]; then
    echo "rbenv: failed to load \`realpath' builtin" >&2
    exit 1
  fi
```

This block of code `echo`s an error message to `STDERR` and returns a non-zero result if the `RBENV_NATIVE_EXT` contains a value.  We did a similar thing in [this line of the `rbenv` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L30){:target="_blank" rel="noopener" }.  For a refresher on why this was added, we can check out [the PR which introduced the change](https://web.archive.org/web/20220722202956/https://github.com/rbenv/rbenv/pull/528){:target="_blank" rel="noopener" }:

<center>
  <a target="_blank" rel="noopener" href="/assets/images/screenshot-14mar2023-919am.png">
    <img src="/assets/images/screenshot-14mar2023-919am.png" width="90%" style="border: 1px solid black; padding: 0.5em">
  </a>
</center>

The core team added this code to make testing (either manual or automated) more performant.

### Checking for the `readlink` command

The next block of code is:

```
READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
if [ -z "$READLINK" ]; then
  echo "rbenv: cannot find readlink - are you missing GNU coreutils?" >&2
  exit 1
fi
```

This is another pattern we've seen before, again [in the `rbenv` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L32){:target="_blank" rel="noopener" }:

 - We check for a path to a command named `greadlink`, and also for a path to a command named `readlink`.
 - We take the first result we find (`| head -n1`), and we set the `READLINK` variable equal to that result.
 - If that assignment did not result in a value for the `READLINK` variable (i.e. if there were no results in our listing of paths to the two commands), then we echo an error message to STDERR and we exit with a non-zero return status.

### Creating the `resolve_link` function

Next block of code:

```
resolve_link() {
  $READLINK "$1"
}
```

If we've reached this code, it means the assignment to the `READLINK` variable was successful, so now we create a function called `resolve_link`, which executes either `greadlink` or `readlink` (depending on which command our shell found first via the `type -p` check).  We then pass the first of `resolve_link`'s arguments to that command.

### Creating the `realpath` function

The `resolve_link` function that we just defined is then called in the next block of code:

```
realpath() {
  local cwd="$PWD"
  local path="$1"
  local name

  while [ -n "$path" ]; do
    name="${path##*/}"
    [ "$name" = "$path" ] || cd "${path%/*}"
    path="$(resolve_link "$name" || true)"
  done

  echo "${PWD}/$name"
  cd "$cwd"
}
```

Here we declare a function named `realpath`.  Inside the function body, we declare 3 local variables:


 - `cwd` (which probably stands for "current working directory" since its value is the result of `$PWD`, or "print working directory")
 - `path`, which is the first argument passed to `realpath`, and
 - `name` (not-yet-assigned)

We then execute a `while` loop, where we:

 - initialize `name` equal to `path`,
 - `cd` into the new `path` *unless* `name` and `path` have the same value,
 - reset `path` to *either* the resolved value of `name` *or* the boolean `true`, and then
 - repeat the loop until `path` is set to the boolean (due to `name` no longer being a symlink).

The overall goal of this `while` loop is to get the canonical, non-symlink path for the argument passed to `realpath`.

Lastly, as a cleanup step, we `cd` back into our original working directory.

### Storing the paths to our hooks

Next line of code:

```
IFS=: hook_paths=($RBENV_HOOK_PATH)
```

We've seen something similar before, [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-commands#L23){:target="_blank" rel="noopener" } inside the `rbenv-commands` file:

We set a new variable called `hook_paths` equal to an array created from splitting the string stored in `$RBENV_HOOK_PATH`, using `:` as the delimiter.  This is called "word splitting" in bash; more info [here](https://web.archive.org/web/20220713204204/https://www.gnu.org/software/bash/manual/html_node/Word-Splitting.html){:target="_blank" rel="noopener" }.  We'll end up with an array of individual directories, which we'll iterate over in the next block.

### Iterating over the hook paths

That next block is:

```
shopt -s nullglob
for path in "${hook_paths[@]}"; do
  for script in "$path/$RBENV_COMMAND"/*.bash; do
    realpath "$script"
  done
done
shopt -u nullglob
```

We've seen `shopt -s nullglob` before, but as a reminder, [this StackExchange link](https://archive.ph/pAHiZ){:target="_blank" rel="noopener" } says this command sets a shell option so that "...filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded."

So if `${hook_paths[@]}` doesn't match any actual directories, or `$path/$RBENV_COMMAND"/*.bash` doesn't match any filenames, we don't perform the code inside the `for` block.

What are the two blocks doing?  For each path in our `hook_paths` variable, and for each Bash script in that path, we call our `realpath` function.  As an argument to `realpath`, we pass the name of that Bash script.  This has the effect of resolving any symlinks and deriving the canonical filepath for that hook script.

Note that we're iterating over each *bash* script.  We don't include any `.sh` script (or any other file extension, for that matter).  This is why the `invalid.sh` script in the earlier test really was invalid, and was therefore not included in the output of the BATS test we examined earlier.  It's also why `bright.sh` was included in a different test- it was being pointed to by a symlink file which *did* contain a `.bash` file extension.

And that's it for the `rbenv hooks` command!

## What are hooks, anyway?

Hooks are 3rd-party libraries that you can install within RBENV, to add functionality to its existing commands.

If we look back to our read-through of the `rbenv` file, we saw that part of that file's job was to [populate the `RBENV_HOOK_PATH` environment variable](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv#L81-L91){:target="_blank" rel="noopener" } with various directories.  One of those directories is `~/.rbenv/rbenv.d/`.  This directory contains zero or more subdirectories whose names correspond to RBENV's commands (for example, `exec/`).  If we create a `.bash` script inside one of these directories, RBENV will treat it as a hook, and will execute that Bash script when running the command corresponding to that directory.

To learn more, let's make our own as an experiment.

### Experiment- making our own hook

Let's add some behavior to the `rbenv exec` command.  To get a baseline for how this command works, I run `ruby --version`, prefacing it with `rbenv exec` so that the command will execute within the context of RBENV:

```
$ rbenv exec ruby --version
ruby 2.7.5p203 (2021-11-24 revision f69aeb8314) [x86_64-darwin22]
```

I then switch the local Ruby version using `rbenv local`, and re-run the command:

```
$ rbenv local 3.0.0
$ rbenv exec ruby --version

ruby 3.0.0p0 (2020-12-25 revision 95aff21468) [x86_64-darwin22]
```

We can see that `ruby --version` has a new value as its output.

Next, inside `~/.rbenv/rbenv.d/exec/`, I create a script called `foo.bash`.  Inside that script, I simply do the following:

```
#!/usr/bin/env bash

echo "Hello world"
```

I `chmod +x` the Bash script so that it's executable.  I then use `rbenv exec` to re-run the `--version` commands I previously ran:

```
$ rbenv exec ruby --version

Hello world
ruby 3.0.0p0 (2020-12-25 revision 95aff21468) [x86_64-darwin22]
```

We can see that our hook has modified the output of the `rbenv exec` command.  Now, in addition to executing the command we give it (in this case, `ruby --version`), it now prints `"Hello world"` to the screen.

Let's change our Ruby version back to its original value and confirm that the change was successful:

```
$ rbenv local 2.7.5
$ rbenv exec ruby --version

Hello world
ruby 2.7.5p203 (2021-11-24 revision f69aeb8314) [x86_64-darwin22]
```

Once again, we see our newly-created hook in action.

Let's delete our hook as a final clean-up step:

```
$ rm ~/.rbenv/rbenv.d/exec/foo.bash
$ rbenv exec ruby --version

ruby 2.7.5p203 (2021-11-24 revision f69aeb8314) [x86_64-darwin22]
```

We no longer see `Hello world` when `rbenv exec` is run.

Let's move on to the next command.
