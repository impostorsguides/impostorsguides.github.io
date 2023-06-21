FIrst, the "Summary" comments.

## Summary

```
$ rbenv version-name --help

Usage: rbenv version-name

Show the current Ruby version
```

Looks like we just call the command itself, with no arguments.  When I try this on my machine, I see:

```
$ rbenv version-name

2.7.5
```

Pretty unsurprising.  Let's move on to the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-name.bats){:target="_blank" rel="noopener"}

### "Installing" a mocked Ruby version

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
create_version() {
  mkdir -p "${RBENV_ROOT}/versions/$1"
}
```

Here we create a sub-directory of our `versions/` directory, ensuring that any parent directories which don't yet exist are created first via the `-p` flag.

### Setting up our tests

Next block of code:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

Here we just make and navigate into our test directory.  This `setup` function is called by the BATS test runner, in [this file](https://github.com/sstephenson/bats/blob/03608115df2071fff4eaaff1605768c275e5f81f/libexec/bats-exec-test){:target="_blank" rel="noopener"}.

### When the user hasn't yet picked a Ruby version

Next block of code is the first test:

```
@test "no version selected" {
  assert [ ! -d "${RBENV_ROOT}/versions" ]
  run rbenv-version-name
  assert_success "system"
}
```

Here we test the case where the user hasn't installed any Ruby versions yet, and then we run the `version-name` command.  We assert that the command was successful and that the default "system" version of Ruby is printed as output.

### When the `system` version is not installed

Next test:

```
@test "system version is not checked for existence" {
  RBENV_VERSION=system run rbenv-version-name
  assert_success "system"
}
```

Here we check that if the user specifically sets their `RBENV_VERSION` env var to "system", the command will use that as the version name, **regardless** of whether or not Ruby is installed on the machine.

This test covers [this line of code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L18){:target="_blank" rel="noopener"}.  We see that when the user's `RBENV_VERSION` env var is either empty or set to "system", the program just prints `system` and exits.

### When the user specifies `RBENV_VERSION`, but `version-name` has a hook

Next test:

```
@test "RBENV_VERSION can be overridden by hook" {
  create_version "1.8.7"
  create_version "1.9.3"
  create_hook version-name test.bash <<<"RBENV_VERSION=1.9.3"

  RBENV_VERSION=1.8.7 run rbenv-version-name
  assert_success "1.9.3"
}
```

This test does the following:

- It creates two Ruby versions with our helper method.
- It then creates a hook file for the `version-name` command named `test.bash`.
- Inside that hook file, we simply set the `RBENV_VERSION` env var to the 2nd version number that we created, "1.9.3".
- We then run the `version-name` command, specifying the *first* version number that we created.
- We assert that the `version-name` command prints the version name from the hook we created.

This implies that the logic to `source` the hook files (which lives [here](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name#L14){:target="_blank" rel="noopener"}) overwrites any env vars passed to the command.

### Uses the user-specified `IFS` value in hooks

Next test:

```
@test "carries original IFS within hooks" {
  create_hook version-name hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
SH

  export RBENV_VERSION=system
  IFS=$' \t\n' run rbenv-version-name env
  assert_success
  assert_line "HELLO=:hello:ugly:world:again"
}
```

Here we do the following:

- We create a hook named `hello.bash` which contains several strings separated by tabs, spaces, and newlines.
    - The hook takes these strings and prints them out, using those separator characters to determine where to split them, and therefore where to concatenate them together delimited by the ":" character.
    - Lastly, the hook mimics the setting the value of an env var named `HELLO` to the value of those concatenated strings, `echo`ing out the command to set the env var.
- We then set the internal field separator to contain the tab, space, and newline characters, and we run `version-name`.
- We assert that the command was successful and that our `HELLO=...` command was `echo`'ed to the screen.

The purpose of this test is to ensure that the value of the internal field separator that we passed to `version-name` is respected by any hooks installed for `version-name`.

### When both `RBENV_VERSION` and `.ruby-version` exist

Next test:

```
@test "RBENV_VERSION has precedence over local" {
  create_version "1.8.7"
  create_version "1.9.3"

  cat > ".ruby-version" <<<"1.8.7"
  run rbenv-version-name
  assert_success "1.8.7"

  RBENV_VERSION=1.9.3 run rbenv-version-name
  assert_success "1.9.3"
}
```

Here we do the following:

- We create two Ruby version installations, named "1.8.7" and "1.9.3".
- We then create a local Ruby version file containing "1.8.7".
- We run the `version-name` command.
- We assert that it was successful and that the version from our local version file was used.
- We then run the command again, this time passing a value for our `RBENV_VERSION` env var.
- We assert that the command was successful, but this time that the value we manually set for `RBENV_VERSION` was the value that was used as the command's output.

### When both a local and global version file exist

Next test:

```
@test "local file has precedence over global" {
  create_version "1.8.7"
  create_version "1.9.3"

  cat > "${RBENV_ROOT}/version" <<<"1.8.7"
  run rbenv-version-name
  assert_success "1.8.7"

  cat > ".ruby-version" <<<"1.9.3"
  run rbenv-version-name
  assert_success "1.9.3"
}
```

Here we do the following:

- We create two Ruby version installations, just as we did in the last test.
- This time we create a global version file containing "1.8.7".
- We first assert that the `version-file` command defaults to using the global version file.
- Then we create our local version file, just as we did in the last test.
- When we run the command again, we now assert that it uses the local version file instead of the global file.

### When the specified version is not installed

Next test:

```
@test "missing version" {
  RBENV_VERSION=1.2 run rbenv-version-name
  assert_failure "rbenv: version \`1.2' is not installed (set by RBENV_VERSION environment variable)"
}
```

This test explicitly avoids the setup step of creating an installed version directory inside RBENV's "versions/" parent directory.  This is so that we can test what happens when the user runs the command with a specified value set for `RBENV_VERSION`.  When this happens, we assert that an error is raised.

### When the version number contains a prefix like `ruby-`

Last test:

```
@test "version with prefix in name" {
  create_version "1.8.7"
  cat > ".ruby-version" <<<"ruby-1.8.7"
  run rbenv-version-name
  assert_success
  assert_output "1.8.7"
}
```

- As setup steps, we do the following:
    - "install" Ruby v1.8.7 in RBENV's "versions/" directory, and
    - create a local Ruby version file with the same version number inside.
- We then run the `version-name` command and assert that:
    - it was successful, and
    - that the expected version number was output.

This is the primary happy-path test for this command.

Now on to the code itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-name){:target="_blank" rel="noopener"}

As per usual:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

- `set -e` sets "exit-on-error" mode.
- `set -x` sets "verbose" mode, in this case when the `RBENV_DEBUG` variable is set.

### When `RBENV_VERSION` is unset

Next block of code:

```
if [ -z "$RBENV_VERSION" ]; then
  RBENV_VERSION_FILE="$(rbenv-version-file)"
  RBENV_VERSION="$(rbenv-version-file-read "$RBENV_VERSION_FILE" || true)"
