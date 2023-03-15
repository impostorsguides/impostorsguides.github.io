Once again, let's start with the command's test file.  It's a good habit to get into.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/hooks.bats)

After the `bats` shebang and the `test_helper` load, the first spec is:

```
@test "prints usage help given no argument" {
  run rbenv-hooks
  assert_failure "Usage: rbenv hooks <command>"
}
```

Pretty straight-forward.  We run the command without any args, and we assert that a) the command failed, and b) that we see a helpful error message describing how the command should be used.

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

We start by creating a few variables, named `path1` and `path2`, which point to the `/rbenv.d` and `/etc/rbenv_hooks` subdirectories of the `RBENV_TEST_DIR` parent, respectively.  We then ensure that `RBENV_HOOK_PATH` is set to `path1`'s value, before running the `create_hook` helper method a few times.  We create 3 hooks for the `exec` command, two of which have `.bash` extensions and one of which has a `.sh` extension.  Judging by the fact that the only apparently "invalid" hook is the one with the `.sh` extension, it appears that files with this extension are not allowed.

We also create a hook for a different command, `which`, containing a script with a `.bash` extension.  We then reset our `RBENV_HOOK_PATH` environment variable to `$path2` and create another `exec` hook with a `.bash` extension.

We then run `rbenv hooks exec`, being sure to include both `$path1` and `$path2` in our `RBENV_HOOK_PATH` env var so that the `hooks` command knows to look in both directories for possible hooks.

