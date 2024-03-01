First, we'll look at the summary comments.

## ["Summary" comments](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-origin#L2){:target="_blank" rel="noopener" }

```
# Summary: Explain how the current Ruby version is set
```

Running `rbenv version-origin --help` returns:

```
$ rbenv version-origin --help

Usage: rbenv version-origin

Explain how the current Ruby version is set
```

So this command doesn't take any arguments.  When I run it in my terminal, I get:

```
 $ rbenv version-origin

/Users/myusername/.rbenv/version
```

And when I run it in a directory with a `.ruby-version` file, I get:

```
$ rbenv version-origin

/Users/myusername/Workspace/OpenSource/impostorsguides.github.io/.ruby-version
```

So `rbenv version-origin` returns the source file where the current Ruby version is set.

Next, the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/version-origin.bats){:target="_blank" rel="noopener" }

### Setup

After the `bats` shebang and the loading of `test_helper`, the first block of code is:

```
setup() {
  mkdir -p "$RBENV_TEST_DIR"
  cd "$RBENV_TEST_DIR"
}
```

We've seen this `setup` helper function before.  It creates and navigates into the temporary test directory that we use to create our test data, directories, etc.

Having a dedicated directory in which to run our spec ensures that we have a sandbox to take whatever actions our test requires (for example, create fake Ruby version files) and subsequently blow away those actions later.

### When no version file exists, global or otherwise

Our first test is:

```
@test "reports global file even if it doesn't exist" {
  assert [ ! -e "${RBENV_ROOT}/version" ]
  run rbenv-version-origin
  assert_success "${RBENV_ROOT}/version"
}
```

- This test starts with a sanity check to ensure that RBENV's global "version" file does not exist.
- It then runs the `version-origin` command.
- Lastly, it asserts that this non-existent global "version" file's path is returned anyway.

