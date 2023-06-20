We'll start with the "Usage" comments at the top of the file.

## Usage

```
# Summary: List existing rbenv shims
# Usage: rbenv shims [--short]
```

Here we learn that the intent of this command is just to list all Ruby gems for which RBENV has installed shims.

We invoke it with `rbenv shims`, passing an optional `--short` flag.  When I run `rbenv shims`, I see output like the following:

```
/Users/myusername/.rbenv/shims/bootsnap
/Users/myusername/.rbenv/shims/brakeman
/Users/myusername/.rbenv/shims/bundle
/Users/myusername/.rbenv/shims/bundle-audit
/Users/myusername/.rbenv/shims/bundle_report
...
```

And so on.  When I pass the `--short` flag, I see the following:

```
bootsnap
brakeman
bundle
bundle-audit
bundle_report
...
```

So the `--short` flag just trims off everything but the command name itself.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

Next, let's look at the tests.

## [Tests](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/test/shims.bats){:target="_blank" rel="noopener"}

### When no shims are installed

After the `bats` shebang and the loading of `test_helper`, the first spec is:

```
@test "no shims" {
  run rbenv-shims
  assert_success
  assert [ -z "$output" ]
}
```

This test does no setup, such as installing any shims.  It immediately runs the command, and asserts that there is no output (`[ -z "$output" ]`) when no shims are installed.

### When shims are installed

Next spec:

```
@test "shims" {
  mkdir -p "${RBENV_ROOT}/shims"
  touch "${RBENV_ROOT}/shims/ruby"
  touch "${RBENV_ROOT}/shims/irb"
  run rbenv-shims
  assert_success
  assert_line "${RBENV_ROOT}/shims/ruby"
  assert_line "${RBENV_ROOT}/shims/irb"
}
```

This test does the following:

- It creates the `shims/` sub-directory inside `RBENV_ROOT`, along with two shim sub-directories inside `shims/`.
- Then we run the `rbenv shims` command.
- Lastly, we assert that the command completed successfully and that the output included the full paths to the two shims we created.

### Passing the `--short` flag

Next and last spec:

```
@test "shims --short" {
  mkdir -p "${RBENV_ROOT}/shims"
  touch "${RBENV_ROOT}/shims/ruby"
  touch "${RBENV_ROOT}/shims/irb"
  run rbenv-shims --short
  assert_success
  assert_line "irb"
  assert_line "ruby"
}
```

Here we do the same setup as in the last spec, but when we run the command, we pass the `--short` argument.  We then assert that, instead of getting the full filepaths, we just get the shims' names.

On to the file itself.

## [Code](https://github.com/rbenv/rbenv/blob/c4395e58201966d9f90c12bd6b7342e389e7a4cb/libexec/rbenv-shims){:target="_blank" rel="noopener"}

The first block of code is:

```
set -e
[ -n "$RBENV_DEBUG" ] && set -x

# Provide rbenv completions
if [ "$1" = "--complete" ]; then
  echo --short
  exit
fi
```

As usual, we have:

- `set -e` to exit after the first error
- Setting verbose mode when `RBENV_DEBUG` is passed.
- Completion instructions (only the `--short` argument is available for `rbenv shims`)

### Setting `nullglob`

Next block of code:

```
shopt -s nullglob
```

Here we set the `nullglob` shell option, so that any filepath patterns which don't expand into actual files to instead expand into the empty string, so that an attempt to iterate over the list of filepaths will instead iterate zero times.

### Printing the shim names (and possibly their directories, too)

Last block of code:

```
for command in "${RBENV_ROOT}/shims/"*; do
  if [ "$1" = "--short" ]; then
    echo "${command##*/}"
  else
    echo "$command"
  fi
done | sort
```

For each item in the "${RBENV_ROOT}/shims/" directory (which contains our list of shim files), we echo a string representing that shim.

- If the `--short` argument was passed, we shave off the parent filepath and only print the filename.
- If no `--short` argument was passed, we print the entire filepath.

As a last step, we take the series of printed shim names (or filepaths) and sort them alphabetically.

<div style="margin: 2em; border-bottom: 1px solid grey"></div>

That's it for this file!  It was a short one, for sure.  Now on to the next file.
