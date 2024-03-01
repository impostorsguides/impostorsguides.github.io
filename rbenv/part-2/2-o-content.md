Let's start by looking at the usage comments at the top of the file.

## Usage

```
# Summary: Display prefix for a Ruby version
# Usage: rbenv prefix [<version>]
#
# Displays the directory where a Ruby version is installed. If no
# version is given, `rbenv prefix' displays the location of the
# currently selected version.
```

So this command prints out the RBENV directory where a given Ruby version is installed.

Trying this out in my console, I try a few different versions of the command.

### Entering a known-valid version number

```
$ rbenv prefix 2.7.5

/Users/myusername/.rbenv/versions/2.7.5
```

When I enter a Ruby version that was installed using RBENV, I see the full path to the directory, as I'd expect from the usage comments.

### Entering a known-invalid version number

```
$ rbenv prefix 2.7.1

rbenv: version `2.7.1' not installed
```

When I enter a Ruby version that I know I don't have installed in my machine, I see an unsurprising error message.

### Entering the word `system`

```
$ rbenv prefix system

/usr
```

I happen to know that RBENV uses the word `system` to refer to the default Ruby version that's installed by your laptop's manufacturer on your machine.  When I pass the string `system` to `rbenv prefix`, I see the path `/usr`.

This is unsurprising, since `/usr` is a directory that contains many of my machine's default executables.

### Calling `rbenv prefix` without arguments

```
$ rbenv prefix

/Users/myusername/.rbenv/versions/2.7.5
```

As mentioned in the usage comments, when I call `rbenv prefix` without any arguments, I see the path of my currently-selected Ruby version.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Simple enough.  Let's look at the specs now.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/prefix.bats){:target="_blank" rel="noopener" }

### Running the command with no argument

After the `bats` shebang and the loading of `test_helper`, the first spec is:

```
@test "prefix" {
  mkdir -p "${RBENV_TEST_DIR}/myproject"
  cd "${RBENV_TEST_DIR}/myproject"
  echo "1.2.3" > .ruby-version
  mkdir -p "${RBENV_ROOT}/versions/1.2.3"
  run rbenv-prefix
  assert_success "${RBENV_ROOT}/versions/1.2.3"
}
```

 - To set up the test, we make (and then `cd` into) a new sub-direrectory of `RBENV_TEST_DIR` called `myproject`.
 - We then add a `.ruby-version` file to that new project dir containing the string "1.2.3".
 - Next, we make a fake "1.2.3" directory in our RBENV `versions/` directory, to simulate the act of installing Ruby v1.2.3 via RBENV.
 - Lastly, we run the `rbenv-prefix` command, and assert that
    - it ran successfully and that
    - it printed out the expected path to the installed Ruby version.

### Running the command with an invalid version

Next spec:

```
@test "prefix for invalid version" {
  RBENV_VERSION="1.2.3" run rbenv-prefix
  assert_failure "rbenv: version \`1.2.3' not installed"
}
```