[As we discovered](https://github.com/rbenv/rbenv/discussions/1510){:target="_blank" rel="noopener" } when reading the command for `rbenv version-file`, the goal of returning the origin is to tell the user where the Ruby version is **expected to be set**, not where it **is being set**.  That's why this command returns the global filepath "even if it doesn't exist".

### When the global version file exists

Next test:

```
@test "detects global file" {
  mkdir -p "$RBENV_ROOT"
  touch "${RBENV_ROOT}/version"
  run rbenv-version-origin
  assert_success "${RBENV_ROOT}/version"
}
```

This test creates the global "version" file in its expected location, then runs the `version-origin` command and asserts that it completed successfully, with the global version file as its output.

### When the `RBENV_VERSION` variable is set

Next test:

```
@test "detects RBENV_VERSION" {
  RBENV_VERSION=1 run rbenv-version-origin
  assert_success "RBENV_VERSION environment variable"
}
```

This test asserts that, when we pass the `RBENV_VERSION` env var to the `version-origin` command, the command runs successfully and prints the string "RBENV_VERSION environment variable" to STDOUT.

### When a `.ruby-version` file exists

Next test:

```
@test "detects local file" {
  echo "system" > .ruby-version
  run rbenv-version-origin
  assert_success "${PWD}/.ruby-version"
}
```

This test creates a local Ruby version file, and specifies that the `version-origin` command runs successfully with that local version file path as its output.

### When a `version-origin` plugin exists

Next test:

```
@test "reports from hook" {
  create_hook version-origin test.bash <<<"RBENV_VERSION_ORIGIN=plugin"

  RBENV_VERSION=1 run rbenv-version-origin
  assert_success "plugin"
}
```

This test creates a hook for the `version-origin` command named `test.bash`, which contains code to overwrite the value of the `RBENV_VERSION_ORIGIN` env var to the string "plugin".

We then run the `version-origin` command with a *different* value of `RBENV_VERSION`, and assert that the command used the value from the hook, *not* the value from the passed-in env var.

### When the user overrides `IFS`

Next test:

```
@test "carries original IFS within hooks" {
  create_hook version-origin hello.bash <<SH
hellos=(\$(printf "hello\\tugly world\\nagain"))
echo HELLO="\$(printf ":%s" "\${hellos[@]}")"
SH

  export RBENV_VERSION=system
  IFS=$' \t\n' run rbenv-version-origin env
  assert_success
  assert_line "HELLO=:hello:ugly:world:again"
}
```

This test is similar to one we saw in the previous file's test suite.

- We create a hook which depends on the `IFS` (i.e. internal field separator) env var being set to contain certain characters.  These characters are the tab, whitespace, and newline characters.
    - The hook first creates an array of strings containing these characters.
    - It then prints a 2nd string which uses these characters as delimiters to split that single string into an array of strings.
- Next we set `RBENV_VERSION` to equal the string `system`.
- Next, we run the `version-origin` command, making sure to set `IFS` to contain the same characters as those we use as delimiters in our hook (tab, space, and newline).
- Finally, we assert that the command exited successfully and that the IFS characters that we set were, in fact, used to delimit the single string into an array of strings.

#### Copypasta error?

It looks like we're passing an argument (i.e. the string "env") to `version-origin` in this test.  I'm not sure what that is.  The argument doesn't appear to be used anywhere, nor does "$1" appear anywhere in the command itself.

I took a look at [the PR](https://github.com/rbenv/rbenv/pull/852/files){:target="_blank" rel="noopener" } which introduced this line of code, and it looks like it might have been a copy-paste error, since the previous implementation of the test did not include an argument to the invocation of the command.

### When the user attempts to pass the `RBENV_VERSION_ORIGIN` var

Last test:

```
@test "doesn't inherit RBENV_VERSION_ORIGIN from environment" {
  RBENV_VERSION_ORIGIN=ignored run rbenv-version-origin
  assert_success "${RBENV_ROOT}/version"
}
```

This test just asserts that the `version-origin` command ignores any value of `RBENV_VERSION_ORIGIN` that's passed in via an environment variable from the caller.

That's it for specs, now onto the code:

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-version-origin){:target="_blank" rel="noopener" }

Let's get the usual suspects out of the way first:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x
```

- `set -e` to exit the script immediately when it encounters an error
- `set -x` to print output in verbose mode when the `RBENV_DEBUG` env var is set

### Ensuring `RBENV_VERSION_ORIGIN` is not inherited

Next block of code:

```
unset RBENV_VERSION_ORIGIN
```

Here we explicitly unset any previously-set values for `RBENV_VERSION_ORIGIN`, such as those passed into the command by the caller.

This line of code was added [in this PR](https://github.com/rbenv/rbenv/commit/4fde4ecbaf1e1f3082c9275a6f244c70527ad497){:target="_blank" rel="noopener" }, and there's no mention of an issue or anything which may have prompted its addition.

### Running hooks

Next block of code:

```
OLDIFS="$IFS"
IFS=$'\n' scripts=(`rbenv-hooks version-origin`)
IFS="$OLDIFS"
for script in "${scripts[@]}"; do
  source "$script"
done
```

We've seen this code before.  It pulls the filepaths for any hooks for the `version-origin` command that the user has installed.  It then runs `source` on each of those filepaths, to ensure that the hook code is executed.

### Printing the origin filepath

The final block of code for this command:

```
if [ -n "$RBENV_VERSION_ORIGIN" ]; then
  echo "$RBENV_VERSION_ORIGIN"
elif [ -n "$RBENV_VERSION" ]; then
  echo "RBENV_VERSION environment variable"
else
  rbenv-version-file
fi
```

The only place where we could be getting our `RBENV_VERSION_ORIGIN` value from is a hook that was just `source`'ed.  That's because:

- We explicitly unset `RBENV_VERSION_ORIGIN` at the top of the file, and
- We didn't subsequently set it ourselves.

If that's indeed what happened, we echo that value to `stdout`.

Otherwise, if we have a non-empty value for `RBENV_VERSION` (either from the caller of `version-origin` or from a hook file), we print the string "RBENV_VERSION environment variable" to STDOUT.

If neither of those are true, we print the output of the `version-file` command that we examined earlier.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's a wrap for this command.  On to the next one.
