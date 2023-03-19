I'm not yet familiar with the `rbenv-prefix` command, so I sneak a peak at the “Usage” and “Summary” comments in the file itself, before switching to the test file:

```
# Displays the directory where a Ruby version is installed. If no
# version is given, `rbenv prefix' displays the location of the
# currently selected version.
```
In the happy-path, this command prints out the RBENV directory where a given Ruby version is installed.  Simple enough.  Let's look at the specs now.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/prefix.bats)

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

To set up the test, we make (and then navigate to) a new sub-direrectory of `RBENV_TEST_DIR` called `myproject`.  We then add a `.ruby-version` file to that new project dir containing the string “1.2.3”.  We then make a fake “1.2.3” directory in our RBENV `versions/` directory, to simulate the act of installing Ruby v1.2.3 via RBENV.

We then run the `rbenv-prefix` command, and assert that it ran successfully and that it printed out the expected path to the installed Ruby version.

Next spec:

```
@test "prefix for invalid version" {
  RBENV_VERSION="1.2.3" run rbenv-prefix
  assert_failure "rbenv: version \`1.2.3' not installed"
}
```

Here we don't do any of the setup we did for the last test, we simply run the command with the `RBENV_VERSION` env var set.  Because we didn't do any of the setup (such as creating the fake directory under RBENV's `/versions` directory), we assert that the test should fail, and that a specific error should be printed.

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

Here the test setup includes making a sub-directory named “bin/” inside `RBENV_TEST_DIR`, and making a file inside that sub-directory named `ruby` (and making that file executable via `chmod`).  Then we run the `rbenv prefix` command with “system” as the value set for `RBENV_VERSION`, and assert that the command ran successfully and printed `RBENV_TEST_DIR` as its output.  This must mean that, if there are no sub-directories installed under `"${RBENV_ROOT}/versions/", the default behavior is to fall back to the `/bin/ruby` subdirectory of `RBENV_TEST_DIR`.

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
making a sub-directory within the `BATS_TEST_DIRNAME` directory,
adding a command within that sub-directory named `rbenv-which` (this is a stubbed-out version of a real RBENV command by the same name),
setting its contents equal to a shell script with a single command (`echo /bin/ruby`), and
updating the new command's permissions so that it's executable.

Once we have our fake `rbenv-which` command ready, we run the command with the `RBENV_VERSION` env var set to `system`, and we verify that the `prefix` command successfully exited with `/` (i.e. the home directory) as its output.

I'm actually not sure what this tells us about the `prefix` command, other than it seems to depend internally on the `rbenv-which` command.  We'll probably learn more when we examine the `prefix` command's contents.

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

Here we run the `rbenv prefix system` command, having ensured that the executable for system Ruby will not be found in the value of `$PATH` because we've removed it with the call to `path_without ruby` (described below).  We then assert that the `prefix` command failed and that a specific error message was output to STDERR.

### Tangent- the `path_without` helper function

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

Let's break down what's happening here:
We create a local variable named `exe`, and set it equal to the first argument which is passed to `path_without` (in the case of our last spec for `rbenv-prefix`, this was the string “ruby”).
We create another local variable called `path`, and set it equal to the current value of our shell's `$PATH` variable, prefixed and suffixed with the “:” character.
We then create 3 more (uninitialized) local variables, named `found`, `alt`, and `util`.
We then run the command `type -aP “$exe”` (which in the case of our spec, resolves to `type -aP ruby`):


If you remember from earlier in this project, we discovered that the `type` command returns a path to the executable file for the command you pass it.