fi
```

Here we check whether the `RBENV_VERSION` variable is empty, either because;

  - no previous script has set it, or because
  - the caller didn't explicitly pass it in like we saw in the unit tests.

If it is empty, we fetch the filepath that we should be using to store the current Ruby version, via the `rbenv version-file` command that we recently discussed.  We store this filepath in the variable `RBENV_VERSION_FILE`.

We then pass that variable to `version-file-read` in order to return the version number itself, storing the result in the variable `RBENV_VERSION`.  We add `|| true` at the end of the command to prevent an error from triggering an exit.

### Calling any hooks for the `version-name` command

Next block of code:

```
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks version-name`)
IFS="$OLDIFS"
for script in "${scripts[@]}"; do
  source "$script"
done
```

Here we do the following:

- We grab all hooks for the `version-name` command, storing the filepaths for the hooks as an array of strings in a variable named `scripts`.
- We need to temporarily reset `IFS` to be the newline character, because the output of `rbenv-hooks` is a series of strings delimited by newlines.
- So we temporarily store the old value of `IFS`, then set its new value to be the newline character for the purposes of creating our `scripts` variable, then reset `IFS` back to its original value.
- We then iterate over the array of filepath strings, running `source` on each one to run each one in turn.

### When RBENV doesn't have any Ruby versions installed

Next block of code:

```
if [ -z "$RBENV_VERSION" ] || [ "$RBENV_VERSION" = "system" ]; then
  echo "system"
  exit
fi
```

Here we check whether:

- our `RBENV_VERSION` variable is empty, or
- whether its value is set to "system".

If either of these conditions are true, we simply print the string "system" and then exit the `version-name` command.

### Deciding whether RBENV knows about a Ruby version

Next block of code:

```
version_exists() {
  local version="$1"
  [ -d "${RBENV_ROOT}/versions/${version}" ]
}
```

Here we define a helper function called `version_exists`, which takes a version number as an argument and tests whether that version has been installed into RBENV's `versions/` directory.

### Finally printing the Ruby version

Last block of code:

```
if version_exists "$RBENV_VERSION"; then
  echo "$RBENV_VERSION"
elif version_exists "${RBENV_VERSION#ruby-}"; then
  echo "${RBENV_VERSION#ruby-}"
else
  echo "rbenv: version \`$RBENV_VERSION' is not installed (set by $(rbenv-version-origin))" >&2
  exit 1
fi
```

Once we have a version number (either from the value specified by the user via the `RBENV_VERSION` env var or from the `version-file-read` command), we invoke our `version_exists` helper method.  This method checks whether that version number is installed.

- If it is installed, we echo it to the user.
- If it's not installed, we next check whether that version number is installed with a `ruby-` prefix.
- If we do find it this time, we print it to the screen, with the prefix removed.
- If both of these checks fail, we print an error message specifying that the requested Ruby version was not found.

We also print the source of the request for that particular version number (whether it was from an environment variable, a version file, etc.).  This origin comes from the `rbenv version-origin` command, which we'll look at in the next file.

Lastly, we exit with a non-zero return code.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for this file!  On to the next one.