Here we don't do any of the setup we did for the last test, we simply run the command with the `RBENV_VERSION` env var set.  Because we didn't do any of the setup (such as creating the fake directory under RBENV's `/versions` directory), we assert that the test should fail, and that a specific error should be printed.

### Running the command when only `system` is installed

Next test:

```
@test "prefix for system" {
  mkdir -p "${RBENV_TEST_DIR}/bin"
  touch "${RBENV_TEST_DIR}/bin/ruby"
  chmod +x "${RBENV_TEST_DIR}/bin/ruby"
  RBENV_VERSION="system" run rbenv-prefix
  assert_success "$RBENV_TEST_DIR"
}
```

As setup steps, we:

 - make a sub-directory named "bin/" inside `RBENV_TEST_DIR`, and
 - make a file inside that sub-directory named `ruby` (and making that file executable via `chmod`).

Then, to run the test, we
 - run the `rbenv prefix` command with "system" as the value set for `RBENV_VERSION`, and
 - assert that the command ran successfully and printed `RBENV_TEST_DIR` as its output.

This must mean that, if there are no sub-directories installed under `"${RBENV_ROOT}/versions/", the default behavior is to fall back to the `/bin/ruby` subdirectory of `RBENV_TEST_DIR`.

### Ensuring `prefix` works with `system` Ruby

Next test:

```
@test "prefix for system in /" {
  mkdir -p "${BATS_TEST_DIRNAME}/libexec"
  cat >"${BATS_TEST_DIRNAME}/libexec/rbenv-which" <<OUT
#!/bin/sh
echo /bin/ruby
OUT
  chmod +x "${BATS_TEST_DIRNAME}/libexec/rbenv-which"
  RBENV_VERSION="system" run rbenv-prefix
  assert_success "/"
  rm -f "${BATS_TEST_DIRNAME}/libexec/rbenv-which"
}
```

Here, the setup includes:
 - making a sub-directory within the `BATS_TEST_DIRNAME` directory,
 - adding a command within that sub-directory named `rbenv-which` (this is a stubbed-out version of a real RBENV command by the same name),
 - setting its contents equal to a shell script with a single command (`echo /bin/ruby`), and
 - updating the new command's permissions so that it's executable.

Once we have our fake `rbenv-which` command ready, we run the command with the `RBENV_VERSION` env var set to `system`, and we verify that the `prefix` command successfully exited with `/` (i.e. the home directory) as its output.

From looking at [the Github history](https://github.com/rbenv/rbenv/pull/919){:target="_blank" rel="noopener" }, it looks like this test was added as part of a bugfix where `rbenv prefix` didn't work when pulling the Ruby version from the machine's system version.

### When no `system` version is installed

Last spec file is:

```
@test "prefix for invalid system" {
  PATH="$(path_without ruby)" run rbenv-prefix system
  assert_failure <<EOF
rbenv: ruby: command not found
rbenv: system version not found in PATH"
EOF
}
```

 - Here we first ensure that the executable for system Ruby will not be found in the value of `$PATH` because we've removed it with the call to `path_without ruby` (described below).
 - Then we run the `rbenv prefix system` command.
 - We then assert that:
    - the `prefix` command failed and that
    - a specific error message was output to STDERR.

#### The `path_without` helper function

This function comes from the `test_helper` file, and looks like this:

```
# Output a modified PATH that ensures that the given executable is not present,
# but in which system utils necessary for rbenv operation are still available.
path_without() {
  local exe="$1"
  local path=":${PATH}:"
  local found alt util
  for found in $(type -aP "$exe"); do
    found="${found%/*}"
    if [ "$found" != "${RBENV_ROOT}/shims" ]; then
      alt="${RBENV_TEST_DIR}/$(echo "${found#/}" | tr '/' '-')"
      mkdir -p "$alt"
      for util in bash head cut readlink greadlink sed sort awk; do
        if [ -x "${found}/$util" ]; then
          ln -s "${found}/$util" "${alt}/$util"
        fi
      done
      path="${path/:${found}:/:${alt}:}"
    fi
  done
  path="${path#:}"
  echo "${path%:}"
}
```

Let's break down what's happening here.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
local exe="$1"
```

We create a local variable named `exe`, and set it equal to the first argument which is passed to `path_without`.

In the case of our last spec for `rbenv-prefix`, this was the string "ruby".

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
local path=":${PATH}:"
```

We create another local variable called `path`, and set it equal to the current value of our shell's `$PATH` variable.  We surround `$PATH` with the `:` character on either side, because that is the character that `PATH` uses as its delimiter.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
local found alt util
```

We create 3 more (uninitialized) local variables, named `found`, `alt`, and `util`, which will be assigned values further down in the `path_without` functions.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
for found in $(type -aP "$exe"); do
  ...
done
```

We run the command `type -aP "$exe"` (which in the case of our spec, resolves to `type -aP ruby`) and iterate over all the results with a `for` loop.

What do the `-a` and `-P` flags do?

Be careful: the `-P` flag is *not* the same as the `-p` flag that we encountered earlier with `type -p`.  If we run `help type` in a bash terminal, we see:

```
    The -P flag forces a PATH search for each NAME, even if it is an alias,
    builtin, or function, and returns the name of the disk file that would
    be executed.
```

So passing `-P` means that you'll see the canonical file that would be executed, not any alias which points to that file.

Similarly, when we search for `-a` in the `help` docs, we see:

```
    If the -a flag is used, `type' displays all of the places that contain
    an executable named `file'.  This includes aliases, builtins, and
    functions, if and only if the -p flag is not also used.
```

This means the `-a` flag tells `type` to return any and all such files, whereas leaving `-a` off returns a max of one result.  We can prove this with a quick experiment.

#### Experiment: passing `-a` to `type`

In Bash, I run `type ls` as a sanity check for the output I should expect:

```
bash-3.2$ type ls

ls is /bin/ls
```

I then make a quick shell function named `ls` (i.e. with the same name as the regular `ls` command):

```
bash-3.2$ ls() {
> echo "foo"
> }
```

I then run `type ls` to see how the command will interpret the `ls` command:

```
bash-3.2$ type ls

ls is a function
ls ()
{
    echo "foo"
}
```

As expected, Bash now interprets `ls` as a shell function, because it looks for shell functions before executables.

Now I run `type -a ls`:

```
bash-3.2$ type -a ls

ls is a function
ls ()
{
    echo "foo"
}
ls is /bin/ls
```

This time I see two results in the output.  First, I see the `ls is a function` indicating that it still recognizes my shell function, but at the bottom I also see `ls is /bin/ls`, the same output I saw during my sanity check.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

So in our `for` loop, we're iterating over each of the results that are found for the executable command whose name we passed to `path_without`.

For example, in our test we say `path_without ruby`, so we're iterating over each `ruby` executable that we have installed on our machine.  On my machine, when I open a Bash shell and enter `type -aP ruby`, I get:

```
bash-3.2$ type -aP ruby

/Users/myusername/.rbenv/shims/ruby
/usr/bin/ruby
```

So I would be iterating over 2 values: `/Users/myusername/.rbenv/shims/ruby` and `/usr/bin/ruby`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

 Each of the above results is referred to as a variable named `found`.  From there:

 ```
 found="${found%/*}"
 ```

We remove everything including and after the last `/` character.  This leaves us with just the directory containing the "found" executable file.

For example, if `type -aP ruby` includes the result `/Users/myusername/.rbenv/shims/ruby` on my machine, then:

 - the updated value of "found" changes from `/Users/myusername/.rbenv/shims/ruby` to `/Users/myusername/.rbenv/shims`, and
 - the updated value of `/usr/bin/ruby` changes to `/usr/bin`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
if [ "$found" != "${RBENV_ROOT}/shims" ]; then
 ...
fi
```

We then compare the new value of found to see if it is equal to `"${RBENV_ROOT}/shims"`.  For example, on my machine, this resolves to `/Users/myusername/.rbenv/shims`.

If the value of the path is *not* equal, we execute the logic inside the `if` block.  For example, we would skip the 1st of my two values for `found` above (`/Users/myusername/.rbenv/shims`), and continue forward with the 2nd value (`/usr/bin`).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
alt="${RBENV_TEST_DIR}/$(echo "${found#/}" | tr '/' '-')"
```

We set the `alt` local variable equal to `"${RBENV_TEST_DIR}/$(echo "${found#/}" | tr '/' '-')"`.  This consists of two strings, concatenated together with a `/`:

 - I added [a logging statement](/assets/images/screenshot-16mar2023-838am.png){:target="_blank" rel="noopener" } to the `path_without` function.  From this logging statement, I determine that `${RBENV_TEST_DIR}` resolves to `/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.eke` on my machine.
 - Similarly, `$(echo "${found#/}" | tr '/' '-')`, resolves to `usr-bin` on my machine.  Again, I learned this because by adding [a logging statement](/assets/images/screenshot-16mar2023-844am.png){:target="_blank" rel="noopener" } which stored the contents of this command in a variable, and then `echo`ed the variable.

We can further tell what's going on here by looking up the `man` page for `tr`:

```
TR(1)                                                                General Commands Manual                                                               TR(1)

NAME
     tr – translate characters

SYNOPSIS
     tr [-Ccsu] string1 string2
     tr [-Ccu] -d string1
     tr [-Ccu] -s string1
     tr [-Ccu] -ds string1 string2

DESCRIPTION
     The tr utility copies the standard input to the standard output with substitution or deletion of selected characters.
```

From the `man` page, we see that `tr` reads from STDIN, and replaces each instance of `string1` with `string2`.

In our case, we're replacing each instance of `/` with `-` (except for the first `/` in `$found`, which was shaved off by the parameter expansion `${found#/}`.

We therefore conclude that the value of the local variable `alt` is `/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.zgI/usr-bin`.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
mkdir -p "$alt"
```

We then take the above new value for `alt`, and make a directory out of it, using the `-p` flag to create any sub-directories as well if they don't already exist.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
for util in bash head cut readlink greadlink sed sort awk; do
  ...
done
```

Then we iterate over a list of system utilities (`bash head cut readlink greadlink sed sort awk`).

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
if [ -x "${found}/$util" ]; then
  ...
fi
```

For each of these utility programs, we check if `${found}/$util` exists as an executable file.  For example, if my value of `$found` is `/usr/bin` and the current `util` I'm iterating on is `head`, we check if `/usr/bin/head` exists as a file and is executable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
ln -s "${found}/$util" "${alt}/$util"
```

If that executable file exists, we create a symlink to it and place the symlink in our `alt` directory.  This has the effect of ensuring that we still have access to these system utils, even though we've removed

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
path="${path/:${found}:/:${alt}:}"
```

We then use parameter expansion to replace occurrences of `found` with `alt` in our `path` variable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

```
path="${path#:}"
echo "${path%:}"
```

Lastly, we trim the trailing `:` character off the beginning and end of `path`, and echo it to STDOUT, so that the caller of `path_without` can store the `echo`d value in a variable.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Having read through the spec file for the `prefix` command, let's turn to the command file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-prefix){:target="_blank" rel="noopener" }

First up is the 4 things that we always see at the beginning:

 - Bash shebang
 - "Usage" and "Summary" comments
 - the call to `set -e`, and
 - the check for the `$RBENV_DEBUG` env var.

### Completions setup

 Next block of code is:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo system
  exec rbenv-versions --bare
fi
```

This is the code to show the user the possible completions if they pass the `--complete` argument to `rbenv prefix`.  If the user types `rbenv prefix --complete`, we print the string `system` plus any Ruby versions that RBENV knows about.

### Setting `RBENV_VERSION` (so we can get the prefix)

Next block of code:

```
if [ -n "$1" ]; then
  export RBENV_VERSION="$1"
elif [ -z "$RBENV_VERSION" ]; then
  RBENV_VERSION="$(rbenv-version-name)"
fi
```

If the user specified a first argument, then we assume it is the version number that the user wants to see the prefix for, so we set `RBENV_VERSION` equal to that first argument and export it as an environment variable, so that this process and any child processes can use it.

If the user did *not* specify a first argument, *and* if `RBENV_VERSION` is currently blank, we set `RBENV_VERSION` equal to the return value of the `rbenv version-name` command.

Based on a cursory run of `rbenv version-name` in my Bash terminal, this appears to be quite similar to running `rbenv version`, but only including the number itself (not including the path to the `.ruby-version` file that sets the version number, as does the `rbenv version` command).  Note that we don't export the environment variable in this case.

If neither the above `if` or `elif` conditions are met, that means that:

 - The user didn't specify a first argument, AND
 - The user has previously set a value for `RBENV_VERSION.

This could happen if, for instance, the user runs the command as such:

```
$ RBENV_VERSION=3.0.0 rbenv prefix

/Users/myusername/.rbenv/versions/3.0.0
```

### Printing the prefix for `system` Ruby

Next block of code:

```
if [ "$RBENV_VERSION" = "system" ]; then
  if RUBY_PATH="$(rbenv-which ruby)"; then
    RUBY_PATH="${RUBY_PATH%/*}"
    RBENV_PREFIX_PATH="${RUBY_PATH%/bin}"
    echo "${RBENV_PREFIX_PATH:-/}"
    exit
  else
    echo "rbenv: system version not found in PATH" >&2
    exit 1
  fi
fi
```
If the current version of Ruby is set to `system`, then we execute the code below:

 - If the command `rbenv which ruby` returns a result, then:
    - We store that result in a variable named `RUBY_PATH`.
    - We remove the last `/` character and anything after it (such as a filename) from the new `RUBY_PATH` value.
    - We create a new variable named `RBENV_PREFIX_PATH`, and set it equal to the value of `RUBY_PATH`, removing any `/bin` at the end.
    - We echo either the value of `RBENV_PREFIX_PATH` if it has been set, or a `/` character as a default.
    - We exit with a 0 (i.e. successful) return code.
 - If `rbenv which ruby` does *not* return a result:
    - We echo a helpful error message letting the user know `system` is not a valid Ruby version.
    - We exit with a non-successful return code.

### Sad path- exiting if the user's version was not found

Next block of code:

```
RBENV_PREFIX_PATH="${RBENV_ROOT}/versions/${RBENV_VERSION}"
if [ ! -d "$RBENV_PREFIX_PATH" ]; then
  echo "rbenv: version \`${RBENV_VERSION}' not installed" >&2
  exit 1
fi
```

All the conditional branches inside that last `if` block terminate with a call to `exit`.  So if we've reached this above block of code, that means the `if` check in the previous block (i.e.`if [ "$RBENV_VERSION" = "system" ]; then`) was false.

Here we attempt to store a value in the `RBENV_PREFIX_PATH` variable, which should correspond to a valid directory on the user's machine.  If that variable does *not* correspond to a valid directory, we echo an error message explaining that the Ruby version that the user attempted to get a prefix for was not found on their machine, and we exit with a non-success return code.

### Printing the prefix

Last line of code:

```
echo "$RBENV_PREFIX_PATH"
```

If we've reached this line of code, that means:

 - we were successful in setting a value for `RBENV_PREFIX_PATH`, and:
 - it does correspond to a directory containing a Ruby version which was installed via RBENV.

If this is the case, we simply `echo` the directory for that Ruby version, and exit the script.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for `rbenv prefix`.  Now on to the next command.