According to [GNU.org](https://web.archive.org/web/20220926111408/https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html), the `-a` flag tells `type` to return any and all such files, whereas leaving `-a` off returns a max of one result.


According to the same link, “The -P option forces a path search for each name, even if -t would not return 'file'.”  This appears to mean that passing `-P` allows `type` to resolve any symlinks to their corresponding files, instead of just returning the path to the symlink itself.


Next we iterate over each of the results from `type` via a `for` loop.  For example, on my machine, when I open a `bash` shell and enter `type -aP ruby`, I get:

```
bash-3.2$ type -aP ruby

/Users/myusername/.rbenv/shims/ruby
/Users/myusername/.rbenv/shims/ruby
/usr/bin/ruby
```

 - There are 3 results above.  We then execute a `for` loop, iterating over each of these 3 results:
    - Each result is referred to as `found`.
    - First we remove everything including and after the last `/` character.
      - This leaves us with just the directory containing the “found” executable file.
      - For example, if `type -aP ruby` includes the result “/Users/myusername/.rbenv/shims/ruby” on my machine, then the updated value of “found” changes from “/Users/myusername/.rbenv/shims/ruby” to “/Users/myusername/.rbenv/shims”.
    - We then compare the new value of found to see if it is equal to `"${RBENV_ROOT}/shims"`.  For example, on my machine, this resolves to `/Users/myusername/.rbenv/shims`.
      - We take *only* the results which are *not* equal.
      - For example, on the output above, we eliminate the first 2 results, and keep only `/usr/bin/ruby`.
    - For the results that we keep, we do the following:
      - We set the `alt` local variable equal to `"${RBENV_TEST_DIR}/$(echo "${found#/}" | tr '/' '-')"`.  This consists of two strings, concatenated together with a `/`:
        - ${RBENV_TEST_DIR}, which in my case resolves to `/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.eke`.  I know this because I added [a logging statement](/assets/images/screenshot-16mar2023-838am.png){:target="_blank" rel="noopener"} to the `path_without` function.
        - On my machine, `$(echo "${found#/}" | tr '/' '-')`, resolves to `usr-bin`.  Again, I learned this because by adding [a logging statement](/assets/images/screenshot-16mar2023-844am.png){:target="_blank" rel="noopener"} which stored the contents of this command in a variable, and then `echo`ed the variable.
        - We can further tell what's going on here by looking up the `man` page for `tr`:
        - If we look up the `man` page for `tr`, we see that `tr` reads from STDIN, and replaces each instance of `string1` with `string2`.
        - In our case, we're replacing each instance of “/” with “-” (except for the last “/” in “$found”, which was shaved off by the parameter expansion "${found#/}".
        - We therefore conclude that the value of the local variable `alt` is “/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.zgI/usr-bin”.
      - We then take the above new value for `alt`, and make a directory out of it, creating any sub-directories as well if they don't already exist.
      - Then we iterate over a list of system utils (`bash head cut readlink greadlink sed sort awk`).  For each of these util programs:
        - We check if “${found}/$util” exists as an executable file.  For example, if my value of “$found” is “/Users/myusername/.rbenv/shims” and the current `util` I'm iterating on is `head`, we check if “/Users/myusername/.rbenv/shims/head” exists as a file and is executable.
        - If that executable file exists, we create a symlink to it and place the symlink in our `alt` directory.
        - This has the effect of ensuring that we still have access to these system utils, even though we've removed
      - Lastly, we concatenate `found` and `alt` to the end of the current value of the lower-case `path` variable.
    - We then trim the trailing “:” character off the beginning and end of `path`, and echo it to STDOUT, so that the caller of `path_without` can store the `echo`d value in a variable.

One thing I don't understand- according to the comments above the `path_without` function, its stated goal is:

```
# Output a modified PATH that ensures that the given executable is not present,
# but in which system utils necessary for rbenv operation are still available.
```

But the local variable `path` is initialized as `local path=":${PATH}:"`.  It then gets appended with more directories, but at no point does `path` appear to have the anything *removed* from it.  So how do we guarantee that “the given executable is not present”?

I decide to do an experiment to see what exact value `path` is initialized to, and how it's modified over the course of the function.

(stopping here for the day; 52905 words)

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-850am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Here we write a file containing the initial value of `path`, as well as its value after each iteration of the `for` loop.  We also echo the values of `found` and `alt`, for the sake of completeness.  When we run the test, we get:

TODO- replace this image with actual code snippet, for readability

<p style="text-align: center">
  <a href='/assets/images/screenshot-16mar2023-852am.png'>
    <img src="/assets/images/screenshot-16mar2023-852am.png" width="100%" style="border: 1px solid black; padding: 0.5em">
  </a>
</p>

One of the first things I notice is that the value of `path` at the beginning and the end are the same, *up to the point* where the original path contains `/usr/bin`.  At that point, instead of `/usr/bin`, the initial `path` contains `:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:` (which begins with the same value as `found`), while the final version of `path` contains `:/var/folders/tn/wks_g5zj6sv_6hh0lk6_6gl80000gp/T/rbenv.hAE/usr-bin:/bin:/usr/sbin:/sbin:/usr/local/bin:` (which begins with the same value as `alt`).  It seems like we can conclude that the job of the `path="${path/:${found}:/:${alt}:}"` operation is *not* to concatenate both `found` and `alt` to the initial value of `path` (as I thought at first), but to *replace* `found` with `alt`.  This appears to be the mechanism by which the code “ensures that the given executable is not present”, as described in the function's comments.

Before moving on, I remember to remove the logging lines that I added to `path_without` above, and to delete the `testdoc` logfile.


### Rant- Including examples in your documentation

I find it incredibly frustrating that so much documentation in programming neglects to include examples of how that code is used in the wild.  So many of the explanations are vague and/or assume prior knowledge that the reader may or may not have.  If the documentation isn't written with a novice in mind, then there is no point in telling that novice to “go read the fucking manual”, is there?

For example, the following page in the GNU bash manual describes several different types of parameter expansion:

<p style="text-align: center">
  <img src="/assets/images/screenshot-16mar2023-856am.png" width="70%" style="border: 1px solid black; padding: 0.5em">
</p>

Not one of these includes examples of what the expected result would be when (for example) `parameter` is set to “foo/bar/baz” and “word” is set to “/”.  Of course, “foo/bar/baz” and “/” might not be the right example cases for all types of parameter expansion, but there will be *some* values for “parameter” and “word” that would clarify the (rather abstract) descriptions above.

It may not be the author's intention, but the effect on newbies is that it reduces their confidence in their ability to learn how to code, and therefore in their ability to participate in this community.  It makes them more likely to consider quitting.  And *we* as a community are worse off if they decide to quit.  Our pool of ideas is then smaller and more shallow.

<div style="border-bottom: 1px solid grey; margin: 3em"></div>

Having read through the spec file for the `prefix` command, let's turn to the command file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-prefix)

After the first 4 things that we always see (`bash` shebang, “Usage” and “Summary” comments, the call to `set -e`, and the check for the `$RBENV_DEBUG` env var), the first block of code we see is:

```
# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo system
  exec rbenv-versions --bare
fi
```

This is the code to show the user the possible completions if they pass the `--complete` argument to `rbenv prefix`.

Next block of code:

```
if [ -n "$1" ]; then
  export RBENV_VERSION="$1"
elif [ -z "$RBENV_VERSION" ]; then
  RBENV_VERSION="$(rbenv-version-name)"
fi
```

If the user specified a first argument, then we assume it is the version number that the user wants to see the prefix for, so we set `RBENV_VERSION` equal to that first argument and export it as an environment variable, so that this process and any child processes can use it.

If the user did *not* specify a first argument, *and* if `RBENV_VERSION` is currently blank, we set `RBENV_VERSION` equal to the return value of the `rbenv version-name` command.  Based on a cursory run of `rbenv version-name` in my `bash` terminal, this appears to be quite similar to running `rbenv version`, but only including the number itself (not including the path to the `.ruby-version` file that sets the version number, as does the `rbenv version` command).  Note that we don't export the environment variable in this case.

If neither the above `if` or `elif` conditions are met, that means that:

 - The user didn't specify a first argument, AND
 - The user has previously set a value for `RBENV_VERSION.

This could happen if, for instance, the user runs the command as such:

```
$ RBENV_VERSION=3.0.0 rbenv prefix

/Users/myusername/.rbenv/versions/3.0.0
```

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

 - If the command `rbenv which ruby` returns a result, and if we're successful in storing that result in a variable named `RUBY_PATH`, then:
    - We trim everything including and after the last `/` character from the new `RUBY_PATH` value.
    - We create a new variable named `RBENV_PREFIX_PATH`, and set it equal to the value of `RUBY_PATH` *plus* a `/bin` at the end.
    - We echo either the value of `RBENV_PREFIX_PATH` if it has been set, or a `/` character as a backup / default.
    - We exit with a 0 (i.e. successful) return code.
 - Otherwise:
    - We echo a helpful error message letting the user know `system` is not a valid Ruby version.
    - We exit with a non-successful return code.

Next block of code:

```
RBENV_PREFIX_PATH="${RBENV_ROOT}/versions/${RBENV_VERSION}"
if [ ! -d "$RBENV_PREFIX_PATH" ]; then
  echo "rbenv: version \`${RBENV_VERSION}' not installed" >&2
  exit 1
fi
```

If we've reached this block of code, that means the `if` check in the previous block (i.e.`if [ "$RBENV_VERSION" = "system" ]; then`) was false.  We know this because all the conditional branches inside that last check contain calls to `exit`.

Here we attempt to store a value in the `RBENV_PREFIX_PATH` variable, which should correspond to a valid directory on the user's machine.  If that variable does *not* correspond to a valid directory, we echo an error message explaining that the Ruby version that the user attempted to get a prefix for was not found on their machine, and we exit with a non-success return code.

Last line of code:

```
echo "$RBENV_PREFIX_PATH"
```

If we've reached this line of code, that means a) we were successful in setting a value for `RBENV_PREFIX_PATH`, and b) it does correspond to a directory containing a Ruby version which was installed via RBENV.  If this is the case, we simply `echo` the directory for that Ruby version, and exit the script.

On to the next file.