Lastly, we assert that the command executed successfully, and that the output contains only the valid hooks, from both directories `$path1` and `$path2`, for the `exec` command (*not* for `which`, since that's not the command we passed to `rbenv hooks).

#### Sidebar: `create_hook()`

That `create_hook` helper method comes from [the `test_helper` file](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash) that we loaded at the start of this test file, and it looks like this:

```
create_hook() {
  mkdir -p "${RBENV_HOOK_PATH}/$1"
  touch "${RBENV_HOOK_PATH}/$1/$2"
  if [ ! -t 0 ]; then
    cat > "${RBENV_HOOK_PATH}/$1/$2"
  fi
}
```

We can see that the function has a dependency on the `RBENV_HOOK_PATH` env var, and although its value is set at the start of the `test_helper` file, we override it for the purposes of this test we're running.

The first two lines of this helper method seem straight-forward:


we create a directory by concating `RBENV_HOOK_PATH` plus the first argument to the function, and
We create an empty file within that new directory.

For example, back in our spec, we call `create_hook exec "hello.bash"`.  Therefore:


`exec` is the value that `$1` resolves to, and the directory that we create should be `${RBENV_TEST_DIR}/rbenv.d/exec`, and
our new file would be `${RBENV_TEST_DIR}/rbenv.d/exec/hello.bash`

I want to test this to make sure I'm right, but at first I thought there would be no way to test this, because I remember from previous attempts that trying to run `echo` (even to STDERR) had no effect.  Then I had the thought that maybe we could write our output to a new file, from within the test (or in this case, within our helper method).  I modify `create_hook` to the following:

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

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-845am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
</p>

So not only were we right about what the newly-created directory and file look like, but we now have a dependable way to log stuff from our BATS tests.  Cool!

Before moving on, I remove the tracer methods I just added.

One thing I was unsure about here was on the next line of `create_hook`:

```
if [ ! -t 0 ]; then
```

I don't recognize the test flag `-t`.  I run `man test`, and search for `-t`, and I see the following:

> -t file_descriptor
>
> True if the file whose file descriptor number is file_descriptor is open and is associated with a terminal.

And as I suspected, the `!` means we negate the result of the `[ -t 0]` test:

> ! expression  True if expression is false.

So the `0` in `! -t 0` represents a file descriptor.  And this condition says "execute the code inside this conditional check, *if* file descriptor # 0 is *not* open or is *not* associated with a terminal".

That… sounds strange to me.  What kind of logic would we want to execute only if file descriptor 0 is *not* open?  And what are file descriptors again?  I've heard the term before, but I forget what they are.

According to [RedHat](https://web.archive.org/web/20220405071108/https://www.redhat.com/sysadmin/more-stupid-bash-tricks):

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-857am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So file descriptor 0 refers to STDIN.  So if standard input is NOT open, then we execute the logic inside the code block.  What is that logic, exactly?

```
cat > "${RBENV_HOOK_PATH}/$1/$2"
```

I've seen `cat` before, but never without some text after it.  I know the `>` symbol means we direct text to the file whose path comes after the `>` symbol, as we see from the `man cat` command:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-858am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So we're sending *some* sort of input to the file we just created in the `create_hook` function, but only if standard input is NOT open.  If the input isn't coming from STDIN, where is it coming from?

I try to mimic what's going on here, by running `cat > foo` in my terminal, expecting this to create a file in my current directory named `foo`:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-859am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

I see a blinking red (in my case) cursor, which looks like it's waiting for me to type stuff.  So I do:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-900am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Unsure of how to get back to my terminal prompt, I hit "Ctrl-C":

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-901am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

This is the standard way to kill a process in a Unix terminal according to [this StackExchange post](https://web.archive.org/web/20220606161921/https://superuser.com/questions/103909/how-to-stop-a-process-in-terminal).

I'm unsure if the `foo` file was created successfully, since I would think there's a chance that hitting "Ctrl-C" would cause the process to be terminated before it reached the file creation step.  I run an `ls`, and in fact I do see the file was created:

```
$ ls foo

foo
```

I `cat` the contents of this file, and I see that the text I typed is indeed present in the file:

```
$ cat foo

bar
baz
buzz
```

Cool, so far so good.  I'm still a tad confused on why Ctrl-C didn't cause my experiment to go awry, so I Google "how to terminate cat command" and get [this link](https://web.archive.org/web/20220712202816/https://www.baeldung.com/linux/cat-writing-file) as the first result:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-902am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Ah OK, so technically we should have run "Ctrl-D" to terminate our terminal input, not Ctrl-C.  I Google "difference between ctrl-c and ctrl-d" and get [this link](https://web.archive.org/web/20220902171324/https://superuser.com/questions/169051/whats-the-difference-between-c-and-d-for-unix-mac-os-x-terminal) as the first result:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-903am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

So "Ctrl-C" sends a SIGINT to the process (in our case, the `cat` process), while "Ctrl-D" tells `cat` that we've reached the end of the input.  I test "Ctrl-D" in the same manner as the original experiment, and I continue to see the same results- a `foo` file with the text I type.  So both keyboard commands get the job done when used with `cat`, but "Ctrl-D" appears to be a bit more semantically correct.

Now that we know how `cat` works in general with respect to STDIN, I'm curious how the input is being sent to `cat` in the case of *these tests*.  I know the `create_hook` function is a helper function, and it could be used in lots of different places in the RBENV codebase.  Let's search for other uses, maybe that will tell us:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-904am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The 3rd result in the above screenshot is for the test file `test/version-name.bats`.  On [this line of code](https://github.com/rbenv/rbenv/blob/d604acb78aeba583be95f08d45eeae430372beb9/test/version-name.bats#L34), I see:

```
create_hook version-name hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
SH
```

OK, so it *looks like* there's some input coming from a heredoc.  So sometimes we pass a multi-line string to `create_hook`, and sometimes we don't.  So now it makes sense why we're ensuring that file descriptor 0 is not associated with a terminal before `cat`ing to the new file- if we don't pass that heredoc string, we just want an empty file and we don't care about what it does when it's executed.

But I'm still confused.  I could understand if we were piping in some text to `create_hook`- that would mean that STDIN is *open* but is not *associated with a terminal*.  But this doesn't look like we're *piping in* the input.  It just looks like the input is argument #3, in which case I would expect to see:

```
cat $3 > "${RBENV_HOOK_PATH}/$1/$2"
```

Instead of:

```
cat > "${RBENV_HOOK_PATH}/$1/$2"
```

I decide to extend my `cat > foo` experiment by adding a heredoc to it, just like we see in the `version-name.bats` test file:

```
$ cat > foo <<FOO
heredoc> 1
heredoc> 2
heredoc> 3
heredoc> FOO
```

When I `cat foo` again, I see:

```
$ cat foo
1
2
3
```

So there's something about a heredoc that makes it work similarly to a pipe?

(stopping here for the day; 45692 words)

[According to the Linux Documentation Project](https://web.archive.org/web/20220824230428/https://tldp.org/LDP/abs/html/here-docs.html), a heredoc's job is to redirect its text to an interactive program (such as `cat`).  The link contains multiple examples of how this is done, such as:

```
COMMAND <<InputComesFromHERE
...
...
...
InputComesFromHERE
```

In the above example, `COMMAND` would be something like the `cat` command.

We can test this in our `bash` shell:

```
bash-3.2$ cat <<END
> foo
> bar
> baz
END

foo
bar
baz

bash-3.2$
```

We can emulate our situation even more closely by wrapping the above `cat` command inside a function, and passing the heredoc to that function:

```
bash-3.2$ make_file() {
  cat > "$1"
}

bash-3.2$ make_file <<END new_file.txt
foo
bar
baz
END
```

Here we create a function called `make_file`, which calls the `cat` command and sends its output to a new file, whose name is specified as the first argument.  We then call our new function, passing it a heredoc and the name of the new file.  I know, the syntax is weird and makes it look like the name of the new file is part of the heredoc text.  That's just the way the syntax is.  More info and examples [here](https://web.archive.org/web/20220926191746/https://linuxize.com/post/bash-heredoc/).

```
$ cat new_file.txt

foo
bar
baz
```

Now that we've called our function, we can see if it actually created a new file with the name we specified.  It did!  Lastly, we `cat` the file itself to see if its content matches our heredoc.  It does!

If we tried to call our function with a filename specified but *without* a heredoc, we'd get this:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-909am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

The call to `cat` inside our function would cause the terminal to hang while waiting for our input, or for us to hit "Ctrl-D" and terminate the input.  The heredoc intercepts this process and provides `cat` with the input it's looking for.

So to summarize what we learned while examining `create_hook()`:

```
create_hook() {
  mkdir -p "${RBENV_HOOK_PATH}/$1"
  touch "${RBENV_HOOK_PATH}/$1/$2"
  if [ ! -t 0 ]; then
    cat > "${RBENV_HOOK_PATH}/$1/$2"
  fi
}
```

We create a directory using the first arg to the function.
We create a file within that directory using the 2nd arg to the function.
If STDIN is not part of a terminal (i.e. if we're using a heredoc), we set the contents of the new file equal to the text from the heredoc.

As a wrap-up, I take a look at [the PR](https://web.archive.org/web/20201029234547/https://github.com/rbenv/rbenv/pull/852) which introduced the `[ ! -t 0]` conditional check, and I see a conversation between Mislav and Jason which largely confirms our conclusions about why the code is structured the way that it is:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-910am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

NB: when Mislav says "Could we not support a string argument?", I initially interpreted this as "Can't we support a string argument?", as in "Isn't it possible to support a string argument?".  After subsequent readings, I realize that his meaning is probably "Could we change this so that the code *does not* support a string argument?".  This 2nd reading makes more sense, b/c the code as it stood at the time included `hook_body="$3"`, which would be that 3rd argument I mentioned earlier.  Mislav is saying he prefers the heredoc method that we see in the final code result.

<div style="border-bottom: 1px solid black; margin-bottom: 1em"></div>

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

Here we create two hook paths, one whose name contains spaces.  We then create a hook for the `exec` command in each path.  Next we run the `rbenv hooks exec` command, ensuring that our hook path contains both paths we created.  Lastly, we assert that the command executed successfully and that the output contains both hooks we created, including the one whose directory contains a space.

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

Here we create a hook for `rbenv exec` in the `rbenv.d` subdirectory of `RBENV_TEST_DIR`.  We also create a directory whose name is the value of the `$HOME` environment variable.  That value is set [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/test_helper.bash#L19):

```
export HOME="${RBENV_TEST_DIR}/home"
```

We then run our `rbenv hooks exec` command, setting the `RBENV_HOOK_PATH` env var equal to `"${HOME}/../rbenv.d"`.  Since `${HOME}` resolves to "${RBENV_TEST_DIR}/home", the `..` should cause us to navigate up to `${RBENV_TEST_DIR}`, and the `/rbenv.d` *after* `..` should resolve the final value of `RBENV_HOOK_PATH` to`${RBENV_TEST_DIR}/rbenv.d/`.  And that's why we assert that the output of the command is "${RBENV_TEST_DIR}/rbenv.d/exec/hello.bash"- this is the expected output if the command resolved the relative path as it should.

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

Here we create a variable named `path`, and make a directory with that path and a subdirectory inside it named `/exec`.  We also create the `$HOME` directory, as we did in the last spec.  We create a valid hook file inside `$HOME` named `hola.bash` and create a symlink inside our `${path}/exec` directory named `hello.bash` which points to that hook file.  We then create another hook file, this time inside `${path}/exec`, named `bright.sh`, and create a symlink called `world.bash` in the same directory.

We then run `rbenv hooks exec` with `$path` as the hook path, and assert that command exited successfully and that the paths to the original files (NOT the symlinks) are displayed in the results.

QUESTION- I see here that we created `bright.sh`, and it appears to be a valid hook since it's included in the output of the successful test.  But in an earlier test we created `invalid.sh` without any apparent modifications to make it invalid.  Therefore I assumed it was the `.sh` extension which made it invalid, since that's the only thing which made it different from the other, valid, hook files.  Why was `invalid.sh` invalid, if it wasn't due to the `.sh` extension?

(stopping here for the day; 46744 words)

Moving on to the command file itself, `libexec/rbenv-hooks`.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-hooks)

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

`bash` shebang
Summary and usage comments (to be read by the previous command we analyzed, `rbenv help`)
Setting the shell option to exit immediately once it encounters an error.
Setting the shell option to output verbose logs if the `RBENV_DEBUG` env var was set
Providing completion instructions for the `rbenv hooks` command, to be output if the users types `rbenv completions hooks`.

(stopping here for the day; 44239 words)

Next block of code:

```
RBENV_COMMAND="$1"
if [ -z "$RBENV_COMMAND" ]; then
  rbenv-help --usage hooks >&2
  exit 1
fi
```

Here we set `RBENV_COMMAND` equal to the first arg passed to `rbenv hooks`.  After setting it, we check to see if it has a value.  If nothing was stored, we run `rbenv help --usage hooks` and direct the output to STDERR, then exit with a non-zero return code.

Next block of code:

```
if ! enable -f "${BASH_SOURCE%/*}"/rbenv-realpath.dylib realpath 2>/dev/null; then
…
fi
```

This code says that if the `enable -f <filepath> realpath` command fails, we execute the code inside the `if` block.  We've seen this before, back when we were analyzing the `rbenv` file.  In that file, the goal was to override the builtin `realpath` command with a more performant version.  So I'm guessing that's the goal here too.  The following code, which is executed inside this `if` block, is likely included here for that purpose:
Checking for the presence of RBENV_NATIVE_EXT

```
  if [ -n "$RBENV_NATIVE_EXT" ]; then
    echo "rbenv: failed to load \`realpath' builtin" >&2
    exit 1
  fi
```

This block of code `echo`s an error message to STDERR and returns a non-zero result if the `RBENV_NATIVE_EXT` contains a value.  I wondered why this was needed, so I searched the Github repo for this variable name.  I found [the following PR](https://web.archive.org/web/20220722202956/https://github.com/rbenv/rbenv/pull/528):

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-919am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Based on the highlighted description above, this seems like something we don't need to spend much time on now.  We can always come back later if we're curious about why this is specifically useful for testing purposes.

### Checking for the `readlink` command

This block of code is:

```
READLINK=$(type -p greadlink readlink 2>/dev/null | head -n1)
if [ -z "$READLINK" ]; then
  echo "rbenv: cannot find readlink - are you missing GNU coreutils?" >&2
  exit 1
fi
```

This is another pattern we've seen before, also in the `rbenv` file.  We check for a path to a command named `greadlink`, and also for a path to a command named `readlink`.  We take the first result we find (`| head -n1`), and we set the `READLINK` variable equal to that result.  If that assignment did not result in a value for the `READLINK` variable (i.e. if there were no results in our listing of paths to the two commands), then we echo an error message to STDERR and we exit with a non-zero return status.

Creating the `resolve_link` function
Next block of code:

```
resolve_link() {
  $READLINK "$1"
}
```

If we've reached this code, it means the assignment to the `READLINK` variable was successful, so now we create a function called `resolve_link`, which executes either `greadlink` or `readlink` (whichever one our shell found first during the `type -p` check above), and we pass the first of `resolve_link`'s arguments to that command.  This function is used in the next block of code:

Creating the `realpath` function:

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


`cwd` (which probably stands for "current working directory" since its value is the result of `$PWD`, or "print working directory")
`path`, which is the first argument passed to `realpath`, and
`name` (not-yet-assigned)

We then execute a `while` loop where we initialize `name` equal to `path`, `cd` into the new `path` *unless* `name` and `path` have the same value, reset `path` to *either* the resolved value of `name` *or* the boolean `true`, and then repeat the loop until `path` is set to the boolean (due to `name` no longer being a symlink).  The overall goal of this `while` loop is to get the canonical, non-symlink path for the argument passed to `realpath`.  Lastly, as a cleanup step, we `cd` back into our original working directory.

Next line of code:

```
IFS=: hook_paths=($RBENV_HOOK_PATH)
```

We've seen something similar before, when examining the `rbenv-commands` file.  Here we're setting a new variable called `hook_paths` equal to an array created from splitting the string stored in `$RBENV_HOOK_PATH`, using `:` as the delimiter.  This is called "word splitting" in bash; more info [here](https://web.archive.org/web/20220713204204/https://www.gnu.org/software/bash/manual/html_node/Word-Splitting.html).  We'll end up with an array of individual directories, which we'll iterate over in the next block.  That next block is:

```
shopt -s nullglob
for path in "${hook_paths[@]}"; do
  for script in "$path/$RBENV_COMMAND"/*.bash; do
    realpath "$script"
  done
done
shopt -u nullglob
```

We've seen `shopt -s nullglob` before, but as a reminder, [this StackExchange link](https://archive.ph/pAHiZ) says this command sets a shell option so that:

Filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.

So if `${hook_paths[@]}` or `$path/$RBENV_COMMAND"/*.bash` don't match any filenames, we don't perform the code inside that `for` block.

What are the two blocks doing?  Well we take each path in our `hook_paths` variable, and for each `bash` script in that path, we call our `realpath` function, passing the name of that `bash` script.  This has the effect of resolving any symlinks and deriving the canonical filepath for that hook script.

Note that we're iterating over each *bash* script.  We don't include any `.sh` script (or any other file extension, for that matter).  This is why the `invalid.sh` script really was invalid, and was therefore not included in the output of the BATS test we examined earlier.

But then what about the last test in the `hooks.bats` file?  If you recall, that spec looked like this:

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

It looks like the answer is that, while we're *iterating* over `.bash` files, we're *resolving* those files to their canonical version.  So we *iterate* over the "${path}/exec/world.bash" symlink file, but when we call `realpath` on that path file, it resolves to "${path}/exec/bright.sh".  Therefore, *that* is the path that we send to STDOUT, and *that* is why a `.sh` file shows up in the test assertion.

And that's it for the `rbenv hooks` command!

But I still don't understand what hooks *are*, or what they *do*.  I need an example to solidify my understanding.

(stopping here for the day; 47818 words)


The trouble is, there's no documentation on how hooks are used, and (so far, at least), the only command we've seen which takes advantage of hooks [simply `source`s the hook files related to that command](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-exec#L36):

```
IFS=$'\n' scripts=(`rbenv-hooks exec`)
for script in "${scripts[@]}"; do
  source "$script"
done
```

I guess I don't know enough about `bash` scripting to know what the possibilities are, given we've `source`d a 3rd-party file.  For example, can that other file intercept calls to `rbenv exec` and layer additional functionality on top?  I assume the answer is yes, and that this is in fact the primary value that hooks provide.  But as far as what that additional functionality could be, I don't know.  Nor do I know *how* those other files would intercept calls to `rbenv`'s commands, i.e. what that interception looks like in code form.

I think it makes sense to drill into hooks a bit more, rather than moving on.  If I were to kick the can down the road at this point, I'd be moving on before I fully understand the functionality of the `rbenv hooks` command.  That level of understanding seems like a necessary thing for me to achieve before moving on from a given command file, whether it's `hooks` or any other `rbenv` command.

I start by searching Github's "Issues" section for the phrase "hooks".  I check both the "Open" and "Closed" issues.  To start, I'm looking in particular for any issue which requests documentation on the hooks feature, since I'm curious to hear whether the core team has specifically addressed the issue of whether such documentation would be useful.  Who knows, they may take the position that hooks are an implementation detail, and are undocumented for a reason.

However, my gut instinct tells me it's unlikely that someone else has requested such documentation in the past.  After all, given the fact that hooks are undocumented, it's unlikely that someone even knows about hooks unless they've combed through the code in the way that I'm doing.  Furthermore, the number of people who would do / have done something like that can probably be counted on one hand, and I'd bet money that most of the people in that group are familiar enough with bash scripting to not need such documentation on hooks.  The Venn diagram of people who, like me, are both a) bash noobs, and b) curious enough to comb through the entire codebase is, let's say, not large.

All of this is just to say, I will try not to get my hopes up.  If I fail to find the exact issue that I'm hoping for, hopefully I can at least find a few issues that tangentially touch on the concept of hooks, such that I can infer what they are or how they're used.  This is going to be a bit of a slog, since there are 50 issues that mention "hooks" in them (2 open and 48 closed):

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-921am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

But no one said this would be easy.  The key will be doing this in a methodical, systematic way.  The goal is to prevent myself from either a) missing some issues because I accidentally skipped over them, or b) re-reading issues that I've already eliminated.

Reading through past Github issues is a difficult process to derive learnings and new knowledge from.  When reading code, if you don't understand a certain piece of syntax, you can always post a question on StackOverflow.  But there's no StackOverflow, Q&A site for questions like "Hey, what did you mean in your Github issue when [you said](https://github.com/rbenv/rbenv/issues/38) `...we will be supporting system wide installs via homebrew…`?"

I mean, to a certain extent, that Q&A site *is* Github itself, but that's not Github's primary intent.  I get the sense that the questions and answers posted on StackOverflow are meant to be just as relevant 10 years from now as they are today.  Also, SO is meant more for discrete questions with discrete answers.  In contrast, the discussions on Github are just that- discussions.  There's much more back-and-forth between contributors… (NOTE- how to finish this train of thought?)

At any rate, it's highly unlikely that anyone would reply to a question I posted on a 10-year-old Github issue, much less the original author.

Let's start with the 2 open issues.

[The very first issue](https://github.com/rbenv/rbenv/issues/865), in fact, tangentially mentions the `rbenv-env` plugin.  Googling for "rbenv-env", I find [this Github repo](https://github.com/ianheggie/rbenv-env).  Does this codebase contain logic which could illuminate how hooks are used?

The README on the repo's homepage shows a pretty straightforward installation process: just run this one line of code:

```
$ git clone https://github.com/ianheggie/rbenv-env.git "$(rbenv root)/plugins/rbenv-env"
```

This pulls down the repo's code and installs it inside a new subdirectory of `$RBENV_ROOT/plugins`, giving the new dir a name of `rbenv-env`.  I run this command, to test out the install process, and get the following when I type `rbenv env`:

```
$ rbenv env
RBENV_VERSION=2.7.5
RBENV_ROOT=/Users/richiethomas/.rbenv
RBENV_HOOK_PATH=/Users/richiethomas/.rbenv/rbenv.d:/usr/local/etc/rbenv.d:/etc/rbenv.d:/usr/lib/rbenv/hooks
PATH=/Users/richiethomas/.rbenv/versions/2.7.5/bin:/Users/richiethomas/.rbenv/libexec:/Users/richiethomas/.rbenv/plugins/rbenv-env/bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Applications/Postgres.app/Contents/Versions/latest/bin:/Users/richiethomas/.nvm/versions/node/v18.12.1/bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/Users/richiethomas/.cargo/bin:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Users/richiethomas/.asdf/shims:/Users/richiethomas/.asdf/bin:/Users/richiethomas/.rbenv/shims:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Applications/Postgres.app/Contents/Versions/latest/bin
RBENV_ORIG_PATH=/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Applications/Postgres.app/Contents/Versions/latest/bin:/Users/richiethomas/.nvm/versions/node/v18.12.1/bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/Users/richiethomas/.rbenv/shims:/Users/richiethomas/.rbenv/bin:/usr/local/lib/ruby/gems/3.1.0:/Users/richiethomas/.cargo/bin:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/usr/local/opt/ruby/bin:/Users/richiethomas/.asdf/shims:/Users/richiethomas/.asdf/bin:/Users/richiethomas/.rbenv/shims:/usr/local/opt/redis@3.2/bin:/usr/local/opt/mongodb@3.2/bin:/usr/local/sbin:/Users/richiethomas/.yarn/bin:/Users/richiethomas/.config/yarn/global/node_modules/.bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Applications/Postgres.app/Contents/Versions/latest/bin
RBENV_SHELL=zsh
RBENV_DIR=/Users/richiethomas/Workspace/OpenSource/impostorsguides.github.io
RUBYLIB=/Users/richiethomas/.rbenv/rbenv.d/exec/gem-rehash:
```

I run `rbenv ` and then attempt a tab completion, and I see the following:

```
$ rbenv
--version           exec                init                rehash              uninstall           version-file-write  whence
commands            global              install             root                version             version-name        which
completions         help                local               shell               version-file        version-origin
env                 hooks               prefix              shims               version-file-read   versions
```

I run `ls $(rbenv root)/plugins` and I see the following:

```
$ ls $(rbenv root)/plugins

rbenv-env
```

OK, so the install of the command and the command itself both work.  So the plugin is not out-of-date.  And actually, this plugin might come in handy, since I've been struggling to differentiate rbenv env vars like `RBENV_DIR` vs. `RBENV_ROOT`.  Running the `rbenv env` command should help me distinguish these.

But the above all seems to relate solely to *plugins*, not *hooks*.  And what even is the difference?  This was a question I asked myself a few weeks ago, and it's something I still haven't answered.  But I have a theory.  I think that:

Plugins are just new commands you can run, i.e. `rbenv env` (this command wasn't available before I installed the above).
Hooks (I think?) are supplementary behaviors that you can add on top of existing commands.  That might be why `rbenv hooks` takes a specific command as an argument.

That's my working theory, for now.

Speaking of the `rbenv hooks` command, would running this on any commands produce results that I could then inspect, to further investigate the idea of hooks and how they work?  I try a few commands, and eventually I get the following output from `rbenv hooks exec`:

```
$ rbenv hooks exec

/Users/richiethomas/.rbenv/rbenv.d/exec/gem-rehash.bash
```

Cool, so we do have a hook that we could study.  This might be helpful:

<p style="text-align: center">
  <img src="/assets/images/screenshot-14mar2023-925am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Maybe not.  It's just one line of code, exporting an environment variable.

OK, I don't want to get too bogged down here for now.  I think this new working hypothesis of mine (that plugins are new commands and hooks are supplements of existing commands) is a reasonable one, given what I know about each one, and coming up with this hypothesis represents progress.  Let's move on.

### Tangent- 1st-order vs. 2nd-order questions

While thinking about `rbenv hooks` I realized there's a common stumbling block which often not only blocks me from making forward progress, but also sometimes saps my motivation to push through and persist.  My working name for this is "2nd-order confusion".

Think about some of the basic questions I've encountered and answered so far, over the course of this project.  For example: "I don't know what the syntax `[ … ]` is in `bash`."  That's a question I had at the beginning of this project.  And it was relatively straightforward to answer, just by Googling "square brackets bash".  I get my answer from StackOverflow, I know a little bit more about bash than I did a minute ago, and it's now relatively easier to read the script in front of me.

But what about when the question is not so straightforward?  What about when I have multiple questions, and they're all unrelated to each other?  What about when I have one question which depends on the answer to another question, for example the questions I had about the commands passed to `awk` when I was examining the `rbenv-help` command?  In that case, I wanted to know a) was I right in thinking that these are 3 separate commands being passed to `awk`, b) if so, what each of those commands were doing?  In that case, I was also confused about c) what the `END` syntax meant, and d) where the values for local variables like `usage` and `summary` were being initialized (i.e. what is going on [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-help#L66) with the `usage = usage…` syntax?).

In a way, it's similar to how cryptography works.  Stay with me, here.  It's relatively easy, given two prime numbers, to multiply them together and get a result.  But if all you have is the result, and you want the two prime numbers, that's a much more difficult problem (intentionally so, in the case of crypto).  2nd-order confusion is like that.  If you're looking at a non-trivial piece of code and don't know where to begin understanding it, one reason might be because you have multiple 1st-order questions and the confusion around each of them is compounding exponentially, leaving you with no idea where to start Googling.

Oftentimes when we're learning something new, we want to learn just enough information to get us unblocked.  Despite the old greybeard StackOverflow refrain of "RTFM", it's not always realistic to expect someone (especially a junior engineer) to read an entire manual just to answer a simple question.  If their question is of the first-order variety (i.e. "What is the `END` syntax in this `awk` invocation?"), then perhaps reading the manual is straightforward.  But if they don't know enough to *realize* that this is their question, or if they have multiple questions which are interacting with each other in weird ways to produce exponential confusion, how do they get unblocked?  They often need help teasing apart the rat's nest of questions, so that they're easier to manage.

I don't know that I have a good answer of how to do this yet.  But that's one thing I'd love to teach people how to do.  People don't need my help Googling simple questions.  They need help turning a rat's nest of overlapping, intertwined questions into those easy, 1st-order questions.  Or at the very least, that's the help *I* need.  I will say, however, that writing out my thoughts (chiefly via this project) has been the single most helpful tool I've encountered to address the idea of 2nd-order confusion and inter-twining questions.  When I write with the goal of teaching an audience (especially an imagined audience of people with a similar or slightly-lower skill level than me), I'm forced to verbalized my current level of understanding of the topic at hand, whatever that may be at the time.  Somehow, this verbalization process exposes gaps in my understanding, and those gaps are often discrete enough to be verbalizable (is that a word?) in the form of a 1st-order question.  Taking the time to answer those 1st-order questions often results in forward progress, but even if I don't go that far, just the act of exposing and writing down those questions is helpful in changing 2nd-order confusion into 1st-order confusion.

If we're stuck on a complicated piece of code and have no idea what's going on, maybe a good starting point is by writing down what we know for sure, what we think we know for certain, what we think might be happening, any assumptions we're making, and any hypotheses we can plausibly construct.  Next, we can verify that the things we think we know for sure are in fact true.  This is important because, if we are 100% certain about something and it turns out to be wrong, any subsequent assumptions or hypotheses could be based on faulty information.  Once we've independently verified our knowledge via docs or StackOverflow questions, we're in a position to start constructing our hypotheses: "I think this code is doing X.  The reason I think this is because the docs say Y."

(stopping here for the day; 49478 words)
